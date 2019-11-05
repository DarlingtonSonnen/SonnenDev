/**
 * Created by m.muchow on 23.07.2018.
 */

@IsTest
private class productSearchTest {
    @TestSetup
    static void testSetup() {
        Product2 testProduct1 = new Product2(Name = 'Test Product 1', Type__c = 'Battery', IsActive = true);
        insert testProduct1;
        Product2 testProduct2 = new Product2(Name = 'Test Product 2');
        insert testProduct2;
        ProductCertification__c testProductCertification = new ProductCertification__c(Product__c = testProduct2.Id);
        insert testProductCertification;
        Certification__c testCertification = new Certification__c(Name = 'Test Certification');
        insert testCertification;
    }

    @IsTest
    static void productSearchTest() {
        String type = 'battery';
        String isActive = 'true';
        Id recordId = [SELECT Id FROM Certification__c].Id;
        Id productId1 = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1'].Id;

        Test.startTest();
        List<String> typeList = productSearch.getTypeList();
        List<Product2> productList = productSearch.getProductList(type, isActive, recordId);
        productSearch.createJunction(recordId, productId1);
        Test.stopTest();

        List<ProdCertJunction__c> PCJ = [SELECT Id FROM ProdCertJunction__c];
        List<ProductCertification__c> PC = [SELECT Id FROM ProductCertification__c];

        System.assertEquals(true, PCJ.size() > 0);
        System.assertEquals(true, PC.size() > 0);
        System.assertEquals(true, typeList.size() > 0);
        System.assertEquals(true, productList.size() > 0);
    }

    @IsTest
    static void productSearchTest2() {
        Id recordId = [SELECT Id FROM Certification__c].Id;
        Id productId2 = [SELECT Id FROM Product2 WHERE Name = 'Test Product 2'].Id;

        Test.startTest();
        productSearch.createJunction(recordId, productId2);
        Test.stopTest();

        List<ProdCertJunction__c> PCJ = [SELECT Id FROM ProdCertJunction__c];
        List<ProductCertification__c> PC = [SELECT Id FROM ProductCertification__c];

        System.assertEquals(true, PCJ.size() > 0);
        System.assertEquals(false, PC.size() > 1);
    }

    @IsTest
    static void productSearchTest3() {
        Id recordId = [SELECT Id FROM Certification__c].Id;
        Id productId2 = [SELECT Id FROM Product2 WHERE Name = 'Test Product 2'].Id;
        List<Product2> productList = [SELECT Id FROM Product2];
        String productListString = JSON.serialize(productList);

        Test.startTest();
        productSearch.createJunction(recordId, productId2);
        List<Product2> updatedList = productSearch.getUpdatedProductList(recordId, productListString);
        Test.stopTest();

        System.assertNotEquals(productList.size(), updatedList.size());
    }
}