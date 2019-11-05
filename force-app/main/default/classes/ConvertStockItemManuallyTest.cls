/**
 * Created by m.muchow on 17.06.2019.
 */

@IsTest
private class ConvertStockItemManuallyTest {

    @TestSetup
    static void testSetup() {
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id stockItemConvertedRecordTypeId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        List<Account> insertAccounts = new List<Account>();
        List<StockItem__c> insertStockItems = new List<StockItem__c>();

        Account aDistributor = new Account(Name = 'Test Distributor', RecordTypeId = aPartnerRecordTypeId);
        insertAccounts.add(aDistributor);

        Account aPerson = new Account(FirstName = 'TestFirstName', LastName = 'TestLastName');
        insertAccounts.add(aPerson);

        insert insertAccounts;

        Asset asset = new Asset(Name = '78945', SerialNumber = '78945', AccountId = aPerson.Id, ContactId = aPerson.PersonContactId);
        insert asset;

        Component__c component = new Component__c(SerialNumber__c = '78945', Asset__c = asset.Id, Current__c = true);
        insert component;

        Product2 product = new Product2(Name = 'sb 10');
        insert product;

        StockItem__c stockItemConverted = new StockItem__c(SerialNumber__c = '78945', Type__c = 'Battery', Product2__c = product.Id,
                ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10,
                ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id, RecordTypeId = stockItemConvertedRecordTypeId,
                Asset__c = asset.Id, Component__c = component.Id, Account__c = aPerson.Id);
        insertStockItems.add(stockItemConverted);

        StockItem__c stockItem = new StockItem__c(SerialNumber__c = '56163', Type__c = 'Battery', Product2__c = product.Id,
                ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10,
                ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItem);

        StockItem__c stockItemChange = new StockItem__c(SerialNumber__c = '12345', Type__c = 'Battery', Product2__c = product.Id,
                ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-4,
                ShippingDate__c = System.today(), DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemChange);

        StockItem__c stockItemCascading1 = new StockItem__c(SerialNumber__c = '98760', Type__c = 'Battery', Product2__c = product.Id,
                ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10,
                ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemCascading1);

        StockItem__c stockItemCascading2 = new StockItem__c(SerialNumber__c = '98761', Type__c = 'Battery', Product2__c = product.Id,
                ManufacturingPlant__c = '2200', RevisionLevel__c = '1', FinalInspectionDate__c = System.today()-10,
                ShippingDate__c = System.today()-5, DistributorSBC__c = aDistributor.Id);
        insertStockItems.add(stockItemCascading2);

        insert insertStockItems;
    }

    static testMethod String getJSONNew() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "56163","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "false","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-03-13 09:17:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "false","IN_riverbox_old_serial": "12345","IN_riverbox_serial_imported": "false"}]';
        return bodyJSON;
    }

    static testMethod String getJSONChangeManually() {
        String bodyJSON = '[{"IN_Gender": "Mr.","IN_FirstName": "Max","IN_LastName": "Power","IN_Phone": "0800 9293340","IN_Email": "test@spam.asd","IN_EmailConfirm": "test@spam.asd","IN_Address1": "Am Riedbach ","IN_City": "Wildpoldsried","IN_Password": null,"IN_ZipCode": "87499","IN_State": "Bayern","IN_Country": "DE","IN_Date": "12/03/2019","IN_ContractId": null,"IN_CustomerNumber": null,"DE_Ticket_Number": "12345","DE_Software": "1.0.7.220343","IN_BACKUP_BOX_SERIAL": null,"IN_FEATURE_CHP": "0","IN_FEATURE_MICROGRID": "0","IN_FEATURE_PROTECT": "0","IN_FEATURE_SCR": "0","IN_FEATURE_TOU": "1","IN_FLAT": "0","IN_FLAT_CONCEPT": "2","IN_FLAT_CONCEPT_DESCRIPTION": null,"IN_FLAT_CONTRACT": null,"IN_FLAT_OFFICIAL": "1","IN_FLAT_PRODUCTION_METER": "1","IN_FLAT_STORAGEPASSNR": null,"IN_IN_Certificate": "123456","IN_IN_Company": "Test Partner","IN_IN_Email": "test@spam.asd","IN_IN_FirstName": "Test","IN_IN_Gender": "Mr.","IN_IN_LastName": "Installer","IN_IN_SoldBy": "Mehr Ampere","IN_IN_SoldbyInstaller": "true","IN_IN_LegalConfirmation": "Yes","IN_Inverter_Country_Code": null,"IN_PROTECT_ACTIVE": "0","IN_PROTECT_CODE": null,"IN_PROTECT_SERIAL": "","IN_SystemInstalled": "1","IN_TZUTCOffset": "1","IN_Time": "16:11","IN_TimeZone": "Europe/Berlin","IN_UTC": "2019-06-24 12:20:46","IN_InstallerNotification": "disabled","IN_OwnerNotification": "disabled","pro_cascade": null,"IN_riverbox_changed": "true","IN_riverbox_old_serial": "56163","IN_riverbox_serial_imported": "false"}]';
        return bodyJSON;
    }

    @IsTest
    static void testNewSingle() {
        Test.startTest();

        StockItem__c stockItem = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = '56163' LIMIT 1];

        stockItem.INClientSalutation__c = 'Mr.';
        stockItem.FirstName__c = 'Max';
        stockItem.LastName__c = 'Power';
        stockItem.ClientEmail__c = 'test@testmail.test';
        stockItem.ClientPhoneNumber__c = '123456';
        stockItem.ClientStreet__c = 'Zossener Str. 56';
        stockItem.ClientZIPCode__c = '10625';
        stockItem.ClientCity__c = 'Berlin';
        stockItem.Country__c = 'DE';

        update stockItem;

        ConvertStockItemManually.handleStockItemManually(stockItem.Id, true, null, '');

        Test.stopTest();

        Id aPersonAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPersonAccountRecordTypeId AND LastName != 'TestLastName' LIMIT 1];
        Asset assetTest = [SELECT Id, SerialNumber, INClientSalutation__c, INClientFirstName__c, INClientLastName__c,
                INClientEmail__c, INClientPhoneNumber__c, INClientStreet__c, INClientZIPCode__c, INClientCity__c,
                INClientCountry__c FROM Asset WHERE SerialNumber != '78945' LIMIT 1];
        Component__c componentTest = [SELECT Id, Asset__c, Current__c, SerialNumber__c FROM Component__c WHERE SerialNumber__c != '78945'];
        StockItem__c stockItemTest = [SELECT Id, ConvertedByCA__c, ConvertedManually__c, UpdatedByCA__c, UpdatedManually__c,
                CreatedOrChangedJSON__c, Asset__c, Account__c, Component__c, INClientSalutation__c, FirstName__c, LastName__c,
                ClientEmail__c, ClientPhoneNumber__c, ClientStreet__c, ClientZIPCode__c, ClientCity__c, Country__c,
                SerialNumber__c FROM StockItem__c WHERE SerialNumber__c != '78945' AND RecordTypeId =: stockItemConvertedId];

        System.assertEquals(false, stockItemTest.ConvertedByCA__c);
        System.assertEquals(true, stockItemTest.ConvertedManually__c);
        System.assertEquals(false, stockItemTest.UpdatedByCA__c);
        System.assertEquals(true, stockItemTest.UpdatedManually__c);
        System.assertNotEquals(null, stockItemTest.CreatedOrChangedJSON__c);
        System.assertEquals(assetTest.Id, stockItemTest.Asset__c);
        System.assertEquals(aPersonTest.Id, stockItemTest.Account__c);
        System.assertEquals(componentTest.Id, stockItemTest.Component__c);
        System.assertEquals(stockItemTest.SerialNumber__c, assetTest.SerialNumber);
        System.assertEquals(stockItemTest.INClientSalutation__c, assetTest.INClientSalutation__c);
        System.assertEquals(stockItemTest.FirstName__c, assetTest.INClientFirstName__c);
        System.assertEquals(stockItemTest.LastName__c, assetTest.INClientLastName__c);
        System.assertEquals(stockItemTest.ClientEmail__c, assetTest.INClientEmail__c);
        System.assertEquals(stockItemTest.ClientPhoneNumber__c, assetTest.INClientPhoneNumber__c);
        System.assertEquals(stockItemTest.ClientStreet__c, assetTest.INClientStreet__c);
        System.assertEquals(stockItemTest.ClientZIPCode__c, assetTest.INClientZIPCode__c);
        System.assertEquals(stockItemTest.ClientCity__c, assetTest.INClientCity__c);
        System.assertEquals(stockItemTest.Country__c, assetTest.INClientCountry__c);
    }

    @IsTest
    static void testNewCascading() {
        Test.startTest();

        StockItem__c stockItem = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = '56163' LIMIT 1];

        stockItem.INClientSalutation__c = 'Mr.';
        stockItem.FirstName__c = 'Max';
        stockItem.LastName__c = 'Power';
        stockItem.ClientEmail__c = 'test@testmail.test';
        stockItem.ClientPhoneNumber__c = '123456';
        stockItem.ClientStreet__c = 'Zossener Str. 56';
        stockItem.ClientZIPCode__c = '10625';
        stockItem.ClientCity__c = 'Berlin';
        stockItem.Country__c = 'DE';

        update stockItem;

        // create Slave Map, should be {nodes={{role=slave, serial=98760}, {role=slave, serial=98761}}}
        Map<String, Object>slaveMap = new Map<String, Object>();
        List<Map<String, String>>slaveMapHelperSet = new List<Map<String, String>>();
        for (Integer x = 0; x <= 1; x++) {
            Map<String, String>slaveMapHelper = new Map<String, String>();
            slaveMapHelper.put('role', 'slave');
            slaveMapHelper.put('serial', '9876'+x);
            slaveMapHelperSet.add(slaveMapHelper);
        }
        slaveMap.put('nodes', slaveMapHelperSet);

        ConvertStockItemManually.handleStockItemManually(stockItem.Id, false, slaveMap, '');

        Test.stopTest();

        Id aPersonAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPersonAccountRecordTypeId AND LastName != 'TestLastName' LIMIT 1];
        Asset assetTest = [SELECT Id, SerialNumber, INClientSalutation__c, INClientFirstName__c, INClientLastName__c,
                INClientEmail__c, INClientPhoneNumber__c, INClientStreet__c, INClientZIPCode__c, INClientCity__c,
                INClientCountry__c FROM Asset WHERE SerialNumber != '78945' LIMIT 1];
        List<Component__c> componentTestList = [SELECT Id, Asset__c, Current__c, SerialNumber__c FROM Component__c WHERE SerialNumber__c != '78945' ORDER BY CreatedDate ASC];
        List<StockItem__c> stockItemTestList = [SELECT Id, ConvertedByCA__c, ConvertedManually__c, UpdatedByCA__c, UpdatedManually__c,
                CreatedOrChangedJSON__c, Asset__c, Account__c, Component__c, INClientSalutation__c, FirstName__c, LastName__c,
                ClientEmail__c, ClientPhoneNumber__c, ClientStreet__c, ClientZIPCode__c, ClientCity__c, Country__c,
                SerialNumber__c FROM StockItem__c WHERE SerialNumber__c != '78945' AND RecordTypeId =: stockItemConvertedId ORDER BY CreatedDate ASC];

        System.assertEquals(3, stockItemTestList.size());
        System.assertEquals(false, stockItemTestList[0].ConvertedByCA__c);
        System.assertEquals(false, stockItemTestList[1].ConvertedByCA__c);
        System.assertEquals(false, stockItemTestList[2].ConvertedByCA__c);
        System.assertEquals(true, stockItemTestList[0].ConvertedManually__c);
        System.assertEquals(true, stockItemTestList[1].ConvertedManually__c);
        System.assertEquals(true, stockItemTestList[2].ConvertedManually__c);
        System.assertEquals(false, stockItemTestList[0].UpdatedByCA__c);
        System.assertEquals(false, stockItemTestList[1].UpdatedByCA__c);
        System.assertEquals(false, stockItemTestList[2].UpdatedByCA__c);
        System.assertEquals(true, stockItemTestList[0].UpdatedManually__c);
        System.assertEquals(true, stockItemTestList[1].UpdatedManually__c);
        System.assertEquals(true, stockItemTestList[2].UpdatedManually__c);
        System.assertNotEquals(null, stockItemTestList[0].CreatedOrChangedJSON__c);
        System.assertNotEquals(null, stockItemTestList[1].CreatedOrChangedJSON__c);
        System.assertNotEquals(null, stockItemTestList[2].CreatedOrChangedJSON__c);
        System.assertEquals(assetTest.Id, stockItemTestList[0].Asset__c);
        System.assertEquals(assetTest.Id, stockItemTestList[1].Asset__c);
        System.assertEquals(assetTest.Id, stockItemTestList[2].Asset__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[1].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[2].Account__c);
        System.assertEquals(componentTestList[0].Id, stockItemTestList[0].Component__c);
        System.assertEquals(componentTestList[1].Id, stockItemTestList[1].Component__c);
        System.assertEquals(componentTestList[2].Id, stockItemTestList[2].Component__c);
        System.assertEquals(stockItemTestList[0].SerialNumber__c, assetTest.SerialNumber);
        System.assertEquals(stockItemTestList[1].INClientSalutation__c, assetTest.INClientSalutation__c);
        System.assertEquals(stockItemTestList[2].FirstName__c, assetTest.INClientFirstName__c);
        System.assertEquals(stockItemTestList[0].LastName__c, assetTest.INClientLastName__c);
        System.assertEquals(stockItemTestList[1].ClientEmail__c, assetTest.INClientEmail__c);
        System.assertEquals(stockItemTestList[2].ClientPhoneNumber__c, assetTest.INClientPhoneNumber__c);
        System.assertEquals(stockItemTestList[0].ClientStreet__c, assetTest.INClientStreet__c);
        System.assertEquals(stockItemTestList[1].ClientZIPCode__c, assetTest.INClientZIPCode__c);
        System.assertEquals(stockItemTestList[2].ClientCity__c, assetTest.INClientCity__c);
        System.assertEquals(stockItemTestList[0].Country__c, assetTest.INClientCountry__c);
    }

    @IsTest
    static void testChangeSingle() {
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

        Id stockItemId = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = '12345'].Id;

        ConvertStockItemManually.handleStockItemManually(stockItemId, true, null, '');

        Test.stopTest();

        Id aPersonAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Id stockItemConvertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        Account aPersonTest = [SELECT Id FROM Account WHERE RecordTypeId =: aPersonAccountRecordTypeId AND LastName != 'TestLastName' LIMIT 1];
        Asset assetTest = [SELECT Id, SerialNumber FROM Asset WHERE SerialNumber != '78945' LIMIT 1];
        List<Component__c> componentTestList = [SELECT Id, Asset__c, Current__c, SerialNumber__c FROM Component__c WHERE SerialNumber__c != '78945' ORDER BY CreatedDate ASC];
        List<StockItem__c> stockItemTestList = [SELECT Id, ConvertedByCA__c, ConvertedManually__c, UpdatedByCA__c, UpdatedManually__c,
                CreatedOrChangedJSON__c, Asset__c, Account__c, Component__c, SerialNumber__c FROM StockItem__c
                WHERE RecordTypeId =: stockItemConvertedId AND SerialNumber__c != '78945' ORDER BY LastModifiedDate ASC];

        System.assertEquals(2, componentTestList.size());
        System.assertEquals(2, stockItemTestList.size());
        System.assertEquals(true, stockItemTestList[0].ConvertedByCA__c);
        System.assertEquals(false, stockItemTestList[1].ConvertedByCA__c);
        System.assertEquals(false, stockItemTestList[0].ConvertedManually__c);
        System.assertEquals(true, stockItemTestList[1].ConvertedManually__c);
        System.assertEquals(true, stockItemTestList[0].UpdatedByCA__c);
        System.assertEquals(true, stockItemTestList[1].UpdatedByCA__c);
        System.assertEquals(false, stockItemTestList[0].UpdatedManually__c);
        System.assertEquals(false, stockItemTestList[1].UpdatedManually__c);
        System.assertEquals(null, stockItemTestList[0].CreatedOrChangedJSON__c);
        System.assertEquals(null, stockItemTestList[1].CreatedOrChangedJSON__c);
        System.assertEquals(assetTest.Id, stockItemTestList[0].Asset__c);
        System.assertEquals(assetTest.Id, stockItemTestList[1].Asset__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[0].Account__c);
        System.assertEquals(aPersonTest.Id, stockItemTestList[1].Account__c);
        System.assertEquals(componentTestList[0].Id, stockItemTestList[0].Component__c);
        System.assertEquals(componentTestList[1].Id, stockItemTestList[1].Component__c);
        System.assertNotEquals(stockItemTestList[0].SerialNumber__c, assetTest.SerialNumber);
        System.assertEquals(stockItemTestList[1].SerialNumber__c, assetTest.SerialNumber);
    }

    @IsTest
    static void testChangeSerialChangeSingle() {
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

        Id stockItemId = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = '12345'].Id;

        ConvertStockItemManually.handleStockItemManually(stockItemId, true, null, '78945');

        Test.stopTest();

        Asset assetChangeTest = [SELECT Id, SerialNumber FROM Asset WHERE SerialNumber != '56163'];
        List<Component__c> componentTestList = [SELECT Id, Asset__c, Current__c, SerialNumber__c, NewComponent__c, OldComponent__c FROM Component__c WHERE SerialNumber__c != '78945' ORDER BY CreatedDate ASC];
        Component__c componentOldTest = [SELECT Id, Asset__c, Current__c, SerialNumber__c, NewComponent__c FROM Component__c WHERE SerialNumber__c = '78945'];

        System.assertEquals(null, componentTestList[0].NewComponent__c);
        System.assertEquals(componentTestList[1].Id, componentOldTest.NewComponent__c);
        System.assertEquals(componentOldTest.Id, componentTestList[1].OldComponent__c);
        System.assertEquals(componentTestList[1].Asset__c, assetChangeTest.Id);
    }

    @IsTest
    static void testCheckComponent() {

        Test.startTest();

        Boolean checkTrue = ConvertStockItemManually.checkForComponentSerial('78945');
        Boolean checkFalse = ConvertStockItemManually.checkForComponentSerial('98456');

        Test.stopTest();

        System.assertEquals(true, checkTrue);
        System.assertEquals(false, checkFalse);
    }
}