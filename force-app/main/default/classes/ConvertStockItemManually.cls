/**
 * Created by m.muchow on 04.06.2019.
 */

public with sharing class ConvertStockItemManually {

    @AuraEnabled
    public static void handleStockItemManually(Id stockItemId, Boolean isSingle, Map<String, Object> slaveMap, String changedOldSerial) {
        String sRequestJSON = '';
        Map<String, Object> requestMap = new Map<String, Object>();

        // Query of Stock Item
        StockItem__c queriedStockItem = queryStockItem(stockItemId);

        // create request Map from JSON if found on Stock Item
        if (queriedStockItem.CommAssistPayLoad__c != null && queriedStockItem.CommAssistPayLoad__c != '') {
            requestMap = (Map<String, Object>) JSON.deserializeUntyped((queriedStockItem.CommAssistPayLoad__c));
            sRequestJSON = queriedStockItem.CommAssistPayLoad__c;
            if (changedOldSerial != '') {
                requestMap.put('IN_riverbox_old_serial', changedOldSerial);
            }
            requestMap.put('IN_riverbox_serial_imported', 'true');
            requestMap.put('manually', 'fromCA');
        }

        // Put additional Information in slaveMap
        if (!isSingle && slaveMap != null) {
            slaveMap.put('role', 'master');
        }

        // update Stock Item if it was not updated by CA
        if (!queriedStockItem.UpdatedByCA__c || changedOldSerial != '') {
            queriedStockItem.UpdatedManually__c = true;
        }

        // create request Map from Stock Item if no JSON from CA was present
        if (requestMap.isEmpty()) {
            requestMap.put('IN_Gender', queriedStockItem.INClientSalutation__c);
            requestMap.put('IN_FirstName', queriedStockItem.FirstName__c);
            requestMap.put('IN_LastName', queriedStockItem.LastName__c);
            requestMap.put('IN_Phone', queriedStockItem.ClientPhoneNumber__c);
            requestMap.put('IN_Email', queriedStockItem.ClientEmail__c);
            requestMap.put('IN_EmailConfirm', queriedStockItem.ClientEmail__c);
            requestMap.put('IN_Address1', queriedStockItem.ClientStreet__c);
            requestMap.put('IN_City', queriedStockItem.ClientCity__c);
            requestMap.put('IN_ZipCode', queriedStockItem.ClientZIPCode__c);
            requestMap.put('IN_State', queriedStockItem.ClientState__c);
            requestMap.put('IN_Country', queriedStockItem.Country__c);
            requestMap.put('DE_Ticket_Number', queriedStockItem.SerialNumber__c);
            // add cascading information depending if single or cascading system
            if (isSingle) {
                requestMap.put('pro_cascade', null);
            } else {
                requestMap.put('pro_cascade', slaveMap);
            }
            // add information for conversion process
            requestMap.put('IN_riverbox_changed', 'false');
            requestMap.put('IN_riverbox_old_serial', '');
            requestMap.put('IN_riverbox_serial_imported', 'false');
            requestMap.put('IN_UTC', '');
            requestMap.put('manually', 'notFromCA');
        }

        // fill request Json
        if (String.isBlank(sRequestJSON)) {
            sRequestJSON = JSON.serialize(requestMap);
        }

        // write created or changed JSON to Stock Item
        if (String.isNotBlank(changedOldSerial) || (String.isBlank(queriedStockItem.CommAssistPayLoad__c))) {
            queriedStockItem.CreatedOrChangedJSON__c = JSON.serialize(requestMap);
        }

        // set manually conversion Indicator
        queriedStockItem.ConvertedManually__c = true;

        update queriedStockItem;

        // call class to handle riverbox creation
        AssetEndpointRiverbox.createRiverbox(requestMap, sRequestJSON);
    }

    @AuraEnabled
    public static Boolean checkForComponentSerial(String oldSerial) {
        Boolean componentPresent;

        List<Component__c> componentCheckList = [SELECT Id FROM Component__c WHERE SerialNumber__c =: oldSerial AND Current__c = TRUE];

        if (componentCheckList.size() == 1) {
            componentPresent = true;
        } else {
            componentPresent = false;
        }
        return componentPresent;
    }

    private static StockItem__c queryStockItem(Id stockItemId) {
        //get map of stock item fields
        Map<String, Schema.SObjectField> mapStockItemFields = Schema.SObjectType.StockItem__c.fields.getMap();
        //initialize string for database query
        String sQuery = 'SELECT ';
        //check for found stock item fields and generate string
        for (Integer i=0; i < mapStockItemFields.values().size(); i++) {
            if (i != mapStockItemFields.values().size() - 1) {
                sQuery = sQuery + mapStockItemFields.values()[i].getDescribe().getName() + ', ';
            } else if (i == mapStockItemFields.values().size() - 1) {
                sQuery = sQuery + mapStockItemFields.values()[i].getDescribe().getName() + ' FROM StockItem__c WHERE Id =: stockItemId';
            }
        }
        //initialize database query with generated string
        StockItem__c stockItem = Database.query(sQuery);
        //return queried stock item list
        return stockItem;
    }
}