/**
 * Created by m.muchow on 09.01.2019.
 * Extension class for MonitoringeServicesTriggerHandler to fill stockitem and to call ConvertStockItem_ApexController to covert stockitem to asset
 * MonitoringeServicesTriggerHandlerTest is Test Class
 * Update - 17.06.2019
 * - removed old Conversion Process ConvertStockItem_ApexController.createAsset(StockItemId);
 * - added new Conversion Process ConvertStockItemManually.handleStockItemManually(stockItemId, true, null, null);
 * - added line 17 to include Salutation
 */

public with sharing class MonitoringeServicesStockItemController {
    public static Id callConvertStockItem (Id contactId, Id contractId, Id stockItemId) {
        Contact contact = [SELECT FirstName, LastName, Salutation, Email, Phone FROM Contact WHERE Id =: contactId];
        Contract contract = [SELECT BillingStreet__c, BillingStreetNumber__c, BillingCity__c, BillingPostalCode__c, BillingCountry__c  FROM Contract WHERE Id =: contractId];
        StockItem__c stockItem = [SELECT Id FROM StockItem__c WHERE Id =: stockItemId];
        stockItem.INClientSalutation__c = contact.Salutation;
        stockItem.FirstName__c = contact.FirstName;
        stockItem.LastName__c = contact.LastName;
        stockItem.ClientEmail__c = contact.Email;
        stockItem.ClientPhoneNumber__c = contact.Phone;
        stockItem.ClientStreet__c = contract.BillingStreet__c+' '+contract.BillingStreetNumber__c;
        stockItem.ClientCity__c = contract.BillingCity__c;
        stockItem.ClientZIPCode__c = contract.BillingPostalCode__c;
        stockItem.ClientCountry__c = contract.BillingCountry__c;
        stockItem.Country__c = contract.BillingCountry__c;
        update stockItem;
        ConvertStockItemManually.handleStockItemManually(stockItemId, true, null, null);
        Id assetId = [SELECT Asset__c FROM StockItem__c WHERE Id =: stockItemId].Asset__c;
        return assetId;
    }
}