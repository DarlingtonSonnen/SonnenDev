/**
 * Created by m.muchow on 20.11.2018.
 */

@IsTest
private class CreateAndSendEmailTest
{
    @TestSetup
    static void testSetup() {

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
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
            Contract flatContract = new Contract(RecordTypeId = contractId,	Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id, StartDate = Date.today().addDays(1), TariffType__c = 'sonnenFlat', Tariff_Version__c = 'sFh 3.0', BillingCountry__c = 'DE', OpportunitySource__c = opp.Id, BankData__c = bankData.Id, CommunityMembership__c = comMem.Id);
            insert flatContract;

            MeterInstallation__c miRecord = new MeterInstallation__c(Account__c = personAcc.Id, Contract__c = flatContract.Id);
            insert miRecord;

            MonitoringeServices__c moneServices = new MonitoringeServices__c(Contract__c = flatContract.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id);
            insert moneServices;

            Id dmContractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
            Contract dmContract = new Contract(RecordTypeId = dmContractId, Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, ContractNumberSonnenFlatDM__c = flatContract.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id);
            insert dmContract;

            EmailTemplate emailTemplate = new EmailTemplate(IsActive = true, Subject = 'Test', Body = 'Test Body', Name = 'emailTemplate', DeveloperName = 'emailTemplate', TemplateType = 'text', FolderId = UserInfo.getUserId());
            insert emailTemplate;

            //Document document = new Document(Body = Blob.valueOf('Test Body'), Name = 'Test');
            //insert document;

            ContentVersion cV = new ContentVersion(Title = 'Test CV', VersionData = Blob.valueOf('Test Blob'), PathOnClient ='/abc.txt');
            insert cV;

            Id cVDocId = [SELECT Id FROM ContentDocument WHERE Title = 'Test CV' LIMIT 1].Id;

            ContentDocumentLink cDL = new ContentDocumentLink(ContentDocumentId = cVDocId, LinkedEntityId = emailTemplate.Id, ShareType= 'V', Visibility = 'AllUsers');
            insert cDL;
        }
    }
    
    @IsTest
    static void CreateAndSendEmailTest() {
        Account acc = [SELECT Id, PersonContactId FROM Account];
        Contract sfContract = [SELECT Id, BankData__c, CommunityMembership__c, OpportunitySource__c, Asset__c, PVAsset__c FROM Contract WHERE TariffType__c = 'sonnenFlat'];
        Contract dmContact = [SELECT Id FROM Contract WHERE ContractNumberSonnenFlatDM__c =: sfContract.Id];
        OrgWideEmailAddress owAddr = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress LIMIT 1];
        MeterInstallation__c mI = [SELECT Id FROM MeterInstallation__c];
        MonitoringeServices__c moneServices = [SELECT Id FROM MonitoringeServices__c WHERE Contract__c =: sfContract.Id LIMIT 1];

        Test.startTest();
        CreateAndSendEmail.EmailRequest request = new CreateAndSendEmail.EmailRequest();
        request.ContactId = null;
        request.SaveActivityToObjectId = null;
        request.EmailToAddress = null;
        request.EmailTemplate = null;
        request.EmailFromAddress = null;
        request.Account = acc.Id;
        request.Contact = acc.PersonContactId;
        request.BankData = sfContract.BankData__c;
        request.CommmunityMembership = sfContract.CommunityMembership__c;
        request.MeterInstallation = mI.Id;
        request.MonitoringeServices = moneServices.Id;
        request.Opportunity = sfContract.OpportunitySource__c;
        request.sonnenFlatContract = sfContract.Id;
        request.DirectMarketingContract = dmContact.Id;
        request.BatteryAsset = sfContract.Asset__c;
        request.PVPlantAsset = sfContract.PVAsset__c;

        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});

        request.ContactId = acc.PersonContactId;
        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});

        request.SaveActivityToObjectId = sfContract.Id;
        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});

        request.EmailToAddress = 'email@mailforspam.com';
        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});

        request.EmailTemplate = 'emailTemplate';
        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});

        request.EmailFromAddress = owAddr.Address;
        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});
        Test.stopTest();

        List<Case> caseCreated = [SELECT Id FROM Case];
        List<Email__c> emailRecords = [SELECT Id FROM Email__c];
        System.assertEquals(true,caseCreated.size() >= 5);
        System.assertEquals(1, emailRecords.size());
    }
}