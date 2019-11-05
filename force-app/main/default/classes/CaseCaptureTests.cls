/**
 * Test CaseCapture
 *
 * Changelog
 * ---------
 *
 * v1.0.0   ?           Daniel Stange               Initial draft
 * v1.1.0   2018-07-30  Marko Schmalenbach          Test of SOBCRM-1236
 *                                                  - Added "preventPersistence" possibility
 *                                                  - Added return of created Case
 *                                                  - Added proper HTTP status on failure
 * v1.2.0   2018-09-07  Marko Schmalenbach          Test of SOBCRM-1253
 *                                                  - Relate Battery by given Battery Serial Number
 *                                                  - Relate Contract by given Contract Number
 *                                                  - Relate Stock Item by given Battery Serial Number
 * v1.3.0   2019-02-04  Marko Schmalenbach          Testing of attachment saving (SOBCRM-1316)
 *
 * @author Daniel Stange
 * @see CaseCapture
 */
@isTest
private class CaseCaptureTests {

    private static final String DEBUG_HEADER = 'CaseCaptureTests.';

    private static Account oAccount;
    private static Contact oContact;
    private static Contract oContract;
    private static Asset oBatteryAsset;
    private static StockItem__c oStockItem;

    @IsTest
    static void setup() {

        oAccount = new Account(
            Name = 'ACME Corp.'
        );
        insert oAccount;

        oContact = new Contact(
            AccountId = oAccount.Id,
            FirstName = 'Voidy',
            LastName  = 'Boguscontact'
        );
        insert oContact;

        oContract = new Contract(
            RecordTypeId     = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('Energy').getRecordTypeId(),
            Type__c          = 'sonnenbatterieHome-DE',
            TariffType__c    = 'household',
            AccountId        = oAccount.Id,
            CustomerSignedId = oContact.Id,
            Status           = 'Draft'
        );
        insert oContract;

        oContract = [SELECT ContractNumber, AccountId, CustomerSignedId FROM Contract WHERE Id = :oContract.Id];

        oBatteryAsset = new Asset(
            RecordTypeId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId(),
            Name         = 'Bogus Battery',
            SerialNumber = '123456',
            AccountId    = oAccount.Id,
            ContactId    = oContact.Id
        );
        insert oBatteryAsset;

        oStockItem = new StockItem__c(
            SerialNumber__c = '654321',
            Type__c = 'Battery'
        );
        insert oStockItem;
    }

    @IsTest
    static void TestCaseCapture() {

        final String DEBUG_HERE = DEBUG_HEADER + 'TestCaseCapture() - ';

        setup();

        // Test ContractNumber filter
        String sContractNumberTest = '';

        sContractNumberTest = '0000000000' + oContract.ContractNumber;
        System.assertEquals(oContract.ContractNumber, CaseCapture.filterContractNumber(sContractNumberTest));

        sContractNumberTest = oContract.ContractNumber.substring(0, 3) + '-' + oContract.ContractNumber.substring(3);
        System.assertEquals(oContract.ContractNumber, CaseCapture.filterContractNumber(sContractNumberTest));

        sContractNumberTest = '123456-789123M';
        System.assertEquals('123456789123', CaseCapture.filterContractNumber(sContractNumberTest));

        // Test BatterySerialNumber filter
        String sBatterySerialNumberTest = '';

        sBatterySerialNumberTest = 'SER. 123-45678';
        System.assertEquals('12345678', CaseCapture.filterBatterySerialNumber(sBatterySerialNumberTest));

        //---------------------------------
        // Success Case
        //---------------------------------
        Case oCaseSuccess = new Case(
            Subject                       = 'Testcase',
            SuppliedName                  = 'Voidy Bogushonk',
            SuppliedEmail                 = 'honk@tonk.com',
            Salutation__c                 = 'Mr.',
            FirstName__c                  = 'Voidy',
            LastName__c                   = 'Bogushonk',
            ContractNumberRequest__c      = oContract.ContractNumber,
            BatterySerialNumberRequest__c = oBatteryAsset.SerialNumber.substring(0, 3) + '-' +
                oBatteryAsset.SerialNumber.substring(3)
        );

        Map<String, Object> mapRequest = oCaseSuccess.getPopulatedFieldsAsMap().clone();

        List<String> listAttachments = new List<String>{
            'https://www.nowhere.wtf/test1.pdf',
            'https://www.nowhere.wtf/test2.pdf'
        };

        mapRequest.put('_attachments', listAttachments);

        Test.startTest();

        RestRequest oRestRequest = new RestRequest();
        RestResponse oRestResponse = new RestResponse();

        oRestRequest.requestURI = '/services/apexrest/case';
        oRestRequest.httpMethod = 'POST';
        oRestRequest.requestBody = Blob.valueOf(JSON.serialize(mapRequest)); // oCaseSuccess
        RestContext.request = oRestRequest;
        RestContext.response = oRestResponse;

        CaseCapture.Response oResponseSuccess = CaseCapture.createCase();
        System.assertEquals(listAttachments.size(), CaseCapture.listAttachmentsUnitTest.size(), 'Expected count of attachments to match');

        //---------------------------------
        // Fail
        //---------------------------------
        Case oCaseFail = new Case(
            SuppliedName = 'Honk',
            SuppliedEmail = 'honktonk.com'
        );

        oRestRequest = new RestRequest();
        oRestResponse = new RestResponse();

        oRestRequest.requestURI = '/services/apexrest/case';
        oRestRequest.httpMethod = 'POST';
        oRestRequest.requestBody = Blob.valueOf(JSON.serialize(oCaseFail));
        RestContext.request = oRestRequest;
        RestContext.response = oRestResponse;

        CaseCapture.Response oResponseFail = CaseCapture.createCase();

        System.assertEquals(500, RestContext.response.statusCode);

        //--------------------------
        // "preventPersistence"
        //--------------------------
        Case oCasePreventPersistence = new Case(
            Subject       = 'Testcase',
            SuppliedName  = 'Honk',
            SuppliedEmail = 'honk@honktonk.com'
        );

        oRestRequest = new RestRequest();
        oRestResponse = new RestResponse();

        oRestRequest.requestURI = '/services/apexrest/case';
        oRestRequest.httpMethod = 'POST';
        oRestRequest.params.put('preventPersistence', '1');
        oRestRequest.requestBody = Blob.valueOf(JSON.serialize(oCasePreventPersistence));
        RestContext.request = oRestRequest;
        RestContext.response = oRestResponse;

        CaseCapture.Response oResponsePreventPersistence = CaseCapture.createCase();

        Test.stopTest();
        //Assertions

        // Number of Cases should be exactly one
        List<Case> listCases = (List<Case>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Case') + ' FROM Case');

        // Successful Case
        System.assert(listCases.size() == 1, 'Expected only one successful Case');
        Case oResultCase = listCases.get(0);

        System.assertEquals(oResultCase.Id, oResponseSuccess.caseid);
        System.assert(oResponseSuccess.caseObject != null);

        for (String sField : oCaseSuccess.getPopulatedFieldsAsMap().keySet()) {
            System.assertEquals(oResultCase.get(sField), oCaseSuccess.getPopulatedFieldsAsMap().get(sField));
        }

        // Check if Battery Asset Id was set by Serial Number
        System.assertEquals(oBatteryAsset.Id, oResultCase.Battery__c);

        // Check if Contract Id was set by Contract Number
        System.assertEquals(oContract.Id, oResultCase.Contract__c);

        // Check on Account Id and Contact Id
        // ⚠️ These had to be set by process "New eService Case from Contract"!
        System.assertEquals(oAccount.Id, oResultCase.AccountId);
        System.assertEquals(oContact.Id, oResultCase.ContactId);

        // Other
        System.assertEquals('Failure', oResponseFail.status);
        System.assertEquals('Success', oResponsePreventPersistence.status);
    }

    @IsTest
    static void TestCaseCaptureWithoutContract() {

        setup();

        Case oCaseSuccess = new Case(
            Subject                       = 'Testcase',
            SuppliedName                  = 'Voidy Bogushonk',
            SuppliedEmail                 = 'honk@tonk.com',
            Salutation__c                 = 'Mr.',
            FirstName__c                  = 'Voidy',
            LastName__c                   = 'Bogushonk',
            BatterySerialNumberRequest__c = oBatteryAsset.SerialNumber
        );

        Test.startTest();

        RestRequest oRestRequest = new RestRequest();
        RestResponse oRestResponse = new RestResponse();

        oRestRequest.requestURI = '/services/apexrest/case';
        oRestRequest.httpMethod = 'POST';
        oRestRequest.requestBody = Blob.valueOf(JSON.serialize(oCaseSuccess));
        RestContext.request = oRestRequest;
        RestContext.response = oRestResponse;

        CaseCapture.createCase();

        Test.stopTest();

        List<Case> listCases = (List<Case>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Case') + ' FROM Case');

        System.assert(listCases.size() == 1);
        Case oResultCase = listCases.get(0);

        // Check on Account Id and Contact Id
        // ⚠️ These had to be set by process "New eService Case from Contract"!
        System.assertEquals(oAccount.Id, oResultCase.AccountId);
        System.assertEquals(oContact.Id, oResultCase.ContactId);
    }

    @IsTest
    static void TestCaseCaptureWithStockItem() {

        setup();

        Case oCaseSuccess = new Case(
            Subject                       = 'Testcase',
            SuppliedName                  = 'Voidy Bogushonk',
            SuppliedEmail                 = 'honk@tonk.com',
            Salutation__c                 = 'Mr.',
            FirstName__c                  = 'Voidy',
            LastName__c                   = 'Bogushonk',
            BatterySerialNumberRequest__c = oStockItem.SerialNumber__c // Test StockItem relation
        );

        Test.startTest();

        RestRequest oRestRequest = new RestRequest();
        RestResponse oRestResponse = new RestResponse();

        oRestRequest.requestURI = '/services/apexrest/case';
        oRestRequest.httpMethod = 'POST';
        oRestRequest.requestBody = Blob.valueOf(JSON.serialize(oCaseSuccess));
        RestContext.request = oRestRequest;
        RestContext.response = oRestResponse;

        CaseCapture.createCase();

        Test.stopTest();

        List<Case> listCases = (List<Case>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Case') + ' FROM Case');

        System.assert(listCases.size() == 1);
        Case oResultCase = listCases.get(0);

        // Check if Stock Item Id was set by Serial Number
        System.assertEquals(oStockItem.Id, oResultCase.StockItem__c);
    }

    /**
     * Attachments saving is done separately as it is done by
     * a future callout which would fail with "uncommitted work pending"
     * in Unit Testing
     */
    @IsTest
    static void TestAttachmentSavingSuccess() {

        Case oCase = new Case(
            Subject                       = 'Testcase',
            SuppliedName                  = 'Voidy Bogushonk',
            SuppliedEmail                 = 'honk@tonk.com',
            Salutation__c                 = 'Mr.',
            FirstName__c                  = 'Voidy',
            LastName__c                   = 'Bogushonk'
        );
        insert oCase;

        List<String> listAttachments = new List<String>{
            'https://www.tralala.de/hulu1.pdf',
            'https://www.tralala.de/hulu2.pdf'
        };

        Test.startTest();
        CaseCapture.saveAttachments(listAttachments, oCase.Id);
        Test.stopTest();

        oCase = [SELECT Id, (SELECT Name FROM Attachments) FROM Case WHERE Id = :oCase.Id];

        System.assertEquals(listAttachments.size(), oCase.Attachments.size(), 'Expected the amount of Attachments to match');
    }

    /**
     * Test error on attachment saving
     */
    @IsTest
    static void TestAttachmentSavingError() {

        Case oCase = new Case(
            Subject                       = 'Testcase',
            SuppliedName                  = 'Voidy Bogushonk',
            SuppliedEmail                 = 'honk@tonk.com',
            Salutation__c                 = 'Mr.',
            FirstName__c                  = 'Voidy',
            LastName__c                   = 'Bogushonk'
        );
        insert oCase;

        List<String> listAttachments = new List<String>{''};

        Test.startTest();
        CaseCapture.saveAttachments(listAttachments, oCase.Id);
        Test.stopTest();

        oCase = [SELECT Id, (SELECT Name FROM Attachments) FROM Case WHERE Id = :oCase.Id];
        System.assert(oCase.Attachments.size() == 0, 'Expected the amount of Attachments to match 0');

        // Check for error case
        List<Case> listCases= [SELECT ParentId FROM Case WHERE Id != :oCase.Id];
        System.assertEquals(1, listCases.size(), 'Expected on error case');
        System.assertEquals(oCase.Id, listCases.get(0).ParentId, 'Expected parent ID of error case to match ID of causing Case');
    }
}