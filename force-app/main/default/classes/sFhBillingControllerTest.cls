@IsTest
public class sFhBillingControllerTest {
    @TestSetup
    static void testSetup() {

        Id personAccId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Account personAcc = new Account(FirstName = 'Person', LastName='Account', RecordTypeId = personAccId);
        insert personAcc;

        Id assetId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('PVPlant').getRecordTypeId();
        Asset pvAsset = new Asset(Name = 'PV-Asset', RecordTypeId = assetId, AccountId = personAcc.Id, PVSizekWp__c = 10);
        insert pvAsset;

        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Contract flatContract = new Contract(RecordTypeId = contractId,	Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, PVAsset__c = pvAsset.Id, StartDate = Date.today().addDays(1), TariffType__c = 'sonnenFlat', Tariff_Version__c = 'sFh 3.0');
        insert flatContract;

        Id contractDmId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
        Contract dmContract = new Contract(RecordTypeId = contractDmId, Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, ContractNumberSonnenFlatDM__c = flatContract.Id, StartOfCommunityFeedIn__c = Date.today().addDays(2));
        insert dmContract;
    }

    @IsTest
    static void sFhBillingControllerTest() {
        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Contract newContract = [SELECT Id FROM Contract WHERE RecordTypeId =: contractId];

        PageReference pageRef = Page.sFhBilling;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', newContract.Id);
        sFhBillingController controller = new sFhBillingController();
        List<SelectOption> options = controller.getItems();
        controller.assetWrapper.pvSize = 12;
        controller.assetWrapper.newDatePV = '2018-01-01';
        controller.accWrapper.vatId = '123/4567/12345';
        controller.accWrapper.subjectToVat = 'Yes';
        controller.confirm();

        Test.stopTest();

        Id accId = [SELECT AccountId FROM Contract WHERE Id =: newContract.Id].AccountId;
        List<DataTransferObject__c> dtoList = [SELECT Id FROM DataTransferObject__c WHERE AccountId__c =: accId];
        DataTransferObject__c dto = [SELECT Id, RelatedProcess__c, CommissioningDatePV__c, PVSizekWp__c, VATId__c, SubjectToVat__c, AccountId__c FROM DataTransferObject__c WHERE AccountId__c =: accId];
        Date expectedDate = Date.newInstance(2018, 01, 01);
        List<Case> caseList = [SELECT Id FROM Case WHERE Contract__c =: newContract.Id];

        System.assertEquals(1, dtoList.size());
        System.assertEquals('sFh Billing', dto.RelatedProcess__c);
        System.assertEquals(expectedDate, dto.CommissioningDatePV__c);
        System.assertEquals(12, dto.PVSizekWp__c);
        System.assertEquals('123/4567/12345', dto.VATId__c);
        System.assertEquals('Yes', dto.SubjectToVat__c);

        System.assertEquals(1, caseList.size());
    }

    @IsTest
    static void sFhBillingControllerTest2() {
        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Contract newContract = [SELECT Id, PVAsset__c, AccountId FROM Contract WHERE RecordTypeId =: contractId];

        Contract dmContract = [SELECT Id, StartOfCommunityFeedIn__c FROM Contract WHERE ContractNumberSonnenFlatDM__c =: newContract.Id];
        dmContract.StartOfCommunityFeedIn__c = Date.newInstance(2017, 01, 01);
        update dmContract;

        Asset pvAsset = [SELECT Id, CommissioningDatePV__c FROM Asset WHERE Id =: newContract.PVAsset__c];
        pvAsset.CommissioningDatePV__c = Date.newInstance(2017, 01, 01);
        update pvAsset;

        Account accUpdate = [SELECT Id, SubjectToVat__c, VATId__c FROM Account WHERE Id =:newContract.AccountId];
        accUpdate.SubjectToVat__c = 'No';
        accUpdate.VATId__c = '987/4567/12345';
        update accUpdate;

        PageReference pageRef = Page.sFhBilling;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', newContract.Id);
        sFhBillingController controller = new sFhBillingController();
        List<SelectOption> options = controller.getItems();
        controller.assetWrapper.pvSize = 10;
        controller.assetWrapper.newDatePV = '2018-01-01';
        controller.accWrapper.vatId = '123/4567/12345';
        controller.accWrapper.subjectToVat = 'Yes';
        controller.confirm();

        Test.stopTest();

        Id accId = [SELECT AccountId FROM Contract WHERE Id =: newContract.Id].AccountId;
        List<DataTransferObject__c> dtoList = [SELECT Id FROM DataTransferObject__c WHERE AccountId__c =: accId];
        DataTransferObject__c dto = [SELECT Id, RelatedProcess__c, CommissioningDatePV__c, PVSizekWp__c, VATId__c, SubjectToVat__c, AccountId__c FROM DataTransferObject__c WHERE AccountId__c =: accId];
        Date expectedDate = Date.newInstance(2018, 01, 01);
        List<Case> caseList = [SELECT Id FROM Case WHERE Contract__c =: newContract.Id];

        System.assertEquals(1, dtoList.size());
        System.assertEquals('sFh Billing', dto.RelatedProcess__c);
        System.assertEquals(expectedDate, dto.CommissioningDatePV__c);
        System.assertEquals(10, dto.PVSizekWp__c);
        System.assertEquals('123/4567/12345', dto.VATId__c);
        System.assertEquals('Yes', dto.SubjectToVat__c);

        System.assertEquals(1, caseList.size());
    }
}