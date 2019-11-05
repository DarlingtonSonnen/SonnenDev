/**
 * Created by m.muchow on 09.11.2018.
 */

@IsTest
private class LandingPageDirectMarketingControllerTest
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

        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Contract flatContract = new Contract(RecordTypeId = contractId,	Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, PVAsset__c = pvAsset.Id, StartDate = Date.today().addDays(1), TariffType__c = 'sonnenFlat', Tariff_Version__c = 'sFh 3.0', BillingCountry__c = 'DE');
        insert flatContract;

        Id dmContractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
        Contract dmContract = new Contract(RecordTypeId = dmContractId, Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, ContractNumberSonnenFlatDM__c = flatContract.Id, Asset__c = sbAsset.Id, PVAsset__c = pvAsset.Id);
        insert dmContract;

        List<TermsAndConditions__c> tncList = new List<TermsAndConditions__c>();
        TermsAndConditions__c tnc1 = new TermsAndConditions__c(Name = 'AGB Directmarketing', Type__c = 'Terms and Conditions Direct Marketing', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        TermsAndConditions__c tnc2 = new TermsAndConditions__c(Name = 'AGB Solandeo 20180824', Type__c = 'Terms and Conditions Solandeo', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        TermsAndConditions__c tnc3 = new TermsAndConditions__c(Name = 'Datenschutz und Datennutzung eServices', Type__c = 'Privacy policy eServices', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        TermsAndConditions__c tnc4 = new TermsAndConditions__c(Name = 'Datenschutzbestimmungen Solandeo', Type__c = 'Privacy policy Solandeo', Language__c = 'DE', Country__c = 'DE', Current__c = true);
        tncList.add(tnc1);
        tncList.add(tnc2);
        tncList.add(tnc3);
        tncList.add(tnc4);
        insert tncList;

        //add attachment to TnCs
        List<Attachment> amList = new List<Attachment>();
        Attachment am1 = new Attachment();
        am1.Name = 'AGB Directmarketing';
        am1.ParentId = tnc1.Id;
        Blob bodyBlob1 = Blob.valueOf('body of attachment 1');
        am1.Body = bodyBlob1;
        amList.add(am1);

        Attachment am2 = new Attachment();
        am2.Name = 'AGB Solandeo 20180824';
        am2.ParentId = tnc2.Id;
        Blob bodyBlob2 = Blob.valueOf('body of attachment 2');
        am2.Body = bodyBlob2;
        amList.add(am2);

        Attachment am3 = new Attachment();
        am3.Name = 'Datenschutz und Datennutzung eServices';
        am3.ParentId = tnc3.Id;
        Blob bodyBlob3 = Blob.valueOf('body of attachment 3');
        am3.Body = bodyBlob3;
        amList.add(am3);

        Attachment am4 = new Attachment();
        am4.Name = 'Datenschutzbestimmungen Solandeo';
        am4.ParentId = tnc4.Id;
        Blob bodyBlob4 = Blob.valueOf('bdy of attachment 4');
        am4.Body = bodyBlob4;
        amList.add(am4);

        insert amList;
    }
    
    @IsTest
    static void noTnCwithFeedInDate() {
        Id dmContractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
        Contract newDMContract = [SELECT Id, StartOfCommunityFeedIn__c FROM Contract WHERE RecordTypeId =: dmContractId];
        newDMContract.StartOfCommunityFeedIn__c = Date.today()-250;
        update newDMContract;
        PageReference pageRef = Page.LandingPageDirectMarketing;

        Test.startTest();
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('id', newDMContract.Id);
            ApexPages.currentPage().getParameters().put('language', 'de');
            LandingPageDirectMarketingController controller = new LandingPageDirectMarketingController();
            List<SelectOption> options = controller.getItems();
            controller.assetPVWrapper.sizePV = 9;
            controller.confirm();
        Test.stopTest();

        DataTransferObject__c dto = [SELECT Id, PVSizekWp__c FROM DataTransferObject__c];
        List<Case> createdCase = [SELECT Id FROM Case];
        List<TermsAndConditions__c> tncInsertList = [SELECT Id FROM TermsAndConditions__c];
        System.assertEquals(9, dto.PVSizekWp__c);
        System.assertEquals(1, createdCase.size());
        System.assertEquals(4, tncInsertList.size());

    }

    @IsTest
    static void hasOneTnC() {
        Id dmContractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
        Contract newDMContract = [SELECT Id, ContractNumberSonnenFlatDM__r.CustomerSignedId FROM Contract WHERE RecordTypeId =: dmContractId];
        List<TermsAndConditions__c> tncList = [SELECT Id FROM TermsAndConditions__c ORDER BY Name];
        TnCsAcceptance__c t1 = new TnCsAcceptance__c(Contract__c = newDMContract.Id, Contact__c = newDMContract.ContractNumberSonnenFlatDM__r.CustomerSignedId, TermsAndConditions__c = tncList[1].Id, Accepted__c = true, DateTimeAccepted__c = Datetime.now(), AppAccepted__c = 'Direct Marketing Landing Page');
        insert t1;
        PageReference pageRef = Page.LandingPageDirectMarketing;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', newDMContract.Id);
        ApexPages.currentPage().getParameters().put('language', 'de');
        LandingPageDirectMarketingController controller = new LandingPageDirectMarketingController();
        List<SelectOption> options = controller.getItems();
        controller.confirm();
        Test.stopTest();

        List<Case> createdCase = [SELECT Id FROM Case];
        List<TermsAndConditions__c> tncInsertList = [SELECT Id FROM TermsAndConditions__c];
        System.assertEquals(0, createdCase.size());
        System.assertEquals(4, tncInsertList.size());
    }

    @IsTest
    static void changedData() {
        Id dmContractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('DirectMarketingEEG').getRecordTypeId();
        Contract newDMContract = [SELECT Id, StartOfCommunityFeedIn__c FROM Contract WHERE RecordTypeId =: dmContractId];
            newDMContract.StartOfCommunityFeedIn__c = Date.today()-250;
        update newDMContract;
        Asset pvAsset = [SELECT Id, PVSizekWp__c, FeedInTarif10kWp__c, FeedInTarif10kWp40kWp__c FROM Asset Where Name = 'PV-Asset'];
            pvAsset.PVSizekWp__c = 12;
            pvAsset.FeedInTarif10kWp__c = 12;
            pvAsset.FeedInTarif10kWp40kWp__c = 11;
        update pvAsset;
        Account personAccount = [SELECT Id, SubjectToVat__c, VATId__c FROM Account WHERE LastName = 'Account'];
            personAccount.SubjectToVat__c = 'Yes';
            personAccount.VATId__c = '1234';
        update personAccount;
        PageReference pageRef = Page.LandingPageDirectMarketing;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', newDMContract.Id);
        ApexPages.currentPage().getParameters().put('language', 'de');
        LandingPageDirectMarketingController controller = new LandingPageDirectMarketingController();
        List<SelectOption> options = controller.getItems();
        controller.assetPVWrapper.sizePV = 9;
        controller.assetPVWrapper.FeedInTariff10kWp = 10;
        controller.assetPVWrapper.newDatePV = ('2018-01-01');
        controller.accWrapper.subjectToVat = 'No';
        controller.confirm();
        Test.stopTest();

        DataTransferObject__c dto = [SELECT Id, PVSizekWp__c, FeedIn10kWp__c, FeedIn40kWp__c, CommissioningDatePV__c, SubjectToVat__c, VATId__c FROM DataTransferObject__c];
        List<Case> createdCase = [SELECT Id FROM Case];
        List<TermsAndConditions__c> tncInsertList = [SELECT Id FROM TermsAndConditions__c];
        System.assertEquals(9, dto.PVSizekWp__c);
        System.assertEquals(10, dto.FeedIn10kWp__c);
        System.assertEquals(null, dto.FeedIn40kWp__c);
        System.assertEquals(Date.valueOf('2018-01-01'), dto.CommissioningDatePV__c);
        System.assertEquals('No', dto.SubjectToVat__c);
        System.assertEquals(null, dto.VATId__c);
        System.assertEquals(1, createdCase.size());
        System.assertEquals(4, tncInsertList.size());
    }
}