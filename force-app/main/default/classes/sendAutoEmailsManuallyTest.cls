/**
 * Created by m.muchow on 06.02.2019.
 */

@IsTest
private class sendAutoEmailsManuallyTest
{
    @TestSetup
    static void testSetup() {
        Id personAccId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Account personAcc = new Account(FirstName = 'Person', LastName='Account', RecordTypeId = personAccId);
        insert personAcc;

        Id assetSBID = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();
        Asset sbAsset = new Asset(Name = 'SB-Asset', RecordTypeId = assetSBID, AccountId = personAcc.Id, SerialNumber = '12345');
        insert sbAsset;

        Id assetPVId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('PVPlant').getRecordTypeId();
        Asset pvAsset = new Asset(Name = 'PV-Asset', RecordTypeId = assetPVId, AccountId = personAcc.Id, PVSizekWp__c = 8, CommissioningDatePV__c = Date.today());
        insert pvAsset;

        Id oppId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('WebOrder').getRecordTypeId();
        Opportunity opp = new Opportunity(Name = 'WebOrder', RecordTypeId = oppId, StageName = 'Requested', CloseDate = Date.today());
        insert opp;

        BankData__c bankData = new BankData__c(Account__c = personAcc.Id, SepaDate__c = Date.today(), FirstName__c = 'FirstName',  LastName__c = 'LastName', IBAN__c = '1234567890');
        insert bankData;

        CommunityMembership__c comMem = new CommunityMembership__c(Account__c = personAcc.Id);
        insert comMem;

        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Id personContactId = [SELECT PersonContactId FROM Account WHERE LastName = 'Account'].PersonContactId;
        Contract flatContract = new Contract(RecordTypeId = contractId,	Type__c = 'sonnenBatterieHome-DE', Status = 'Draft',
                AccountId = personAcc.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id, StartDate = Date.today().addDays(1),
                TariffType__c = 'sonnenFlat', Tariff_Version__c = 'sFh 3.0', BillingCountry__c = 'DE', OpportunitySource__c = opp.Id,
                BankData__c = bankData.Id, CommunityMembership__c = comMem.Id, CustomerSignedId = personContactId, 
                ContractingPartyEmail__c = 'email@mailforspam.com');
        insert flatContract;

        MeterInstallation__c miRecord = new MeterInstallation__c(Account__c = personAcc.Id, Contract__c = flatContract.Id);
        insert miRecord;

        MonitoringeServices__c moneServices = new MonitoringeServices__c(Contract__c = flatContract.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id);
        insert moneServices;

        Id dmContractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
        Contract dmContract = new Contract(RecordTypeId = dmContractId, Type__c = 'sonnenBatterieHome-DE', Status = 'Draft',
                AccountId = personAcc.Id, ContractNumberSonnenFlatDM__c = flatContract.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id);
        insert dmContract;
    }
    
    @IsTest
    static void sendAutoEmailsManuallyTest(){
        Id recordId = [SELECT Id FROM Contract WHERE TariffType__c = 'sonnenFlat'].Id;
        String template = [SELECT TemplateList__c FROM Manually_Email_Setting__mdt WHERE RecordTypeDeveloperName__c = 'SonnenFlat'].TemplateList__c.substringBefore(',');
    
        Test.startTest();
        List<EmailTemplate> tempList = sendAutoEmailsManually.getEmailTemplateList(recordId);
        sendAutoEmailsManually.sendEmail(recordId, template);
        Test.stopTest();

        List<Email__c> emailRecords = [SELECT Id FROM Email__c];
        System.assertEquals(true, tempList.size() >= 1);
        System.assertEquals(1, emailRecords.size());
    }
}