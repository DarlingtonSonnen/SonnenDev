/**
 * Created by m.muchow on 16.11.2018.
 * Update 09.01.2019 - M.Muchow - update of testSetup and noAssetButStockitem test for new extension to convert stockitem to asset
 */

@IsTest
private class MonitoringeServicesTriggerHandlerTest
{
    @TestSetup
    static void testSetup() {

        Id personAccId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        List<Account> listAccounts = new List<Account>();
        Account personAcc = new Account(FirstName = 'Person', LastName='Account', RecordTypeId = personAccId, Phone = '123456', PersonEmail = 'test@test.test');
        Account personOtherAcc = new Account(FirstName = 'Person', LastName='Other Account', RecordTypeId = personAccId);
        listAccounts.add(personAcc);
        listAccounts.add(personOtherAcc);
        insert listAccounts;

        Id assetId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();
        List<Asset> listAssets = new List<Asset>();
        Asset sbAsset1 = new Asset(Name = 'SB-Asset1', RecordTypeId = assetId, SerialNumber = '12345', AccountId = personAcc.Id);
        Asset sbAsset2 = new Asset(Name = 'SB-Asset2', RecordTypeId = assetId, SerialNumber = '15975', AccountId = personAcc.Id);
        listAssets.add(sbAsset1);
        listAssets.add(sbAsset2);
        insert listAssets;

        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Contract flatContract = new Contract(RecordTypeId = contractId,	Type__c = 'sonnenBatterieHome-DE', Status = 'Draft',
                                            AccountId = personAcc.Id, StartDate = Date.today().addDays(1), TariffType__c = 'sonnenFlat',
                                            Tariff_Version__c = 'sFh 3.0', BillingStreet__c = 'Test-Street', BillingStreetNumber__c = '1',
                                            BillingCity__c = 'Test City', BillingPostalCode__c = '12345', BillingCountry__c = 'DE');
        insert flatContract;

        MonitoringeServices__c miRecord = new MonitoringeServices__c(Contract__c = flatContract.Id);
        insert miRecord;

        StockItem__c stockItem = new StockItem__c(SerialNumber__c = '6789', Type__c = 'Battery');
        insert stockItem;
    }
    
    @IsTest
    static void assetLinkedToCorrectAccountAndContract()
    {
        Asset sbAsset = [SELECT Id, AccountId FROM Asset WHERE Name = 'SB-Asset1'];
        Account personAccount = [SELECT Id FROM Account WHERE LastName = 'Account'];
        sbAsset.AccountId = personAccount.Id;
        update sbAsset;
        MonitoringeServices__c miRecord = [SELECT Id, BatteryID__c, Asset__c FROM MonitoringeServices__c];

        Test.startTest();
            miRecord.BatteryID__c = '12345';
            update miRecord;
        Test.stopTest();

        MonitoringeServices__c miRecordTest = [SELECT Asset__c FROM MonitoringeServices__c];
        Contract contractTest = [SELECT Asset__c FROM Contract];
        System.assertEquals(miRecordTest.Asset__c, sbAsset.Id);
        System.assertEquals(contractTest.Asset__c, sbAsset.Id);
    }

    @IsTest
    static void assetLinkedToCorrectAccountAndContractHasOtherAsset()
    {
        Asset sbAsset1 = [SELECT Id, AccountId FROM Asset WHERE Name = 'SB-Asset1'];
        Asset sbAsset2 = [SELECT Id, AccountId FROM Asset WHERE Name = 'SB-Asset2'];
        Account personAccount = [SELECT Id FROM Account WHERE LastName = 'Account'];
        sbAsset1.AccountId = personAccount.Id;
        update sbAsset1;
        Contract contract = [SELECT Asset__c FROM Contract];
        contract.Asset__c = sbAsset2.Id;
        update contract;
        MonitoringeServices__c miRecord = [SELECT Id, BatteryID__c, Asset__c FROM MonitoringeServices__c];

        Test.startTest();
        miRecord.BatteryID__c = '12345';
        update miRecord;
        Test.stopTest();

        MonitoringeServices__c miRecordTest = [SELECT Asset__c FROM MonitoringeServices__c];
        Contract contractTest = [SELECT Asset__c FROM Contract];
        List<Case> caseList = [SELECT Id FROM Case];
        System.assertEquals(miRecordTest.Asset__c, sbAsset1.Id);
        System.assertEquals(contractTest.Asset__c, sbAsset2.Id);
        System.assertEquals(1,caseList.size());
    }

    @IsTest
    static void assetLinkedToWrongAccount() {
        Asset sbAsset = [SELECT Id, AccountId FROM Asset WHERE Name = 'SB-Asset1'];
        Account personOtherAccount = [SELECT Id FROM Account WHERE LastName = 'Other Account'];
        sbAsset.AccountId = personOtherAccount.Id;
        update sbAsset;
        MonitoringeServices__c miRecord = [SELECT Id, BatteryID__c FROM MonitoringeServices__c];

        Test.startTest();
        miRecord.BatteryID__c = '12345';
        update miRecord;
        Test.stopTest();

        List<Case> caseList = [SELECT Id FROM Case];
        System.assertEquals(1,caseList.size());
    }

    @IsTest
    static void noAssetButStockitem() {
        Account account = [SELECT PersonContactId FROM Account WHERE LastName = 'Account'];
        Contract contract = [SELECT CustomerSignedId FROM Contract];
        contract.CustomerSignedId = account.PersonContactId;
        update contract;
        MonitoringeServices__c miRecord = [SELECT Id, BatteryID__c FROM MonitoringeServices__c];

        Test.startTest();
        miRecord.BatteryID__c = '6789';
        update miRecord;
        Test.stopTest();

        MonitoringeServices__c miRecordTest = [SELECT Asset__c FROM MonitoringeServices__c];
        Contract contractTest = [SELECT Asset__c FROM Contract];
        List<Asset> assetList = [SELECT Id FROM Asset WHERE SerialNumber = '6789'];
        System.assertEquals(miRecordTest.Asset__c, assetList[0].Id);
        System.assertEquals(contractTest.Asset__c, assetList[0].Id);
        System.assertEquals(1,assetList.size());
    }

    @IsTest
    static void noAssetNoStockitem() {
        MonitoringeServices__c miRecord = [SELECT Id, BatteryID__c FROM MonitoringeServices__c];

        Test.startTest();
        miRecord.BatteryID__c = '98765';
        update miRecord;
        Test.stopTest();

        List<Case> caseList = [SELECT Id FROM Case];
        System.assertEquals(1,caseList.size());
    }
}