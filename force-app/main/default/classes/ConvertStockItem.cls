/**
 * Created by m.muchow on 17.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class ConvertStockItem {
    public static void convertToEUnitNew(Id stockItemId, Map<String, Object> requestMap, String sRequestJSON) {
        //get RecordTypeId for converted StockItem
        Id convertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        //put Id of Stock Item into Set
        Set<Id> stockItemIdSet = new Set<Id>{stockItemId};

        //Query StockItem with dynamic query
        List<StockItem__c> stockItemList = queryStockItem(stockItemIdSet);

        //Call Convert StockItem to Asset
        Asset convertedAsset = ConvertStockItemAsset.createAssetFromStockItem(stockItemList[0]);

        if (convertedAsset.AccountId == null && convertedAsset.ContactId == null) {
            //Call Duplicate Check
            List<Asset> assetList = new List<Asset>{convertedAsset};
            DuplicateCheckHandlerv3 dCH = new DuplicateCheckHandlerv3(assetList);
            Map<Id, Map<String, Id>> idMap = dCH.handleObjectsv2();

            //link Asset to Account & Contact
            convertedAsset.AccountId = idMap.get(convertedAsset.Id).get('Account');
            convertedAsset.ContactId = idMap.get(convertedAsset.Id).get('Contact');
        }

        //upsert Asset
        upsert convertedAsset;

        //Call Convert StockItem to Electric Unit
        Component__c convertedComponent = ConvertStockItemEUnit.createEUnitFromStockItem(stockItemList[0], requestMap, convertedAsset, sRequestJSON);

        //link Stock Item and convert Stock Item
        stockItemList[0].Account__c = convertedAsset.AccountId;
        stockItemList[0].Asset__c = convertedAsset.Id;
        stockItemList[0].Component__c = convertedComponent.Id;
        stockItemList[0].RecordTypeId = convertedId;
        if (String.isBlank((String) requestMap.get('manually'))) {
            stockItemList[0].ConvertedByCA__c = true;
        }
        update stockItemList;

        //link the stock item cases, attachments and files with the asset
        ConvertStockItemLinkRelatedRecords.linkCases(stockItemList[0].Id, convertedAsset.Id);
        ConvertStockItemLinkRelatedRecords.linkAttachments(stockItemList[0].Id, convertedAsset.Id);
        ConvertStockItemLinkRelatedRecords.linkFiles(stockItemList[0].Id, convertedAsset.Id);
    }

    public static void convertToEUnitChange(Id stockItemId, Map<String, Object> requestMap, String sRequestJSON) {
        //get RecordTypeId for battery assets
        Id batteryRecordId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();

        //get RecordTypeId for converted StockItem
        Id convertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        //put Id of Stock Item into Set
        Set<Id> stockItemIdSet = new Set<Id>{stockItemId};

        //Query StockItem with dynamic query
        List<StockItem__c> stockItemList = queryStockItem(stockItemIdSet);

        //Query Asset
        List<Asset> assetList = [SELECT Id, AccountId FROM Asset WHERE SerialNumber =: (String) requestMap.get('IN_riverbox_old_serial') AND RecordTypeId =: batteryRecordId];

        //Query Electric Unit
        List<Component__c> componentList = [SELECT Id, Current__c, DeactivatedSince__c, NewComponent__c FROM Component__c WHERE SerialNumber__c =: (String) requestMap.get('IN_riverbox_old_serial')];

        if (!assetList.isEmpty() && !componentList.isEmpty()) {

            //Call Convert StockItem to E-Unit Class
            Component__c convertedComponent = ConvertStockItemEUnit.createEUnitFromStockItem(stockItemList[0], requestMap, assetList[0], sRequestJSON);

            //update New Electric Unit
            convertedComponent.OldComponent__c = componentList[0].Id;
            update convertedComponent;

            //link Stock Item and convert Stock Item
            stockItemList[0].Account__c = assetList[0].AccountId;
            stockItemList[0].Asset__c = assetList[0].Id;
            stockItemList[0].Component__c = convertedComponent.Id;
            stockItemList[0].RecordTypeId = convertedId;
            if (String.isBlank((String) requestMap.get('manually'))) {
                stockItemList[0].ConvertedByCA__c = true;
            }
            update stockItemList;

            //update Old Electric Unit
            componentList[0].Current__c = false;
            componentList[0].DeactivatedSince__c = System.now();
            componentList[0].NewComponent__c = convertedComponent.Id;
            update componentList[0];

            //link the stock item cases, attachments and files with the asset
            ConvertStockItemLinkRelatedRecords.linkCases(stockItemList[0].Id, assetList[0].Id);
            ConvertStockItemLinkRelatedRecords.linkAttachments(stockItemList[0].Id, assetList[0].Id);
            ConvertStockItemLinkRelatedRecords.linkFiles(stockItemList[0].Id, assetList[0].Id);
        }
    }

    public static void convertToCascadingNew(Id mainStockItemId, Map<String, Object> requestMap, String sRequestJSON) {
        //get RecordTypeId for converted StockItem
        Id convertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        //initialize maps
        Map<String, String> nodesMap = new Map<String, String>();
        Map<Id, String> masterMap = new Map<Id, String>();
        Map<Id, String> slaveMap = new Map<Id, String>();

        //initialize lists
        List<Object> data = new List<Object>();
        List<StockItem__c> stockItemList = new List<StockItem__c>();
        List<StockItem__c> stockItemUpdateList = new List<StockItem__c>();

        //initialize sets
        Set<Id> stockItemIdSet = new Set<Id>();
        Set<String> stockItemSerialNumberSet = new Set<String>();

        //initialize asset
        Asset convertedAsset = new Asset();

        //initialize map & string & fill with data
        Map<String, Object> mapCascading = (Map<String, Object>) requestMap.get('pro_cascade');
        String roleString = ((String)mapCascading.get('role')).capitalize();

        //pre fill map & set with data
        nodesMap.put((String) requestMap.get('DE_Ticket_Number'), roleString);
        stockItemIdSet.add(mainStockItemId);

        //loop trough JSON request and populate list with data
        for (Object instance : (List<Object>)mapCascading.get('nodes')) {
            data.add(instance);
        }

        //loop trough list and populate map and list with data
        for (Object da : data) {
            String subStringRole = String.valueOf(da).substringBefore(',');
            String subStringSerial = String.valueOf(da).substringAfter(',');
            subStringRole = subStringRole.substringAfter('=');
            subStringSerial = subStringSerial.substringBetween('=', '}');
            nodesMap.put(subStringSerial, subStringRole.capitalize());
            stockItemSerialNumberSet.add(subStringSerial);
        }

        // loop trough list, populate set with stock item ids and create new Stock Items if necessary
        Set<String> serialSet = new Set<String>();
        List<StockItem__c> createStockItemList = new List<StockItem__c>();
        List<StockItem__c> stockItemIdList = [SELECT Id, SerialNumber__c FROM StockItem__c WHERE SerialNumber__c IN : stockItemSerialNumberSet];

        // add found Serial Numbers to Set for Check
        for (StockItem__c stockItemKey : stockItemIdList) {
            serialSet.add(stockItemKey.SerialNumber__c);
        }

        // loop trough Serial Numbers from JSON and create new Stock Items if not present
        for (String serialKey : stockItemSerialNumberSet) {
            if (!serialSet.contains(serialKey)) {
                StockItem__c createStockItem = new StockItem__c(SerialNumber__c = serialKey, CreatedByCA__c = true, Type__c = 'Battery');
                createStockItemList.add(createStockItem);
            }
        }

        // insert new Stock Items if necessary
        if (!createStockItemList.isEmpty()) {
            insert createStockItemList;
        }

        // add Stock Item Ids which were present before insert to Set
        for (StockItem__c key : stockItemIdList) {
            if (key.Id != null || key.Id != '') {
                stockItemIdSet.add(key.Id);
            }
        }

        // add Stock Item Id from newly created Stock Items to Set
        for (StockItem__c newKey : createStockItemList) {
            if (newKey.Id != null || newKey.Id != '') {
                stockItemIdSet.add(newKey.Id);
            }
        }

        //query stock items and populate list with stock items
        stockItemList = queryStockItem(stockItemIdSet);

        //call class and method to update stock item with data from JSON request
        AssetEndpointStockItemUpdate.updateStockItemCascading(stockItemList, requestMap, nodesMap, sRequestJSON);

        //loop trough updated stock items and create asset for master stock item
        for (StockItem__c stockItem : stockItemList) {
            if (stockItem.Hierarchy__c == 'Master') {
                //Call Convert StockItem to Asset
                convertedAsset = ConvertStockItemAsset.createAssetFromStockItem(stockItem);
                break;
            }
        }

        if (convertedAsset.AccountId == null && convertedAsset.ContactId == null) {
            //Call Duplicate Check
            List<Asset> assetList = new List<Asset>{convertedAsset};
            DuplicateCheckHandlerv3 dCH = new DuplicateCheckHandlerv3(assetList);
            Map<Id, Map<String, Id>> idMap = dCH.handleObjectsv2();

            //link Asset to Account & Contact
            convertedAsset.AccountId = idMap.get(convertedAsset.Id).get('Account');
            convertedAsset.ContactId = idMap.get(convertedAsset.Id).get('Contact');
        }

        //upsert Asset
        upsert convertedAsset;

        //loop trough stock item list and create electric unit for every stock item
        for (StockItem__c stockItem : stockItemList) {
            //Call Convert StockItem to Electric Unit
            Component__c convertedComponent = ConvertStockItemEUnit.createEUnitFromStockItem(stockItem, requestMap, convertedAsset, sRequestJSON);

            //link Stock Item and convert Stock Item
            stockItem.Account__c = convertedAsset.AccountId;
            stockItem.Asset__c = convertedAsset.Id;
            stockItem.Component__c = convertedComponent.Id;
            stockItem.RecordTypeId = convertedId;
            if (String.isBlank((String) requestMap.get('manually'))) {
                stockItemList[0].ConvertedByCA__c = true;
            }

            //populate maps with master and slave data
            if (convertedComponent.Hierarchy__c == 'Master') {
                masterMap.put(convertedComponent.Id, convertedComponent.SerialNumber__c);
            } else if (convertedComponent.Hierarchy__c == 'Slave') {
                slaveMap.put(convertedComponent.Id, convertedComponent.SerialNumber__c);
            }
            stockItemUpdateList.add(stockItem);
        }
        //update stock items
        update stockItemUpdateList;

        //loop trough updated stock item list
        for (StockItem__c stockItem : stockItemUpdateList) {
            //link the stock item cases, attachments and files with the asset
            ConvertStockItemLinkRelatedRecords.linkCases(stockItem.Id, convertedAsset.Id);
            ConvertStockItemLinkRelatedRecords.linkAttachments(stockItem.Id, convertedAsset.Id);
            ConvertStockItemLinkRelatedRecords.linkFiles(stockItem.Id, convertedAsset.Id);
        }

        //create junction object between components
        ConvertStockItemJunction.createJunction(masterMap, slaveMap);
    }

    public static void convertToCascadingChange(Id changeStockItemId, Map<String, Object> requestMap, String sRequestJSON) {
        //get RecordTypeId for battery assets
        Id batteryRecordId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();

        //get RecordTypeId for converted StockItem
        Id convertedId = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        // initialize maps
        Map<String, String> nodesMap = new Map<String, String>();
        Map<Id, String> masterMap = new Map<Id, String>();
        Map<Id, String> slaveMap = new Map<Id, String>();

        //initialize lists
        List<Object> data = new List<Object>();
        List<StockItem__c> stockItemList = new List<StockItem__c>();

        //initialize String
        String oldMasterSerial;

        //initialize sets
        Set<Id> stockItemIdSet = new Set<Id>();

        //initialize map & string & fill with data
        Map<String, Object> mapCascading = (Map<String, Object>) requestMap.get('pro_cascade');
        String roleString = ((String)mapCascading.get('role')).capitalize();

        //pre fill map & set with data
        nodesMap.put((String) requestMap.get('DE_Ticket_Number'), roleString);
        stockItemIdSet.add(changeStockItemId);

        //loop trough JSON request and populate list with data
        for (Object instance : (List<Object>)mapCascading.get('nodes')) {
            data.add(instance);
        }

        //search for master serial
        if (roleString == 'Master') {
            oldMasterSerial = (String) requestMap.get('IN_riverbox_old_serial');
        } else if (roleString != 'Master') {
            for (Object da : data) {
                String subStringRole = String.valueOf(da).substringBefore(',');
                String subStringSerial = String.valueOf(da).substringAfter(',');
                subStringRole = subStringRole.substringAfter('=');
                subStringSerial = subStringSerial.substringBetween('=', '}');
                if (subStringRole == 'Master') {
                    oldMasterSerial = subStringSerial;
                    break;
                }
            }
        }

        //query stock items and populate list with stock items
        stockItemList = queryStockItem(stockItemIdSet);

        //call class and method to update stock item with data from JSON request
        AssetEndpointStockItemUpdate.updateStockItemCascading(stockItemList, requestMap, nodesMap, sRequestJSON);

        //Query Asset
        List<Asset> assetList = [SELECT Id, AccountId FROM Asset WHERE SerialNumber =: oldMasterSerial AND RecordTypeId =: batteryRecordId];

        //Query Electric Unit
        List<Component__c> componentList = [SELECT Id, Current__c, DeactivatedSince__c, NewComponent__c FROM Component__c WHERE SerialNumber__c =: (String) requestMap.get('IN_riverbox_old_serial')];

        //Call Convert StockItem to E-Unit Class
        Component__c convertedComponent = ConvertStockItemEUnit.createEUnitFromStockItem(stockItemList[0], requestMap, assetList[0], sRequestJSON);

        //update New Electric Unit
        convertedComponent.OldComponent__c = componentList[0].Id;
        update convertedComponent;

        //link Stock Item and convert Stock Item
        stockItemList[0].Account__c = assetList[0].AccountId;
        stockItemList[0].Asset__c = assetList[0].Id;
        stockItemList[0].Component__c = convertedComponent.Id;
        stockItemList[0].RecordTypeId = convertedId;
        if (String.isBlank((String) requestMap.get('manually'))) {
            stockItemList[0].ConvertedByCA__c = true;
        }
        update stockItemList;

        //update Old Electric Unit
        componentList[0].Current__c = false;
        componentList[0].DeactivatedSince__c = System.now();
        componentList[0].NewComponent__c = convertedComponent.Id;
        update componentList[0];

        //link the stock item cases, attachments and files with the asset
        ConvertStockItemLinkRelatedRecords.linkCases(stockItemList[0].Id, assetList[0].Id);
        ConvertStockItemLinkRelatedRecords.linkAttachments(stockItemList[0].Id, assetList[0].Id);
        ConvertStockItemLinkRelatedRecords.linkFiles(stockItemList[0].Id, assetList[0].Id);

        //Query all Electric Units
        List<Component__c> currentComponentList = [SELECT Id, SerialNumber__c, Hierarchy__c, Current__c FROM Component__c WHERE Asset__c =: assetList[0].Id AND Current__c = TRUE];

        //Loop trough current component list
        for (Component__c cmp : currentComponentList) {
            if (cmp.Hierarchy__c == 'Master') {
                masterMap.put(cmp.Id, cmp.SerialNumber__c);
            } else if (cmp.Hierarchy__c == 'Slave') {
                slaveMap.put(cmp.Id, cmp.SerialNumber__c);
            }
        }

        //delete old junction objects
        ConvertStockItemJunction.deleteJunction(oldMasterSerial);

        //create junction object between components
        ConvertStockItemJunction.createJunction(masterMap, slaveMap);
    }

    private static List<StockItem__c> queryStockItem(Set<Id> stockItemIdSet) {
        //get map of stock item fields
        Map<String, Schema.SObjectField> mapStockItemFields = Schema.SObjectType.StockItem__c.fields.getMap();
        //initialize string for database query
        String sQuery = 'SELECT ';
        //check for found stock item fields and generate string
        for (Integer i=0; i < mapStockItemFields.values().size(); i++) {
            if (i != mapStockItemFields.values().size() - 1) {
                sQuery = sQuery + mapStockItemFields.values()[i].getDescribe().getName() + ', ';
            } else if (i == mapStockItemFields.values().size() - 1) {
                sQuery = sQuery + mapStockItemFields.values()[i].getDescribe().getName() + ' FROM StockItem__c WHERE Id IN : stockItemIdSet';
            }
        }
        //initialize database query with generated string
        List<StockItem__c> stockItemList = Database.query(sQuery);
        //return queried stock item list
        return stockItemList;
    }
}