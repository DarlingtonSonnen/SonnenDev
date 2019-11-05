@IsTest
public class AssetTriggerHandlerTest {

    @TestSetup
    static void testSetup() {

        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();

        Account aPartner = new Account(Name = 'Test Partner', RecordTypeId = aPartnerRecordTypeId);
        insert aPartner;

        Contact cInstaller = new Contact(FirstName = 'Test', LastName = 'Installer', AccountId = aPartner.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insert cInstaller;

        Product2 product10 = new Product2(Name = 'eco 10');
        insert product10;

        Date dateAssetOK = Date.newInstance(2019, 01, 01);
        Id bateryId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();
        Certification__c cert = new Certification__c(Name = 'Test Cert');
        insert cert;

        Date certDate = Date.newInstance(2018, 12, 01);
        Certificate__c certif = new Certificate__c(Description__c = 'Certestficate', CertificateRevoked__c = false, StartDate__c = certDate, Certification__c = cert.Id, Contact__c = cInstaller.Id);
        insert certif;

        ProductCertification__c productCertif = new ProductCertification__c(Product__c = product10.Id);
        insert productCertif;

        ProdCertJunction__c prodCertJun = new ProdCertJunction__c(Certification__c = cert.Id, ProductCertification__c = productCertif.Id);
        insert prodCertJun;

        Asset bateryAsset = new Asset(Name = 'Test-Asset', RecordTypeId = bateryId, AccountId = aPartner.Id, Product2Id = product10.Id, Installer__c = cInstaller.Id, CommissioningDateTime__c = dateAssetOK);
        insert bateryAsset;
    }

    @IsTest
    static void assetCertificationStatusDateOK() {

        Test.startTest();

        Asset bateryAsset = [SELECT Id, CommissioningDateTime__c,CertificationStatus__c FROM Asset LIMIT 1];
        bateryAsset.CommissioningDateTime__c = Date.newInstance(2020, 01, 01);
        update bateryAsset;

        Test.stopTest();
        List<Asset> assets = [SELECT Id,CertificationStatus__c FROM Asset LIMIT 1];
        System.assertEquals(true, assets[0].CertificationStatus__c);
    }

    @IsTest
    static void assetCertificationStatusOldDate() {

        Test.startTest();

        Asset bateryAsset = [SELECT Id,CommissioningDateTime__c,CertificationStatus__c FROM Asset LIMIT 1];
        bateryAsset.CommissioningDateTime__c = Date.newInstance(2000, 01, 01);
        update bateryAsset;

        Test.stopTest();
        List<Asset> updatedAsset = [SELECT Id, CommissioningDateTime__c, CertificationStatus__c FROM Asset LIMIT 1];
        System.assertEquals(false, updatedAsset[0].CertificationStatus__c);
    }

    @IsTest
    static void assetInsertCertificationStatus() {

        Contact cInstaller = [SELECT Id FROM Contact LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        Id bateryId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();


        Test.startTest();

        Asset bateryAsset = new Asset(Name = 'TestAsset');
        bateryAsset.RecordTypeId = bateryId;
        bateryAsset.Installer__c = cInstaller.Id;
        bateryAsset.AccountId = acc.Id;
        bateryAsset.CommissioningDateTime__c = Date.newInstance(2020, 01, 01);
        bateryAsset.Product2Id = prod.Id;
        insert bateryAsset;

        Test.stopTest();

        List<Asset> assets = [SELECT Id,CertificationStatus__c FROM Asset WHERE Name = 'TestAsset'];
        System.assertEquals(true, assets[0].CertificationStatus__c);
    }

    @IsTest
    static void assetCertificationStatusUpdInstallerNoCertification() {

        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();

        Test.startTest();

        Account aPartner = new Account(Name = 'Test Partner1', RecordTypeId = aPartnerRecordTypeId);
        insert aPartner;

        Contact cInstaller = new Contact(FirstName = 'Test1', LastName = 'Installer1', AccountId = aPartner.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insert cInstaller;

        Asset bateryAsset = [SELECT Id,CommissioningDateTime__c,Installer__c,CertificationStatus__c,ContactId,Product2Id FROM Asset LIMIT 1];
        bateryAsset.Installer__c = cInstaller.Id;
        update bateryAsset;

        Test.stopTest();
        List<Asset> assets = [SELECT Id,CertificationStatus__c FROM Asset LIMIT 1];
        System.assertEquals(false, assets[0].CertificationStatus__c);
    }

    @IsTest
    static void assetCertificationStatusUpdInstallerCertificated() {

        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();

        Test.startTest();

        Account aPartner = new Account(Name = 'Test Partner1', RecordTypeId = aPartnerRecordTypeId);
        insert aPartner;

        Contact cInstaller = new Contact(FirstName = 'Test1', LastName = 'Installer1', AccountId = aPartner.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insert cInstaller;

        Certification__c cert = new Certification__c(Name = 'Test Cert');
        insert cert;

        Date certDate = Date.newInstance(2010, 12, 01);
        Certificate__c certif = new Certificate__c(Description__c = 'Certestficate', CertificateRevoked__c = false, StartDate__c = certDate, Certification__c = cert.Id, Contact__c = cInstaller.Id);
        insert certif;

        Product2 product = [SELECT Id FROM Product2 LIMIT 1].get(0);
        ProductCertification__c productCertif = new ProductCertification__c(Product__c = product.Id);
        insert productCertif;

        ProdCertJunction__c prodCertJun = new ProdCertJunction__c(Certification__c = cert.Id, ProductCertification__c = productCertif.Id);
        insert prodCertJun;


        Asset bateryAsset = [SELECT Id,CommissioningDateTime__c,Installer__c,CertificationStatus__c,ContactId,Product2Id FROM Asset LIMIT 1];
        bateryAsset.Installer__c = cInstaller.Id;
        update bateryAsset;

        Test.stopTest();
        List<Asset> assets = [SELECT Id,CertificationStatus__c FROM Asset LIMIT 1];
        System.assertEquals(true, assets[0].CertificationStatus__c);
    }

    @IsTest
    static void assetCertificationStatusRevoked() {

        Test.startTest();

        Certificate__c certif = [SELECT Id FROM Certificate__c LIMIT 1];
        certif.CertificateRevoked__c = true;
        certif.RevokedReason__c = 'TEST';
        certif.StartDate__c = Date.newInstance(2019, 01, 01);
        update certif;

        Asset bateryAsset = [SELECT Id,Installer__c,CertificationStatus__c,Product2Id FROM Asset LIMIT 1];
        bateryAsset.CommissioningDateTime__c = Date.newInstance(2020, 01, 01);
        update bateryAsset;

        Test.stopTest();

        List<Asset> assets = [SELECT Id,CertificationStatus__c FROM Asset LIMIT 1];
        System.assertEquals(false, assets[0].CertificationStatus__c);
    }
}