/**
 * Created by m.muchow on 21.05.2019.
 * Code coverage by the class AssetEndpointV3_Test
 * Code coverage by the class ConvertStockItemManually_Test for lines 34 to 37
 */

public with sharing class AssetEndpointCases {
    public static void checkForCases(Map<String, Object> requestMap, Id assetId) {
        // initialize Case list
        List<Case> insertCaseList = new List<Case>();
        // get Custom Metadata Map
        Map<String, CommAssistCaseHandler__mdt> caseMetadataMap = createMetadataMap();
        // query Asset based on given Asset Id
        Asset queriedAsset = [SELECT Id, AccountId, ContactId, Installer__c, ServicePartner__c FROM Asset WHERE Id =: assetId];
        system.debug('queriedAsset '+queriedAsset);
        // query Stock Item based on request
        StockItem__c queriedStockItem = [SELECT Id, ConvertedByCA__c, Account__r.Name, FirstName__c, LastName__c FROM StockItem__c WHERE SerialNumber__c =: (String) requestMap.get('DE_Ticket_Number')];

        // check in request if riverbox was changed but serialnumber could not be imported automatically
        if ((String) requestMap.get('IN_riverbox_changed') == 'true' && (String) requestMap.get('IN_riverbox_serial_imported') == 'false') {
            Case addCase = defineCase(queriedAsset, queriedStockItem, requestMap, caseMetadataMap, 'Serial Verification');
            insertCaseList.add(addCase);
        }
        // check for Technician Certification
        if (queriedAsset.Installer__c == null && queriedStockItem.ConvertedByCA__c == true) {
            Case addCase = defineCase(queriedAsset, queriedStockItem, requestMap, caseMetadataMap, 'Check Certification');
            insertCaseList.add(addCase);
        }
        // check for Service Partner
        if (queriedAsset.ServicePartner__c == null && queriedStockItem.ConvertedByCA__c == true) {
            Case addCase = defineCase(queriedAsset, queriedStockItem, requestMap, caseMetadataMap, 'No Service Partner');
            insertCaseList.add(addCase);
        }
        // check for difference from manually conversion
        if (String.isNotBlank(queriedStockItem.Account__c) && queriedStockItem.Account__r.Name != (queriedStockItem.FirstName__c +' '+queriedStockItem.LastName__c)) {
            Case addCase = defineCase(queriedAsset, queriedStockItem, requestMap, caseMetadataMap, 'Conversion Difference');
            insertCaseList.add(addCase);
        }
        // insert Cases it any was defined
        if (!insertCaseList.isEmpty()) {
            insert insertCaseList;
        }
    }

    // Method to get Custom Metadata for Case definition
    private static Map<String, CommAssistCaseHandler__mdt> createMetadataMap() {
        // initialize Map
        Map<String, CommAssistCaseHandler__mdt> caseMetadataMap = new Map<String, CommAssistCaseHandler__mdt>();
        // Query Custom Metadata
        List<CommAssistCaseHandler__mdt> caseMetadataList = [SELECT Label, Subject__c, Description__c, RecordTypeId__c, OwnerId__c, Impact__c, Priority__c, Type__c FROM CommAssistCaseHandler__mdt];
        // Populate map based on Label
        for (CommAssistCaseHandler__mdt metadata : caseMetadataList) {
            caseMetadataMap.put(metadata.Label, metadata);
        }
        return caseMetadataMap;
    }

    private static Case defineCase(Asset queriedAsset, StockItem__c queriedStockItem,Map<String, Object> requestMap, Map<String, CommAssistCaseHandler__mdt> caseMetadataMap, String mapString) {
        String oldSerial = 'no Serial';
        // get case metadata based on label
        CommAssistCaseHandler__mdt caseMetaData = caseMetadataMap.get(mapString);
        // get old serial number if present in JSON
        if (String.isNotBlank((String) requestMap.get('IN_riverbox_old_serial'))) {
            oldSerial = String.valueOf(requestMap.get('IN_riverbox_old_serial'));
        }
        // initialize Case
        Case definedCase = new Case();
        // define values of Case defined by the corresponding Custom Metadata
        definedCase.Subject = String.valueOf(caseMetaData.get('Subject__c'));
        definedCase.Description = String.valueOf(caseMetaData.get('Description__c')).replace('SPARTNER', '"'+String.valueOf(requestMap.get('IN_IN_SoldBy'))+'"').replace('OLDSERIAL', oldSerial).replace('NEWSERIAL', String.valueOf(requestMap.get('DE_Ticket_Number')));
        definedCase.RecordTypeId = String.valueOf(caseMetaData.get('RecordTypeId__c'));
        definedCase.Impact__c = String.valueOf(caseMetaData.get('Impact__c'));
        definedCase.OwnerId = String.valueOf(caseMetaData.get('OwnerId__c'));
        definedCase.Priority = String.valueOf(caseMetaData.get('Priority__c'));
        definedCase.Type = String.valueOf(caseMetaData.get('Type__c'));
        // link Case to related Asset
        definedCase.AssetId = queriedAsset.Id;
        // link Case to related Account
        definedCase.AccountId = queriedAsset.AccountId;
        // link Case to related Contact
        definedCase.ContactId = queriedAsset.ContactId;
        // link to Stock Item if Serial Number could not be imported
        if (mapString == 'Serial Verification') {
            definedCase.StockItem__c = queriedStockItem.Id;
        }
        definedCase.Origin = String.valueOf(caseMetadataMap.get('Origin__c'));
        // hardcoded for all Cases created by CA
        definedCase.IsInstallation__c = true;
        // return defined Case
        return definedCase;
    }
}