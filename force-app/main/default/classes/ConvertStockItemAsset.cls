/**
 * Created by m.muchow on 17.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class ConvertStockItemAsset {
    public static Asset createAssetFromStockItem(StockItem__c stockItem) {

        Id batteryRecordTypeId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();
        Asset convertedAsset;

        if (stockItem.Asset__c == null) {
            convertedAsset = new Asset();
        } else {
            convertedAsset = [SELECT Id, Name, RecordTypeId, INClientFirstName__c, INClientLastName__c, INClientSalutation__c,
                    INClientPhoneNumber__c, INClientEmail__c, InClientEmail2__c, INClientStreet__c, INClientCity__c, INClientZIPCode__c,
                    INClientState__c, INClientCountry__c, INClientLanguage__c, Country__c, Product2Id, AccountId, ContactId FROM Asset WHERE Id =: stockItem.Asset__c];
        }

        convertedAsset.Name = 'TBD';
        convertedAsset.RecordTypeId = batteryRecordTypeId;
        convertedAsset.INClientFirstName__c = stockItem.FirstName__c;
        convertedAsset.INClientLastName__c = stockItem.LastName__c;
        convertedAsset.INClientSalutation__c = (String)stockItem.INClientSalutation__c;
        convertedAsset.INClientPhoneNumber__c = stockItem.ClientPhoneNumber__c;
        convertedAsset.INClientEmail__c = stockItem.ClientEmail__c;
        convertedAsset.InClientEmail2__c = stockItem.ClientEmail__c;
        convertedAsset.INClientStreet__c = stockItem.ClientStreet__c;
        convertedAsset.INClientCity__c = stockItem.ClientCity__c;
        convertedAsset.INClientZIPCode__c = stockItem.ClientZIPCode__c;
        convertedAsset.INClientState__c = stockItem.ClientState__c;
        convertedAsset.INClientCountry__c = stockItem.Country__c;
        convertedAsset.Country__c = stockItem.Country__c;
        convertedAsset.Product2Id = stockItem.Product2__c;
        convertedAsset.INClientLanguage__c = stockItem.INClientLanguage__c;
        if (stockItem.Asset__c == null) {
            convertedAsset.AccountId = null;
            convertedAsset.ContactId = null;
        }

        return convertedAsset;
    }
}