/**
 * Created by m.muchow on 25.10.2018.
 */
@IsTest
public with sharing class LandingPageOrderAUDControllerTest {
    @TestSetup
    static void testSetup() {
        //create Partner Account if PV Installer TnC is necessary
            //Id partnerAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Partner').getRecordTypeId();
            //Account partner = new Account(RecordTypeId = partnerAccRecordTypeId, Name = 'Test Partner', Website = 'Http//www.google.de');
            //insert partner;

        //create Person Account
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Account person = new Account(FirstName = 'John', LastName = 'Mate', RecordTypeId = personAccRecordTypeId);
        insert person;

        //create WebOrder Opportunity
        Id oppRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('WebOrder').getRecordTypeId();
        Opportunity opp = new Opportunity(Name = 'WebOrder Test', StageName = 'Requested', CloseDate = Date.today()+10, Account = person, TargetCountry__c = 'AU', Language__c = 'EN',
                Amount = 23905.00, UpfrontPayment__c = 4000, WebOrderType__c = 'Battery;PV Module',
                ShippingStreet__c = 'Flushcombe Road', ShippingStreetNo__c = '100', ShippingAdditional__c = 'APT 15', ShippingPostalCode__c = '2148',
                ShippingCity__c ='Blacktown', ShippingState__c = 'NSW', ShippingCountryIsoCode__c = 'AU', ProductName__c = 'sonnenInklusiv Special 6.75', BatteryCapacity__c = 6.75, RecordTypeId = oppRecordTypeId);
            //insert Recommended Partner if PV Installer TnC is necessary
                //opp.RecommendedPartner__c = partner.Id;
        insert opp;

        //create TnCs
        List<TermsAndConditions__c> tncList = new List<TermsAndConditions__c>();
        TermsAndConditions__c tnc1 = new TermsAndConditions__c(Name = 'TnC', Type__c = 'General TnC', Language__c = 'EN', Country__c = 'AU', Current__c = true);
        TermsAndConditions__c tnc2 = new TermsAndConditions__c(Name = 'Guarantee', Type__c = 'Manufacture Guarantee', Language__c = 'EN', Country__c = 'AU', Current__c = true);
        tncList.add(tnc1);
        tncList.add(tnc2);
        insert tncList;

        //add attachment to TnCs
        List<Attachment> amList = new List<Attachment>();
        Attachment am1 = new Attachment();
        am1.Name = 'Privacy policy';
        am1.ParentId = tnc1.Id;
        Blob bodyBlob1 = Blob.valueOf('bdy of attachment 1');
        am1.Body = bodyBlob1;
        amList.add(am1);

        Attachment am2 = new Attachment();
        am2.Name = 'General terms and conditions';
        am2.ParentId = tnc2.Id;
        Blob bodyBlob2 = Blob.valueOf('bdy of attachment 2');
        am2.Body = bodyBlob2;
        amList.add(am2);

        insert amList;
    }

    //test Landing Page No Financing
    @IsTest
    static void noFinancing() {
        Opportunity opp = [SELECT Id, Financing__c FROM Opportunity WHERE ProductName__c = 'sonnenInklusiv Special 6.75'];
        PageReference pageRef = Page.LandingPageOrderAUD;

        Test.startTest();
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('id', opp.Id);
            ApexPages.currentPage().getParameters().put('language', 'en');
            LandingPageOrderAUDController controller = new LandingPageOrderAUDController();
            controller.confirm();
        Test.stopTest();

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c WHERE (TermsAndConditions__r.Type__c = 'General TnC' OR  TermsAndConditions__r.Type__c = 'Manufacture Guarantee')].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);
    }

    //test Landing Page Part Financing
    @IsTest
    static void partFinancing() {
        Opportunity opp = [SELECT Id, Financing__c FROM Opportunity WHERE ProductName__c = 'sonnenInklusiv Special 6.75'];
        opp.Financing__c = 'PartFinancing';
        update opp;
        PageReference pageRef = Page.LandingPageOrderAUD;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('language', 'en');
        LandingPageOrderAUDController controller = new LandingPageOrderAUDController();
        controller.confirm();
        Test.stopTest();

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c WHERE (TermsAndConditions__r.Type__c = 'General TnC' OR  TermsAndConditions__r.Type__c = 'Manufacture Guarantee')].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);
    }

    //test Landing Page Full Financing
    @IsTest
    static void fullFinancing() {
        Opportunity opp = [SELECT Id, Financing__c FROM Opportunity WHERE ProductName__c = 'sonnenInklusiv Special 6.75'];
        opp.Financing__c = 'FullFinancing';
        update opp;
        PageReference pageRef = Page.LandingPageOrderAUD;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('language', 'en');
        LandingPageOrderAUDController controller = new LandingPageOrderAUDController();
        controller.confirm();
        Test.stopTest();

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c WHERE (TermsAndConditions__r.Type__c = 'General TnC' OR  TermsAndConditions__r.Type__c = 'Manufacture Guarantee')].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);
    }

    //test Landing Page only Battery & no Shipping Additional
    @IsTest
    static void noBatteryNoAdditional() {
        Opportunity opp = [SELECT Id, WebOrderType__c, ShippingAdditional__c FROM Opportunity WHERE ProductName__c = 'sonnenInklusiv Special 6.75'];
        opp.WebOrderType__c = 'Battery';
        opp.ShippingAdditional__c = '';
        update opp;
        PageReference pageRef = Page.LandingPageOrderAUD;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('language', 'en');
        LandingPageOrderAUDController controller = new LandingPageOrderAUDController();
        controller.confirm();
        Test.stopTest();

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c WHERE (TermsAndConditions__r.Type__c = 'General TnC' OR  TermsAndConditions__r.Type__c = 'Manufacture Guarantee')].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);
    }

    //test Landing Page has TnC already
    @IsTest
    static void hasTnC() {
        Opportunity opp = [SELECT Id, PrimaryContact__c FROM Opportunity WHERE ProductName__c = 'sonnenInklusiv Special 6.75'];
        List<TermsAndConditions__c> tncList = [SELECT Id FROM TermsAndConditions__c ORDER BY Name];
        List<TnCsAcceptance__c> accTnCList = new List<TnCsAcceptance__c>();
        TnCsAcceptance__c t1 = new TnCsAcceptance__c(Opportunity__c = opp.Id, Contact__c = opp.PrimaryContact__c, TermsAndConditions__c = tncList[1].Id, Accepted__c = true, DateTimeAccepted__c = Datetime.now(), AppAccepted__c = 'AU Web Order Landing Page');
        TnCsAcceptance__c t2 = new TnCsAcceptance__c(Opportunity__c = opp.Id, Contact__c = opp.PrimaryContact__c, TermsAndConditions__c = tncList[0].Id, Accepted__c = true, DateTimeAccepted__c = Datetime.now(), AppAccepted__c = 'AU Web Order Landing Page');
        accTnCList.add(t1);
        accTnCList.add(t2);
        insert accTnCList;
        PageReference pageRef = Page.LandingPageOrderAUD;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('language', 'en');
        LandingPageOrderAUDController controller = new LandingPageOrderAUDController();
        controller.confirm();
        Test.stopTest();

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c WHERE (TermsAndConditions__r.Type__c = 'General TnC' OR  TermsAndConditions__r.Type__c = 'Manufacture Guarantee')].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);
    }

    //test Landing Page has only one TnC already
    @IsTest
    static void hasOneTnC() {
        Opportunity opp = [SELECT Id, PrimaryContact__c FROM Opportunity WHERE ProductName__c = 'sonnenInklusiv Special 6.75'];
        List<TermsAndConditions__c> tncList = [SELECT Id FROM TermsAndConditions__c ORDER BY Name];
        TnCsAcceptance__c t1 = new TnCsAcceptance__c(Opportunity__c = opp.Id, Contact__c = opp.PrimaryContact__c, TermsAndConditions__c = tncList[1].Id, Accepted__c = true, DateTimeAccepted__c = Datetime.now(), AppAccepted__c = 'AU Web Order Landing Page');
        insert t1;
        PageReference pageRef = Page.LandingPageOrderAUD;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', opp.Id);
        ApexPages.currentPage().getParameters().put('language', 'en');
        LandingPageOrderAUDController controller = new LandingPageOrderAUDController();
        controller.confirm();
        Test.stopTest();

        // assert that TnCsAssets have been created
        System.assertEquals(2, [SELECT Id FROM TnCsAcceptance__c WHERE (TermsAndConditions__r.Type__c = 'General TnC' OR  TermsAndConditions__r.Type__c = 'Manufacture Guarantee')].size());
        System.assert([SELECT DateTimeAccepted__c FROM TnCsAcceptance__c LIMIT 1].DateTimeAccepted__c != null);
    }
}