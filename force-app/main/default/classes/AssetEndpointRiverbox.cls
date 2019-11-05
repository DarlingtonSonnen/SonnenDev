/**
 * Created by m.muchow on 11.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class AssetEndpointRiverbox {

    public static Id createRiverbox(Map<String, Object> requestMap, String sRequestJSON) {
        // get RecordTypeId for battery assets
        Id batteryRecordId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();
        // get list of assets (battery) with serialnumber given by request
        List<Asset> assetList = [SELECT Id FROM Asset WHERE SerialNumber =: (String) requestMap.get('DE_Ticket_Number') AND RecordTypeId =: batteryRecordId];
        // get list of assets (battery) with serialnumber of old Riverbox given by request
        List<Component__c> assetIdFromComponent = [SELECT Asset__c FROM Component__c WHERE SerialNumber__c =: (String) requestMap.get('IN_riverbox_old_serial')];
        // get list of stockitem (battery) with serialnumber given by request which was not converted by CA
        List<StockItem__c> stockItemList = [SELECT Id, UpdatedManually__c, CommAssistPayLoad__c FROM StockItem__c WHERE SerialNumber__c =: (String) requestMap.get('DE_Ticket_Number') AND Type__c = 'Battery' AND ConvertedByCA__c = FALSE];

        // initialize objects
        Id stockItemId;
        Id assetId;
        Boolean checkOldCA = false;
        StockItem__c stockItem;

        if (String.isBlank((String) requestMap.get('IN_riverbox_changed')) && String.isBlank((String) requestMap.get('IN_riverbox_old_serial')) && String.isBlank((String) requestMap.get('IN_riverbox_serial_imported'))) {
            checkOldCA = true;
        }

        if (!stockItemList.isEmpty() || assetList.isEmpty()) {
            // assign first found stock item to variable or create new Stock Item if no stock Item is present
            if (!stockItemList.isEmpty()) {
                stockItem = stockItemList[0];
            } else {
                stockItem = new StockItem__c(SerialNumber__c = (String) requestMap.get('DE_Ticket_Number'), CreatedByCA__c = true, Type__c = 'Battery');
                insert stockItem;
            }
            // call method to update given stock item with data from request
            if (stockItem.UpdatedManually__c == false || (stockItem.UpdatedManually__c == true && (String) requestMap.get('manually') == 'notFromCA') || checkOldCA == true) {
                stockItemId = AssetEndpointStockItemUpdate.updateStockItem(stockItem, requestMap, sRequestJSON);
            } else {
                stockItemId = stockItem.Id;
            }
            // call convert method
            Id convertedStockItemId = convertStockItemProcess(stockItemId, requestMap, sRequestJSON, checkOldCA);
            // update created or found asset with data from request
            if ((!stockItemList.isEmpty() || assetList.isEmpty()) && ((String) requestMap.get('IN_riverbox_changed') == 'false' || ((String) requestMap.get('IN_riverbox_changed') == 'true' && (String) requestMap.get('IN_riverbox_serial_imported') == 'true')  || checkOldCA == true)) {
                assetId = AssetEndpointAssetUpdate.updateAsset(convertedStockItemId, requestMap, checkOldCA);
            } else {
                assetId = assetIdFromComponent[0].Asset__c;
            }
        }
        return assetId;
    }

    // method to update stock item with data from request
    private static Id convertStockItemProcess(Id stockItemId, Map<String, Object> requestMap, String sRequestJSON, Boolean checkOldCA) {
        String cascadingRole;
        // create map if Cascading System
        Map<String, Object> cascadingMap = (Map<String, Object>) requestMap.get('pro_cascade');
        if (cascadingMap != null) {
            cascadingRole = (String) cascadingMap.get('role');
        }
        // check if cascading system
        if ((Map<String, Object>) requestMap.get('pro_cascade') == null || checkOldCA == true) {
            // if new Asset with Electric Unit, call class to convert stock item to asset
            if ((String) requestMap.get('IN_riverbox_changed') == 'false' || checkOldCA == true) {
                ConvertStockItem.convertToEUnitNew(stockItemId, requestMap, sRequestJSON);
            // if change of Electric Unit only, call class to convert stock item to component
            } else if ((String) requestMap.get('IN_riverbox_changed') == 'true' && (String) requestMap.get('IN_riverbox_serial_imported') == 'true') {
                ConvertStockItem.convertToEUnitChange(stockItemId, requestMap, sRequestJSON);
            }
        } else if ((Map<String, Object>) requestMap.get('pro_cascade') != null) {
            // create cascading system
            if ((String) requestMap.get('IN_riverbox_changed') == 'false' && cascadingRole == 'master') {
                ConvertStockItem.convertToCascadingNew(stockItemId, requestMap, sRequestJSON);
            // update cascading system
            } else if ((String) requestMap.get('IN_riverbox_changed') == 'true' && (String) requestMap.get('IN_riverbox_serial_imported') == 'true') {
                ConvertStockItem.convertToCascadingChange(stockItemId, requestMap, sRequestJSON);
            }
        }
        return stockItemId;
    }
}