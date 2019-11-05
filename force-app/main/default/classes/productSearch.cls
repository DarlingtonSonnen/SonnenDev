/**
 * Created by m.muchow on 19.07.2018.
 * Update by m.muchow on 30.07.2018.
 *      change in picklist valu for all products from ' ' to 'All Types'
 *      change in sQuery to filter all products when 'All Types' is selected
 */

global with sharing class productSearch {

    @AuraEnabled
    //create initial product list for lightning component
    public static List<Product2> getProductList(String type, String isActive, Id recordId) {
        String typeQuery = '';
        String isActiveQuery = '';
        String andQuery = '';
        String whereQuery = '';
        Set<Id> productQueryIds = new Set<Id>();
        Set<Id> prodCertIds = new Set<Id>();
        Set<Id> excludeProductIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        if (type != 'All Types') {
            whereQuery = ' WHERE';
            typeQuery = ' Type__c = \''+type+'\'';
        }
        if (String.isNotBlank(isActive)) {
            whereQuery = ' WHERE';
            isActiveQuery = ' IsActive = '+isActive;
        }
        if ((String.isNotBlank(type)) && (String.isNotBlank(isActive))) {
            whereQuery = ' WHERE';
            andQuery = 'AND';
        }
        //create string query for database query
        String sQuery = 'SELECT Name, Id FROM Product2'+whereQuery+typeQuery+andQuery+isActiveQuery;
        List<Product2> queryList = Database.query(sQuery);
        //create id set from initial database query
        for (Product2 p : queryList) {
            productQueryIds.add(p.Id);
        }
        //check for already attached product certifications and add to id set
        List<ProdCertJunction__c> certJunctions = [SELECT ProductCertification__c FROM ProdCertJunction__c WHERE Certification__c =: recordId];
        for (ProdCertJunction__c pCJ : certJunctions) {
            prodCertIds.add(pCJ.ProductCertification__c);
        }
        //search products from product certifications and add to is set
        List<ProductCertification__c> excludeProdCert = [SELECT Product__c FROM ProductCertification__c WHERE Id IN : prodCertIds];
        for (ProductCertification__c pC : excludeProdCert) {
            excludeProductIds.add(pC.Product__c);
        }
        //create id set for final product query
        for (Id thisId : productQueryIds) {
            if (!excludeProductIds.contains(thisId)) {
                productIds.add(thisId);
            }
        }
        //query final product list
        List<Product2> productList = [SELECT Id, Name FROM Product2 WHERE Id IN : productIds];
        return productList;
    }

    @AuraEnabled
    //create type list for lightning component
    public static List<String> getTypeList() {
        List<String> typeList = new List<String>();
        typeList.add('All Types');
        Schema.DescribeFieldResult fieldResult = Product2.Type__c.getDescribe();
        List<Schema.PickListEntry> typeListSchema = fieldResult.getPicklistValues();
        for(Schema.PickListEntry p: typeListSchema) {
            typeList.add(p.getLabel());
        }
        return typeList;
    }

    @AuraEnabled
    public static void createJunction(Id recordId, Id productId) {
        //get list of attached product certifications
        List<ProductCertification__c> prodCert = [SELECT Id FROM ProductCertification__c WHERE Product__c =: productId ORDER BY CreatedDate LIMIT 1];
        if (prodCert.size() > 0) {
          //create Junction Object if the product has a production certificate
          ProdCertJunction__c newCertJunction = new ProdCertJunction__c();
          newCertJunction.ProductCertification__c = prodCert[0].Id;
          newCertJunction.Certification__c = recordId;
          insert newCertJunction;
        } else {
          //create new Production Certificate
          ProductCertification__c newProdCert = new ProductCertification__c();
          newProdCert.Product__c = productId;
          insert newProdCert;
          //create Junction Object
          ProdCertJunction__c newCertJunction = new ProdCertJunction__c();
          newCertJunction.ProductCertification__c = newProdCert.Id;
          newCertJunction.Certification__c = recordId;
          insert newCertJunction;
        }
    }

    @AuraEnabled
    //update product list after product was attached
    public static List<Product2> getUpdatedProductList(Id recordId, String productListString) {
        Set<Id> prodCertIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> newProductIds = new Set<Id>();
        Set<Id> oldProductIds = new Set<Id>();
        //get list of current product list from lightning component and create id set of current products
        List<Product2> oldProducts = (List<Product2>)JSON.deserializeStrict(productListString,List<Product2>.class);
        for (Product2 p : oldProducts) {
            oldProductIds.add(p.Id);
        }
        //get list of attached product certifications through junction object and create id set of attached product certifications
        List<ProdCertJunction__c> certJunctions = [SELECT ProductCertification__c FROM ProdCertJunction__c WHERE Certification__c =: recordId];
        for (ProdCertJunction__c pCJ : certJunctions) {
            prodCertIds.add(pCJ.ProductCertification__c);
        }
        //get list of attached products and create id set of attached products
        List<ProductCertification__c> excludeProdCert = [SELECT Product__c FROM ProductCertification__c WHERE Id IN : prodCertIds];
        for (ProductCertification__c pC : excludeProdCert) {
            productIds.add(pC.Product__c);
        }
        //create id set for updated product query
        for (Id thisId : oldProductIds) {
            if (!productIds.contains(thisId)) {
                newProductIds.add(thisId);
            }
        }
        //query updated product list
        List<Product2> newProductList = [SELECT Id, Name FROM Product2 WHERE Id IN : newProductIds];
        return newProductList;
    }
}