@isTest
public class ConvertStockItem_ApexController_test {
	
    @isTest
    public static void scenario1() {

        // create product to link it with the stock item
        Product2 p = new Product2();
        p.Name = 'sonnenBatterie eco 8.0 - 10 kWh LFP2';
        insert p;

        // create stock item with complete data;
        StockItem__c si = new StockItem__c();
        si.Account__c = null; 
        si.Asset__c = null;
        si.ClientCity__c = 'Berlin'; 
        si.Country__c = 'DE'; 
        si.ClientPhoneNumber__c = '2324324'; 
        si.ClientState__c = 'Berlin';
        si.ClientStreet__c = 'Zossener str. 56'; 
        si.ClientZIPCode__c = '10345';
        si.FirstName__c = 'Paul';
        si.LastName__c = 'Newman';
        si.SerialNumber__c = '12345';
        si.Type__c = 'Battery';
        si.ClientEmail__c = 'b.jarmolinski@sonnen.de';
        si.Product2__c = p.Id;
        insert si;
        
        // create case under SI - check if linked with asset after conversion
        Case c = new Case(Subject='New Case', Status='New',Type='Request', Impact__c = '2. High', StockItem__c=si.Id);
        c.RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'TechnicalSupportCase' LIMIT 1].Id;
        insert c;

        // create attachment under stock item and check if it is relinked to the asset
        Attachment att = new Attachment();
        att.Name = 'testFile';
        att.ParentId = si.Id;
        att.Body = EncodingUtil.base64Decode('attachment body');
        insert att;

        // create contentversion and content document link to check if additional content doc link is created
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode('test file');
        cv.Title = 'newFile';
        cv.PathOnClient = 'newFile';
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = si.Id;
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;
        cdl.ShareType = 'V';
        insert cdl;

        // call ConvertStockItem_ApexController.createAsset(Id stockItemId)
        Test.startTest();
        String s = ConvertStockItem_ApexController.createAsset(si.Id);
        Test.stopTest();

        Id assetId = [SELECT Asset__c FROM StockItem__c WHERE Id = :si.Id].Asset__c;
        //  assert that account and asset have been created
		System.assertEquals('Success: The asset has been successfully created and linked with the stock item.', s);
        System.assert([SELECT Asset__c FROM StockItem__c WHERE Id =:si.Id].Asset__c != null);
        System.assert([SELECT Account__c FROM StockItem__c WHERE Id =:si.Id].Account__c != null);
        System.assertEquals(1, [SELECT Id FROM Case WHERE StockItem__c =:si.Id].size());
        System.assertEquals(1, [SELECT Id FROM Case WHERE AssetId != null AND Id =:c.Id].size());
        System.assertEquals(1, [SELECT Id FROM Attachment WHERE ParentId =:assetId].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :assetId].size());
    }
    @isTest
    public static void scenario2() {
        // try to create stock item if asset already exists - should fail due to trigger and addError logic in StockItem trigger handler
        // create asset with serial number
        Account a = new Account(Name = 'newAccount');
        insert a;
        
        Asset ast = new Asset(Name = 'newAsset', SerialNumber = '23456', AccountId = a.Id);
        insert ast;
        
        // create stock item with the same number;
        StockItem__c si = new StockItem__c();
        si.SerialNumber__c = '23456';

        try {
            insert si;
        } catch (Exception e) {
            // assert that exception was thrown
            System.assert(e.getMessage().contains('Unable to save the stock item because assets with these serial numbers already exist'));            
        }


        // call ConvertStockItem_ApexController.createAsset(Id stockItemId)
        //Test.startTest();
        //String s = ConvertStockItem_ApexController.createAsset(si.Id);
        //Test.stopTest();
        
        // assert that stock item has been linked to the asset
        //System.assert([SELECT Asset__c FROM StockItem__c WHERE Id = :si.Id].Asset__c == ast.Id);
        //System.assertEquals(ast.Id, [SELECT Asset__c FROM StockItem__c WHERE Id = :si.Id].Asset__c);
        //System.assertEquals('Success: The asset already exists. The Stock Item has been linked to it.', s);
    }
    @isTest
    public static void scenario3() {
        // try to convert stock item without serial number
        // create stock item with the same number;
        
		StockItem__c si = new StockItem__c();
        si.Account__c = null; 
        si.Asset__c = null;
        si.ClientCity__c = 'Berlin'; 
        si.Country__c = 'DE'; 
        si.ClientPhoneNumber__c = '2324324'; 
        si.ClientState__c = 'Berlin';
        si.ClientStreet__c = 'Zossener str. 56'; 
        si.ClientZIPCode__c = '10345';
        si.FirstName__c = 'Paul';
        si.LastName__c = 'Newman';
        si.SerialNumber__c = null;
        si.Type__c = 'Battery';
        si.ClientEmail__c = 'b.jarmolinski@sonnen.de';
        insert si;
        
        // call ConvertStockItem_ApexController.createAsset(Id stockItemId)
        Test.startTest();
        String s = ConvertStockItem_ApexController.createAsset(si.Id);
        Test.stopTest();
        
        System.assertEquals('Error: Serial number is mandatory for conversion to asset.', s);
    }
    
    @isTest
    public static void scenario4() {
        // case when data is not complete and conversion should fail
        
		StockItem__c si = new StockItem__c();
        si.Account__c = null; 
        si.Asset__c = null;
        si.ClientCity__c = null; 
        si.Country__c = 'DE'; 
        si.ClientPhoneNumber__c = '2324324'; 
        si.ClientState__c = 'Berlin';
        si.ClientStreet__c = null; 
        si.ClientZIPCode__c = '10345';
        si.FirstName__c = 'Paul';
        si.LastName__c = 'Newman';
        si.SerialNumber__c = '12345';
        si.Type__c = 'Battery';
        si.ClientEmail__c = 'b.jarmolinski@sonnen.de';
        insert si;
        
        Test.startTest();
        String s = ConvertStockItem_ApexController.createAsset(si.Id);
        Test.stopTest();

        System.assertEquals('Error: The data on stock item is not complete', s);
    }

    @isTest
    public static void scenario5() {
        // check that creating stock item with the same serial number as another stock item fails

        // create stock item;
        StockItem__c si = new StockItem__c();
        si.SerialNumber__c = '23456';

        insert si;

        // create another stock item with the same number
        StockItem__c s2 = new StockItem__c();
        s2.SerialNumber__c = '23456';

        try {
            insert s2;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unable to save the stock item because other stock items with the same serial numbers already exist'));
        }
    }

    @isTest
    public static void scenario6() {

        // try to create stock item if asset already exists - should fail due to trigger and addError logic in StockItem trigger handler
        // create asset with serial number
        Account a = new Account(Name = 'newAccount');
        insert a;
        
        // create stock item with the same number;
        StockItem__c si = new StockItem__c();
        si.SerialNumber__c = '23456';
        si.Asset__c = null;
        insert si;

        Asset ast = new Asset(Name = 'newAsset', SerialNumber = '23456', AccountId = a.Id);
        insert ast;

        // call ConvertStockItem_ApexController.createAsset(Id stockItemId)
        Test.startTest();
        String s = ConvertStockItem_ApexController.createAsset(si.Id);
        Test.stopTest();
        
        // assert that stock item has been linked to the asset
        System.assert([SELECT Asset__c FROM StockItem__c WHERE Id = :si.Id].Asset__c == ast.Id);
        System.assertEquals(ast.Id, [SELECT Asset__c FROM StockItem__c WHERE Id = :si.Id].Asset__c);
        System.assertEquals('Success: The asset already exists. The Stock Item has been linked to it.', s);        
    }

    @isTest
    public static void scenario7() {
        // check that validation will not allow changing serial number to already existing one

        StockItem__c si = new StockItem__c();
        si.SerialNumber__c = '23456';
        si.Asset__c = null;
        insert si;

        // create stock item with different serial number
        StockItem__c s2 = new StockItem__c();
        s2.SerialNumber__c = '23000';
        s2.Asset__c = null;
        insert s2;

        // change serial number of s2 to the same as si - should fail
        s2.SerialNumber__c = '23456';

        try {
            update s2;  
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unable to save the stock item because other stock items with the same serial numbers already exist'));
        }
    }
}