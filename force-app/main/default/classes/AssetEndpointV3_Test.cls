/**
 * Created by m.muchow on 09.05.2019.
 */

@IsTest
public with sharing class AssetEndpointV3_Test {

    @TestSetup
    static void testSetup() {
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();
        Id casTechnicalRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('TechnicalSupportCase').getRecordTypeId();

        List<Account> insertAccounts = new List<Account>();
        List<Product2> insertProducts = new List<Product2>();
        List<StockItem__c> insertStockItems = new List<StockItem__c>();

        Account aDistributor = new Account(Name = 'Test Distributor', RecordTypeId = aPartnerRecordTypeId);
        insertAccounts.add(aDistributor);

        Account aPartner = new Account(Name = 'Test Partner', RecordTypeId = aPartnerRecordTypeId);
        insertAccounts.add(aPartner);

        insert insertAccounts;

        Contact cInstaller = new Contact(FirstName = 'Test', LastName = 'Installer', AccountId = aPartner.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insert cInstaller;

        Product2 product10 = new Product2(Name = 'eco 10');
        insertProducts.add(product10);

        Product2 product11 = new Product2(Name = 'eco 11');
        insertProducts.add(product11);

        insert insertProducts;

        StockItem__c stockItemNew = new StockItem__c(SerialNumber__c = '56163', Type__c = 'Battery', Product2__c = product10.Id, ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10, ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemNew);

        StockItem__c stockItemChange = new StockItem__c(SerialNumber__c = '12345', Type__c = 'Battery', Product2__c = product11.Id, ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-4, ShippingDate__c = System.today(), DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemChange);

        StockItem__c stockItemSlaveOne = new StockItem__c(SerialNumber__c = '99997', Type__c = 'Battery', Product2__c = product10.Id, ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10, ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemSlaveOne);

        StockItem__c stockItemSlaveTwo = new StockItem__c(SerialNumber__c = '99998', Type__c = 'Battery', Product2__c = product10.Id, ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10, ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemSlaveTwo);

        insert insertStockItems;

        Case cLinkCase = new Case(Subject = 'New Case', Status = 'New', Type = 'Request', Impact__c = '2. High', StockItem__c = stockItemNew.Id, RecordTypeId = casTechnicalRecordTypeId);
        insert cLinkCase;

        Attachment att = new Attachment(Name = 'Test Attachment', ParentId = stockItemNew.Id, Body = EncodingUtil.base64Decode('Attachment Body'));
        insert att;

        ContentVersion cV = new ContentVersion(Title = 'Test File', PathOnClient = 'Test File', VersionData = EncodingUtil.base64Decode('File Body'), FirstPublishLocationId = stockItemNew.Id);
        insert cV;
    }

    static testMethod String getJSONNew() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "56163","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "false","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "false","IN_riverbox_old_serial": "12345","IN_riverbox_serial_imported": "false"}]';
        return bodyJSON;
    }

    static testMethod String getJSONChange() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "12345","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "true","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-06-24 12:20:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "true","IN_riverbox_old_serial": "56163","IN_riverbox_serial_imported": "true"}]';
        return bodyJSON;
    }

    static testMethod String getJSONChangeManually() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "12345","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "true","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-06-24 12:20:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "true","IN_riverbox_old_serial": "56163","IN_riverbox_serial_imported": "false"}]';
        return bodyJSON;
    }

    static testMethod String getJSONNewNoInstaller() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "56163","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "789456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "false","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "false","IN_riverbox_old_serial": "12345","IN_riverbox_serial_imported": "true"}]';
        return bodyJSON;
    }

    static testMethod String getJSONCascadingNew() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "56163","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "false","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade":{"role":"master","nodes":[{"role":"slave","serial":99997},{"role":"slave","serial":99998}]},"IN_riverbox_changed": "false","IN_riverbox_old_serial": "","IN_riverbox_serial_imported": "true"}]';
        return bodyJSON;
    }

    static testMethod String getJSONCascadingMasterChange() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "12345","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "true","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade":{"role":"master","nodes":[{"role":"slave","serial":99997},{"role":"slave","serial":99998}]},"IN_riverbox_changed": "true","IN_riverbox_old_serial": "56163","IN_riverbox_serial_imported": "true"}]';
        return bodyJSON;
    }

    static testMethod String getJSONCascadingSlaveChange() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "12345","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "false","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade":{"role":"slave","nodes":[{"role":"master","serial":56163},{"role":"slave","serial":99998}]},"IN_riverbox_changed": "true","IN_riverbox_old_serial": "99997","IN_riverbox_serial_imported": "true"}]';
        return bodyJSON;
    }

    static testMethod String getJSONNewNoStockItem() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "98745","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "false","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "false","IN_riverbox_old_serial": "12345","IN_riverbox_serial_imported": "false"}]';
        return bodyJSON;
    }

    @IsTest
    static void testSystemNew() {
        Test.startTest();

        RestRequest request = new RestRequest();

        request.requestURI = '/assetEndpointAPI/';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNew());

        RestContext.request = request;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id compEURecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();
        Id currentUserId = UserInfo.getUserId();

        Account aPersonTest = [SELECT Id FROM Account WHERE FirstName = 'Max' AND LastName = 'Power'];
        Account aInstallerTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Partner'];
        Account aDistributorTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Distributor'];
        Contact conInstallerTest = [SELECT Id FROM Contact WHERE RecordTypeId =: conInstallerRecordTypeId];
        StockItem__c stockItemTest = [SELECT Id, Account__c, Asset__c, Component__c, Product2__c, RecordTypeId FROM StockItem__c WHERE SerialNumber__c = '56163'];
        List<Asset> assetTestList = [SELECT Id, Product2Id, SerialNumber, InstallingCompany__c, Installer__c, DistributorSBC__c FROM Asset];
        List<Component__c> componentTestList = [SELECT Id, Current__c, SerialNumber__c FROM Component__c WHERE RecordTypeId =: compEURecordTypeId];
        List<Case> caseTestList = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case'];
        Case caseLinkTest = [SELECT Id, AssetId FROM Case WHERE Subject = 'New Case'];
        Attachment attTest = [SELECT Id, ParentId FROM Attachment];
        Id cVDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test File'].ContentDocumentId;
        ContentDocumentLink cDL = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId =: cVDocId AND LinkedEntityId !=: stockItemTest.Id AND LinkedEntityId !=: currentUserId];
        List<Log__c> logList = [SELECT Id FROM Log__c];

        System.assertEquals(aPersonTest.Id, stockItemTest.Account__c);
        System.assertEquals(1, assetTestList.size());
        System.assertEquals(assetTestList[0].Id, stockItemTest.Asset__c);
        System.assertEquals(aInstallerTest.Id, assetTestList[0].InstallingCompany__c);
        System.assertEquals(aDistributorTest.Id, assetTestList[0].DistributorSBC__c);
        System.assertEquals(conInstallerTest.Id, assetTestList[0].Installer__c);
        System.assertEquals(1, componentTestList.size());
        System.assertEquals(componentTestList[0].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertEquals(componentTestList[0].Id, stockItemTest.Component__c);
        System.assertEquals(true, componentTestList[0].Current__c);
        System.assertEquals(stockItemConvertedId, stockItemTest.RecordTypeId);
        System.assertEquals(stockItemTest.Product2__c, assetTestList[0].Product2Id);
        System.assertEquals(2, caseTestList.size());
        System.assertEquals('No Service Partner', caseTest.Subject);
        System.assertEquals(assetTestList[0].Id, caseLinkTest.AssetId);
        System.assertEquals(assetTestList[0].Id, attTest.ParentId);
        System.assertEquals(assetTestList[0].Id, cDL.LinkedEntityId);
        System.assertEquals(1, logList.size());
    }

    @IsTest
    static void testSystemChange() {
        Test.startTest();

        RestRequest requestNew = new RestRequest();

        requestNew.requestURI = '/assetEndpointAPI/';
        requestNew.httpMethod = 'POST';
        requestNew.requestBody = Blob.valueOf(getJSONNew());

        RestContext.request = requestNew;

        AssetEndpointV3.handlePost();

        RestRequest requestChange = new RestRequest();

        requestChange.requestURI = '/assetEndpointAPI/';
        requestChange.httpMethod = 'POST';
        requestChange.requestBody = Blob.valueOf(getJSONChange());

        RestContext.request = requestChange;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id compEURecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE FirstName = 'Max' AND LastName = 'Power'];
        Account aInstallerTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Partner'];
        Account aDistributorTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Distributor'];
        Contact conInstallerTest = [SELECT Id FROM Contact WHERE RecordTypeId =: conInstallerRecordTypeId];
        List<StockItem__c> stockItemTestList = [SELECT Id, Account__c, Asset__c, Component__c, Product2__c, SerialNumber__c, RecordTypeId FROM StockItem__c WHERE RecordTypeId =: stockItemConvertedId ORDER BY CreatedDate ASC];
        List<Asset> assetTestList = [SELECT Id, Product2Id, SerialNumber, InstallingCompany__c, Installer__c, DistributorSBC__c FROM Asset];
        List<Component__c> componentTestList = [SELECT Id, Current__c, SerialNumber__c, OldComponent__c, NewComponent__c FROM Component__c WHERE RecordTypeId =: compEURecordTypeId ORDER BY CreatedDate ASC];
        List<Case> caseTestList = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case'];

        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[1].Account__c);
        System.assertEquals(stockItemConvertedId, stockItemTestList[0].RecordTypeId);
        System.assertEquals(stockItemConvertedId, stockItemTestList[1].RecordTypeId);
        System.assertEquals(1, assetTestList.size());
        System.assertEquals(assetTestList[0].Id, stockItemTestList[0].Asset__c);
        System.assertEquals(assetTestList[0].Id, stockItemTestList[1].Asset__c);
        System.assertEquals(aInstallerTest.Id, assetTestList[0].InstallingCompany__c);
        System.assertEquals(aDistributorTest.Id, assetTestList[0].DistributorSBC__c);
        System.assertEquals(conInstallerTest.Id, assetTestList[0].Installer__c);
        System.assertEquals(componentTestList[1].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertNotEquals(componentTestList[0].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertEquals(2, componentTestList.size());
        System.assertEquals(componentTestList[0].Id, stockItemTestList[0].Component__c);
        System.assertEquals(componentTestList[1].Id, stockItemTestList[1].Component__c);
        System.assertEquals(stockItemTestList[0].SerialNumber__c, componentTestList[0].SerialNumber__c);
        System.assertEquals(stockItemTestList[1].SerialNumber__c, componentTestList[1].SerialNumber__c);
        System.assertEquals(false, componentTestList[0].Current__c);
        System.assertEquals(true, componentTestList[1].Current__c);
        System.assertEquals(componentTestList[1].Id, componentTestList[0].NewComponent__c);
        System.assertEquals(componentTestList[0].Id, componentTestList[1].OldComponent__c);
        System.assertEquals(stockItemTestList[0].Product2__c, assetTestList[0].Product2Id);
        //Product on Asset should stay the old one
        System.assertNotEquals(stockItemTestList[1].Product2__c, assetTestList[0].Product2Id);
        System.assertEquals(2, caseTestList.size());
        System.assertEquals('No Service Partner', caseTest.Subject);
    }

    @IsTest
    static void testSystemChangeManually() {
        Test.startTest();

        RestRequest requestNew = new RestRequest();

        requestNew.requestURI = '/assetEndpointAPI/';
        requestNew.httpMethod = 'POST';
        requestNew.requestBody = Blob.valueOf(getJSONNew());

        RestContext.request = requestNew;

        AssetEndpointV3.handlePost();

        RestRequest requestChange = new RestRequest();

        requestChange.requestURI = '/assetEndpointAPI/';
        requestChange.httpMethod = 'POST';
        requestChange.requestBody = Blob.valueOf(getJSONChangeManually());

        RestContext.request = requestChange;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id compEURecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();
        Id stockItemNotConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Default').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE FirstName = 'Max' AND LastName = 'Power'];
        Account aInstallerTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Partner'];
        Account aDistributorTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Distributor'];
        Contact conInstallerTest = [SELECT Id FROM Contact WHERE RecordTypeId =: conInstallerRecordTypeId];
        List<StockItem__c> stockItemTestList = [SELECT Id, Account__c, Asset__c, Component__c, Product2__c, SerialNumber__c, RecordTypeId FROM StockItem__c WHERE RecordTypeId =: stockItemConvertedId OR SerialNumber__c = '12345' ORDER BY CreatedDate ASC];
        List<Asset> assetTestList = [SELECT Id, Product2Id, SerialNumber, InstallingCompany__c, Installer__c, DistributorSBC__c FROM Asset];
        List<Component__c> componentTestList = [SELECT Id, Current__c, SerialNumber__c, OldComponent__c, NewComponent__c FROM Component__c WHERE RecordTypeId =: compEURecordTypeId ORDER BY CreatedDate ASC];
        List<Case> caseTestList = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case' AND Subject != 'No Service Partner'];

        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(null, stockItemTestList[1].Account__c);
        System.assertEquals(stockItemConvertedId, stockItemTestList[0].RecordTypeId);
        System.assertEquals(stockItemNotConvertedId, stockItemTestList[1].RecordTypeId);
        System.assertEquals(1, assetTestList.size());
        System.assertEquals(assetTestList[0].Id, stockItemTestList[0].Asset__c);
        System.assertEquals(null, stockItemTestList[1].Asset__c);
        System.assertEquals(aInstallerTest.Id, assetTestList[0].InstallingCompany__c);
        System.assertEquals(aDistributorTest.Id, assetTestList[0].DistributorSBC__c);
        System.assertEquals(conInstallerTest.Id, assetTestList[0].Installer__c);
        System.assertEquals(componentTestList[0].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertEquals(1, componentTestList.size());
        System.assertEquals(componentTestList[0].Id, stockItemTestList[0].Component__c);
        System.assertEquals(stockItemTestList[0].SerialNumber__c, componentTestList[0].SerialNumber__c);
        System.assertEquals(true, componentTestList[0].Current__c);
        System.assertEquals(null, componentTestList[0].NewComponent__c);
        System.assertEquals(stockItemTestList[0].Product2__c, assetTestList[0].Product2Id);
        System.assertEquals(3, caseTestList.size());
        System.assertEquals('Manual Serial Number verification needed', caseTest.Subject);
    }

    @IsTest
    static void testNoInstaller() {
        Test.startTest();

        RestRequest request = new RestRequest();

        request.requestURI = '/assetEndpointAPI/';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNewNoInstaller());

        RestContext.request = request;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        List<Case> caseListTest = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case' AND Subject != 'No Service Partner'];

        System.assertEquals(3, caseListTest.size());
        System.assertEquals('Check Technician Certification', caseTest.Subject);
    }

    @IsTest
    static void testCascadingSystemNew() {
        Test.startTest();

        RestRequest request = new RestRequest();

        request.requestURI = '/assetEndpointAPI/';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONCascadingNew());

        RestContext.request = request;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id compEURecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();
        Id currentUserId = UserInfo.getUserId();

        Account aPersonTest = [SELECT Id FROM Account WHERE FirstName = 'Max' AND LastName = 'Power'];
        Account aInstallerTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Partner'];
        Account aDistributorTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPartnerRecordTypeId AND Name = 'Test Distributor'];
        Contact conInstallerTest = [SELECT Id FROM Contact WHERE RecordTypeId =: conInstallerRecordTypeId];
        List<StockItem__c> stockItemTestList = [SELECT Id, Account__c, Asset__c, Component__c, Product2__c, RecordTypeId, SerialNumber__c FROM StockItem__c WHERE SerialNumber__c != '12345' ORDER BY CreatedDate ASC];
        List<Asset> assetTestList = [SELECT Id, Product2Id, SerialNumber, InstallingCompany__c, Installer__c, DistributorSBC__c FROM Asset];
        List<Component__c> componentTestList = [SELECT Id, Current__c, SerialNumber__c, Hierarchy__c FROM Component__c WHERE RecordTypeId =: compEURecordTypeId ORDER BY CreatedDate ASC];
        List<ComponentJunction__c> compJunctionTestList = [SELECT Id, MasterComponent__c, SlaveComponent__c FROM ComponentJunction__c ORDER BY CreatedDate ASC];
        List<Case> caseListTest = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case'];
        Case caseLinkTest = [SELECT Id, AssetId FROM Case WHERE Subject = 'New Case'];
        Attachment attTest = [SELECT Id, ParentId FROM Attachment];
        Id cVDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test File'].ContentDocumentId;
        ContentDocumentLink cDL = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId =: cVDocId AND LinkedEntityId !=: stockItemTestList[0].Id AND LinkedEntityId !=: currentUserId];

        System.assertEquals(3, stockItemTestList.size());
        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[1].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[2].Account__c);
        System.assertEquals(stockItemConvertedId, stockItemTestList[0].RecordTypeId);
        System.assertEquals(stockItemConvertedId, stockItemTestList[1].RecordTypeId);
        System.assertEquals(stockItemConvertedId, stockItemTestList[2].RecordTypeId);
        System.assertEquals(1, assetTestList.size());
        System.assertEquals(assetTestList[0].Id, stockItemTestList[0].Asset__c);
        System.assertEquals(assetTestList[0].Id, stockItemTestList[1].Asset__c);
        System.assertEquals(assetTestList[0].Id, stockItemTestList[2].Asset__c);
        System.assertEquals(aInstallerTest.Id, assetTestList[0].InstallingCompany__c);
        System.assertEquals(aDistributorTest.Id, assetTestList[0].DistributorSBC__c);
        System.assertEquals(conInstallerTest.Id, assetTestList[0].Installer__c);
        System.assertEquals(componentTestList[0].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertEquals(3, componentTestList.size());
        System.assertEquals(stockItemTestList[0].SerialNumber__c, componentTestList[0].SerialNumber__c);
        System.assertEquals(stockItemTestList[1].SerialNumber__c, componentTestList[1].SerialNumber__c);
        System.assertEquals(stockItemTestList[2].SerialNumber__c, componentTestList[2].SerialNumber__c);
        System.assertEquals(componentTestList[0].Id, stockItemTestList[0].Component__c);
        System.assertEquals(componentTestList[1].Id, stockItemTestList[1].Component__c);
        System.assertEquals(componentTestList[2].Id, stockItemTestList[2].Component__c);
        System.assertEquals(true, componentTestList[0].Current__c);
        System.assertEquals(true, componentTestList[1].Current__c);
        System.assertEquals(true, componentTestList[2].Current__c);
        System.assertEquals('Master', componentTestList[0].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[1].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[2].Hierarchy__c);
        System.assertEquals(2, compJunctionTestList.size());
        System.assertEquals(componentTestList[0].Id, compJunctionTestList[0].MasterComponent__c);
        System.assertEquals(componentTestList[0].Id, compJunctionTestList[1].MasterComponent__c);
        System.assertEquals(componentTestList[1].Id, compJunctionTestList[0].SlaveComponent__c);
        System.assertEquals(componentTestList[2].Id, compJunctionTestList[1].SlaveComponent__c);
        System.assertEquals(2, caseListTest.size());
        System.assertEquals('No Service Partner', caseTest.Subject);
        System.assertEquals(assetTestList[0].Id, caseLinkTest.AssetId);
        System.assertEquals(assetTestList[0].Id, attTest.ParentId);
        System.assertEquals(assetTestList[0].Id, cDL.LinkedEntityId);
    }

    @IsTest
    static void testCascadingSystemMasterChange() {
        Test.startTest();

        RestRequest requestNew = new RestRequest();

        requestNew.requestURI = '/assetEndpointAPI/';
        requestNew.httpMethod = 'POST';
        requestNew.requestBody = Blob.valueOf(getJSONCascadingNew());

        RestContext.request = requestNew;

        AssetEndpointV3.handlePost();

        RestRequest requestChange = new RestRequest();

        requestChange.requestURI = '/assetEndpointAPI/';
        requestChange.httpMethod = 'POST';
        requestChange.requestBody = Blob.valueOf(getJSONCascadingMasterChange());

        RestContext.request = requestChange;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id compEURecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE FirstName = 'Max' AND LastName = 'Power'];
        List<StockItem__c> stockItemTestList = [SELECT Id, Account__c, Asset__c, Component__c, Product2__c, RecordTypeId, SerialNumber__c FROM StockItem__c WHERE RecordTypeId =: stockItemConvertedId ORDER BY CreatedDate ASC];
        List<Asset> assetTestList = [SELECT Id, Product2Id, SerialNumber, InstallingCompany__c, Installer__c, DistributorSBC__c FROM Asset];
        List<Component__c> componentTestList = [SELECT Id, Current__c, SerialNumber__c, Hierarchy__c, NewComponent__c, OldComponent__c FROM Component__c WHERE RecordTypeId =: compEURecordTypeId ORDER BY CreatedDate ASC];
        List<ComponentJunction__c> compJunctionTestList = [SELECT Id, MasterComponent__c, SlaveComponent__c FROM ComponentJunction__c ORDER BY CreatedDate ASC];
        List<Case> caseTestList = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case'];

        System.assertEquals(4, stockItemTestList.size());
        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[1].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[2].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[3].Account__c);
        System.assertEquals(1, assetTestList.size());
        System.assertEquals(componentTestList[3].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertNotEquals(componentTestList[0].SerialNumber__c, assetTestList[0].SerialNumber);
        // Component with the Serial 56163 is changed, should be on position 1 in the list
        System.assertEquals(false, componentTestList[0].Current__c);
        System.assertEquals(true, componentTestList[1].Current__c);
        System.assertEquals(true, componentTestList[2].Current__c);
        System.assertEquals(true, componentTestList[3].Current__c);
        System.assertEquals('Master', componentTestList[0].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[1].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[2].Hierarchy__c);
        System.assertEquals('Master', componentTestList[3].Hierarchy__c);
        System.assertEquals(componentTestList[3].Id, componentTestList[0].NewComponent__c);
        System.assertEquals(componentTestList[0].Id, componentTestList[3].OldComponent__c);
        System.assertEquals(2, compJunctionTestList.size());
        System.assertNotEquals(componentTestList[0].Id, compJunctionTestList[0].MasterComponent__c);
        System.assertNotEquals(componentTestList[0].Id, compJunctionTestList[1].MasterComponent__c);
        System.assertEquals(componentTestList[3].Id, compJunctionTestList[0].MasterComponent__c);
        System.assertEquals(componentTestList[3].Id, compJunctionTestList[1].MasterComponent__c);
        System.assertEquals(componentTestList[1].Id, compJunctionTestList[0].SlaveComponent__c);
        System.assertEquals(componentTestList[2].Id, compJunctionTestList[1].SlaveComponent__c);
        System.assertEquals(2, caseTestList.size());
        System.assertEquals('No Service Partner', caseTest.Subject);
    }

    @IsTest
    static void testCascadingSystemSlaveChange() {
        Test.startTest();

        RestRequest requestNew = new RestRequest();

        requestNew.requestURI = '/assetEndpointAPI/';
        requestNew.httpMethod = 'POST';
        requestNew.requestBody = Blob.valueOf(getJSONCascadingNew());

        RestContext.request = requestNew;

        AssetEndpointV3.handlePost();

        RestRequest requestChange = new RestRequest();

        requestChange.requestURI = '/assetEndpointAPI/';
        requestChange.httpMethod = 'POST';
        requestChange.requestBody = Blob.valueOf(getJSONCascadingSlaveChange());

        RestContext.request = requestChange;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id compEURecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE FirstName = 'Max' AND LastName = 'Power'];
        List<StockItem__c> stockItemTestList = [SELECT Id, Account__c, Asset__c, Component__c, Product2__c, RecordTypeId, SerialNumber__c FROM StockItem__c WHERE RecordTypeId =: stockItemConvertedId ORDER BY CreatedDate ASC];
        List<Asset> assetTestList = [SELECT Id, Product2Id, SerialNumber, InstallingCompany__c, Installer__c, DistributorSBC__c FROM Asset];
        List<Component__c> componentTestList = [SELECT Id, Current__c, SerialNumber__c, Hierarchy__c, NewComponent__c, OldComponent__c FROM Component__c WHERE RecordTypeId =: compEURecordTypeId ORDER BY CreatedDate ASC];
        List<ComponentJunction__c> compJunctionTestList = [SELECT Id, MasterComponent__c, SlaveComponent__c FROM ComponentJunction__c ORDER BY CreatedDate ASC];
        List<Case> caseTestList = [SELECT Id FROM Case];
        Case caseTest = [SELECT Id, Subject FROM Case WHERE Subject != 'New Case'];

        System.assertEquals(4, stockItemTestList.size());
        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[1].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[2].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[3].Account__c);
        System.assertEquals(1, assetTestList.size());
        System.assertEquals(componentTestList[0].SerialNumber__c, assetTestList[0].SerialNumber);
        System.assertEquals(true, componentTestList[0].Current__c);
        // Component with Serial 99997 is changed, should be on position 2 in the list
        System.assertEquals(false, componentTestList[1].Current__c);
        System.assertEquals(true, componentTestList[2].Current__c);
        System.assertEquals(true, componentTestList[3].Current__c);
        System.assertEquals('Master', componentTestList[0].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[1].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[2].Hierarchy__c);
        System.assertEquals('Slave', componentTestList[3].Hierarchy__c);
        System.assertEquals(componentTestList[3].Id, componentTestList[1].NewComponent__c);
        System.assertEquals(componentTestList[1].Id, componentTestList[3].OldComponent__c);
        System.assertEquals(2, compJunctionTestList.size());
        System.assertEquals(componentTestList[0].Id, compJunctionTestList[0].MasterComponent__c);
        System.assertEquals(componentTestList[0].Id, compJunctionTestList[1].MasterComponent__c);
        System.assertNotEquals(componentTestList[1].Id, compJunctionTestList[0].SlaveComponent__c);
        System.assertEquals(componentTestList[2].Id, compJunctionTestList[0].SlaveComponent__c);
        System.assertEquals(componentTestList[3].Id, compJunctionTestList[1].SlaveComponent__c);
        System.assertEquals(2, caseTestList.size());
        System.assertEquals('No Service Partner', caseTest.Subject);
    }

    @IsTest
    static void testJSONWithoutStockItem() {
        Test.startTest();

        RestRequest requestNew = new RestRequest();

        requestNew.requestURI = '/assetEndpointAPI/';
        requestNew.httpMethod = 'POST';
        requestNew.requestBody = Blob.valueOf(getJSONNewNoStockItem());

        RestContext.request = requestNew;

        AssetEndpointV3.handlePost();

        Test.stopTest();

        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        List<Asset> assetTestList = [SELECT Id, SerialNumber FROM Asset];
        List<StockItem__c> stockItemList = [SELECT Id, SerialNumber__c FROM StockItem__c WHERE RecordTypeId =: stockItemConvertedId];

        System.assertEquals(1, assetTestList.size());
        System.assertEquals(1, stockItemList.size());
    }
}