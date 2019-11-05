/**
 * Created by m.muchow on 13.05.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class AssetEndpointStockItemUpdate {

    public static Id updateStockItem(StockItem__c stockItem, Map<String, Object> requestMap, String sRequestJSON) {

        StaticResource countryLanguageISOResource = [SELECT Body FROM StaticResource WHERE Name = 'CountryLanguageISO' LIMIT 1];
        Map<String, Object> isoMap = (Map<String, Object>) JSON.deserializeUntyped(countryLanguageISOResource.Body.toString());

        system.debug('debug_done '+(String) requestMap.get('manually'));

        stockItem.FirstName__c = (String) requestMap.get('IN_FirstName');
        stockItem.LastName__c = (String) requestMap.get('IN_LastName');
        stockItem.INClientSalutation__c = (String) requestMap.get('IN_Gender');
        stockItem.ClientStreet__c = (String) requestMap.get('IN_Address1');
        stockItem.ClientCity__c = (String) requestMap.get('IN_City');
        stockItem.ClientZIPCode__c = (String) requestMap.get('IN_ZipCode');
        stockItem.ClientState__c = (String) requestMap.get('IN_State');
        stockItem.Country__c = (String) requestMap.get('IN_Country');
        stockItem.ClientCountry__c = (String) requestMap.get('IN_Country');
        stockItem.ClientEmail__c = (String) requestMap.get('IN_Email');
        stockItem.ClientPhoneNumber__c = (String) requestMap.get('IN_Phone');
        stockItem.INClientLanguage__c = (String)isoMap.get((String) requestMap.get('IN_Country'));
        if (String.isNotBlank((String) requestMap.get('manually')) && (String) requestMap.get('manually') == 'notFromCA') {
            stockItem.UpdatedManually__c = true;
            stockItem.CreatedOrChangedJSON__c = sRequestJSON;
        } else {
            stockItem.CommAssistPayLoad__c = sRequestJSON;
            stockItem.UpdatedByCA__c = true;
        }

        update stockItem;
        return stockItem.Id;
    }

    public static void updateStockItemCascading(List<StockItem__c> stockItemList, Map<String, Object> requestMap, Map<String, Object> cascadingMap, String sRequestJSON) {

        StaticResource countryLanguageISOResource = [SELECT Body FROM StaticResource WHERE Name = 'CountryLanguageISO' LIMIT 1];
        Map<String, Object> isoMap = (Map<String, Object>) JSON.deserializeUntyped(countryLanguageISOResource.Body.toString());

        List<StockItem__c> stockItemToUpdate = new List<StockItem__c>();

        for (StockItem__c stockItem : stockItemList) {
            stockItem.FirstName__c = (String) requestMap.get('IN_FirstName');
            stockItem.LastName__c = (String) requestMap.get('IN_LastName');
            stockItem.INClientSalutation__c = (String) requestMap.get('IN_Gender');
            stockItem.ClientStreet__c = (String) requestMap.get('IN_Address1');
            stockItem.ClientCity__c = (String) requestMap.get('IN_City');
            stockItem.ClientZIPCode__c = (String) requestMap.get('IN_ZipCode');
            stockItem.ClientState__c = (String) requestMap.get('IN_State');
            stockItem.Country__c = (String) requestMap.get('IN_Country');
            stockItem.ClientCountry__c = (String) requestMap.get('IN_Country');
            stockItem.ClientEmail__c = (String) requestMap.get('IN_Email');
            stockItem.ClientPhoneNumber__c = (String) requestMap.get('IN_Phone');
            stockItem.INClientLanguage__c = (String)isoMap.get((String) requestMap.get('IN_Country'));
            if (String.isNotBlank((String) requestMap.get('manually')) && (String) requestMap.get('manually') == 'notFromCA') {
                stockItem.UpdatedManually__c = true;
                stockItem.ConvertedManually__c = true;
                stockItem.CreatedOrChangedJSON__c = sRequestJSON;
            } else {
                stockItem.CommAssistPayLoad__c = sRequestJSON;
                stockItem.UpdatedByCA__c = true;
            }
            stockItem.Hierarchy__c = (String) cascadingMap.get(stockItem.SerialNumber__c);

            stockItemToUpdate.add(stockItem);
        }
        update stockItemToUpdate;
    }
}