/**
 * WebOrderUtil
 *
 * Utilities for WebOrders
 *
 * Changelog
 * ---------
 * v1.0.0   2018-10-12  Marko Schmalenbach          Initial
 * v1.1.0   2018-12-20  Marko Schmalenbach          Set datetime of acceptance to TnCsAcceptance__c.DateTimeAccepted__c (SOBCRM-1313)
 *
 * @since 2018-10-12
 * @see RESTServiceOrder
 * @see WebOrderContractCreator
 */
public class WebOrderUtil {

    private static final String DEBUG_HEADER = 'WebOrderUtil.';

    private static Map<Id, String> mapAssetRecordTypeDeveloperNameByIds;

    /**
     * Get the target object name for an SObject
     *
     * In most cases this is the SObject type name
     *
     * @param oSObject
     *
     * @return
     */
    private static String getTargetObjectNameFromSObject(SObject oSObject) {

        String sSObjectType = String.valueOf(oSObject.getSObjectType());
        String sTargetObjectName = sSObjectType;

        if (sSObjectType == 'Asset') {

            // Create mapAssetRecordTypeDeveloperNameByIds
            if (mapAssetRecordTypeDeveloperNameByIds == null) {

                Map<String, Id> mapAssetRecordTypeIdsByDeveloperName = DiaUtilities.getRecordTypeIds('Asset', true); // lowercase keys
                mapAssetRecordTypeDeveloperNameByIds = new Map<Id, String>();

                for (String sDeveloperName : mapAssetRecordTypeIdsByDeveloperName.keySet()) {
                    mapAssetRecordTypeDeveloperNameByIds.put(
                        mapAssetRecordTypeIdsByDeveloperName.get(sDeveloperName),
                        sDeveloperName
                    );
                }
            }

            if (oSObject.get('RecordTypeId') != null && mapAssetRecordTypeDeveloperNameByIds.containsKey((String)oSObject.get('RecordTypeId'))) {
                sTargetObjectName = mapAssetRecordTypeDeveloperNameByIds.get((String)oSObject.get('RecordTypeId'));
            }
        }

        return sTargetObjectName.toLowerCase();
    }

    /**
     * Set Order Input Definition Values to (related) SObjects
     *
     * @param listOrderInputDefinitionValues
     * @param listObjectsToUpdate
     * @return
     */
    public static Map<String,List<SObject>> updateSObjectsByOrderInputDefinitionValues(List<Id> listOrderInputDefinitionValueIds, List<Object> listObjectsToUpdate) {

        final String DEBUG_HERE = DEBUG_HEADER + 'updateSObjectsByOrderInputDefinitionValues() - ';

        // Target Object Name -> List of SObjects
        Map<String,List<SObject>> mapSObjectsForValueCopying = new Map<String,List<SObject>>();

        for (Object oObject : listObjectsToUpdate) {

            if (oObject instanceof List<Object>) {

                List<SObject> listObjects = (List<SObject>)oObject;

                if (!listObjects.isEmpty()) {
                    for (SObject oSObject : listObjects) {
                        mapSObjectsForValueCopying.put(getTargetObjectNameFromSObject(oSObject), listObjects);
                    }
                }
                else {
                    // On empty list simply set target object name to SObject type
                    mapSObjectsForValueCopying.put(
                        String.valueOf(listObjects.getSObjectType()).toLowerCase(),
                        listObjects
                    );
                }
            }
            else {
                SObject oSObject = (SObject)oObject;
                mapSObjectsForValueCopying.put(getTargetObjectNameFromSObject(oSObject), new List<SObject>{oSObject});
            }
        }

        System.debug(DEBUG_HERE + 'SObjectTypes to handle: ' + mapSObjectsForValueCopying.keySet());

        // Collect Order Input Definition Values
        List<OrderInputDefinitionValue__c> listOrderInputDefinitionValue = [
            SELECT
                Value__c,
                OrderInputDefinition__r.Id__c,
                OrderInputDefinition__r.TargetField__c,
                OrderInputDefinition__r.TargetFields__c,
                OrderInputDefinitionJunction__r.TargetFields__c,
                OrderInputDefinitionJunction__r.IsOverridesParentTargetFields__c,
                OrderInputDefinition__r.RecordType.DeveloperName,
                OrderInputDefinition__r.TermsAndConditionsType__c,
                TermsAndConditions__c,
                OpportunityLineItem__c,
                OrderItem__c,
                CreatedDate
            FROM
                OrderInputDefinitionValue__c
            WHERE
                Id IN :listOrderInputDefinitionValueIds
        ];


        Map<String, Map<String, OrderInputDefinitionValue__c>> mapSObjectFieldsToOrderInputDefinitionValue = new Map<String, Map<String, OrderInputDefinitionValue__c>>();

        //----------------------------------------------------------------------------------------
        // Inspect each OrderInputDefinitionValue__c for copying value to target field(s)
        //----------------------------------------------------------------------------------------
        for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listOrderInputDefinitionValue) {

            String sValue = oOrderInputDefinitionValue.Value__c;

            System.debug(DEBUG_HERE + 'Process OrderInputDefinitionValues for OrderInputDefinition "' + oOrderInputDefinitionValue.OrderInputDefinition__r.Id__c + '"');

            // Register values to copy to any target fields on related objects
            // By this it's clear that TargetField is unique among the incoming OrderInputDefinitionValues!
            // Anyway it wouldn't make sense to copy a value from to fields to one target field
            Map<String,Set<String>> mapSObjectToFields = new Map<String,Set<String>>();

            extractTargetFields(oOrderInputDefinitionValue.OrderInputDefinition__r.TargetField__c, mapSObjectToFields);
            extractTargetFields(oOrderInputDefinitionValue.OrderInputDefinition__r.TargetFields__c, mapSObjectToFields);

            // If Junction Target Fields should override those of the parent Order Input Definition
            // clear the map
            if (oOrderInputDefinitionValue.OrderInputDefinitionJunction__r.IsOverridesParentTargetFields__c) {
                mapSObjectToFields.clear();
            }
            extractTargetFields(oOrderInputDefinitionValue.OrderInputDefinitionJunction__r.TargetFields__c, mapSObjectToFields);

            if (!mapSObjectToFields.isEmpty()) {

                System.debug(DEBUG_HERE + 'Target fields: ' + JSON.serializePretty(mapSObjectToFields));

                // Iterate over SObjects and their fields extracted from Order Input Definition Values
                for (String sTargetObjectName : mapSObjectToFields.keySet()) {

                    sTargetObjectName = sTargetObjectName.toLowerCase();

                    if (!mapSObjectFieldsToOrderInputDefinitionValue.containsKey(sTargetObjectName)) {
                        mapSObjectFieldsToOrderInputDefinitionValue.put(sTargetObjectName, new Map<String, OrderInputDefinitionValue__c>());
                    }

                    for (String sSObjectField : mapSObjectToFields.get(sTargetObjectName)) {
                        mapSObjectFieldsToOrderInputDefinitionValue.get(sTargetObjectName).put(sSObjectField, oOrderInputDefinitionValue);
                    }
                }
            }
            else {
                System.debug(DEBUG_HERE + 'No target fields defined');
            }

            // Special handling for Terms and Conditions
            String sOrderInputDefinitionType = oOrderInputDefinitionValue.OrderInputDefinition__r.RecordType.DeveloperName;
            String sSObjectNameAcceptance = 'TnCsAcceptance__c'.toLowerCase();

            if (sOrderInputDefinitionType == 'termsAndConditions' && mapSObjectsForValueCopying.containsKey(sSObjectNameAcceptance)) {

                Boolean bAccepted = (sValue != null && (sValue == 'true' || sValue == '1'));
                Id idTermsAndConditions = oOrderInputDefinitionValue.TermsAndConditions__c;

                // Create a new TermsAndConditionAcceptance
                if (idTermsAndConditions != null) {

                    String sTermsAndConditionsType = oOrderInputDefinitionValue.OrderInputDefinition__r.TermsAndConditionsType__c;
                    System.debug(DEBUG_HERE + 'Create TnCsAcceptance__c instance for Terms and Conditions type "' + sTermsAndConditionsType + '" with ID ' + idTermsAndConditions);

                    mapSObjectsForValueCopying.get(sSObjectNameAcceptance).add(new TnCsAcceptance__c(
                        Accepted__c             = bAccepted,
                        AppAccepted__c          = 'Web Order',
                        DateTimeAccepted__c     = oOrderInputDefinitionValue.CreatedDate,
                        TermsAndConditions__c   = idTermsAndConditions
                    ));
                }
            }
        }

        //----------------------------------------------------------------------------------------
        // Copy OrderInputDefinitionValue.Value__c to found target fields on SObjects
        //----------------------------------------------------------------------------------------
        for (String sTargetObjectName : mapSObjectsForValueCopying.keySet()) {

            if (!mapSObjectFieldsToOrderInputDefinitionValue.containsKey(sTargetObjectName) || mapSObjectFieldsToOrderInputDefinitionValue.get(sTargetObjectName) == null) {
                continue;
            }

            List<SObject> listSObjectsToCopyValuesTo = mapSObjectsForValueCopying.get(sTargetObjectName);
            Integer iSObjectCount = listSObjectsToCopyValuesTo.size();

            String sObjectName = String.valueOf(listSObjectsToCopyValuesTo.get(0).getSObjectType());

            // Get all OrderInputDefinitionValue__c with target fields on current sSObject
            Map<String,OrderInputDefinitionValue__c> mapFieldToOrderInputDefinitionValues = mapSObjectFieldsToOrderInputDefinitionValue.get(sTargetObjectName);

            // Describe
            Schema.DescribeSObjectResult oDescribeSObjectResult = Schema.getGlobalDescribe().get(sObjectName).getDescribe();
            Map<String, Schema.SObjectField> mapSObjectFields = (Map<String, Schema.SObjectField>) oDescribeSObjectResult.fields.getMap();

            System.debug(DEBUG_HERE + 'Handle fields for SObject "' + sObjectName + '"' + (sObjectName != sTargetObjectName ? ' (special name "' + sTargetObjectName + '")' : ''));

            // Iterate over target fields
            for (String sFieldName : mapFieldToOrderInputDefinitionValues.keySet()) {

                OrderInputDefinitionValue__c oOrderInputDefinitionValue = mapFieldToOrderInputDefinitionValues.get(sFieldName);

                // The value as simple string which maybe has to be cast
                String sOrderInputDefinitionValue = oOrderInputDefinitionValue.Value__c;

                String sApiFieldName = String.valueOf(mapSObjectFields.get(sFieldName));
                System.debug(DEBUG_HERE + '    - Target field "' + sApiFieldName + '" will be set to value: ' + sOrderInputDefinitionValue);

                // Do not handle value if it is null as this will
                // change nothing to a the SObject and will potentially
                // raise NULL exceptions at conversions below
                if (sOrderInputDefinitionValue == null) {
                    continue;
                }

                String fieldType = null;

                if (mapSObjectFields.containsKey(sFieldName)) {
                    fieldType = String.valueOf(mapSObjectFields.get(sFieldName).getDescribe().getType());
                }
                else {
                    // Skip invalid fields
                    System.debug(DEBUG_HERE + '        -> Field is not present on SObject - skip it!');
                    continue;
                }

                Boolean bMatchingItemFound = false;
                Integer i=0;

                for (SObject oSObjectToCopyValuesTo : listSObjectsToCopyValuesTo) {

                    String sApiSObjectType = String.valueOf(oSObjectToCopyValuesTo.getSObjectType());
                    i++;

                    if (iSObjectCount > 1) {

                        if (i == 1) {
                            System.debug(DEBUG_HERE + '    - ' + iSObjectCount + ' ' + sApiSObjectType + 's to handle - searching for the one which is linked to the OrderInputDefinitionJunction');
                        }

                        if (sTargetObjectName == 'OpportunityLineItem' && oSObjectToCopyValuesTo.get('Id') == oOrderInputDefinitionValue.OpportunityLineItem__c) {
                            System.debug(DEBUG_HERE + '    - Value will go to ' + sApiSObjectType + ' with Id ' + oOrderInputDefinitionValue.OpportunityLineItem__c);
                            bMatchingItemFound = true;
                        }
                        else if (sTargetObjectName == 'OrderItem' && oSObjectToCopyValuesTo.get('Id') == oOrderInputDefinitionValue.OrderItem__c) {
                            System.debug(DEBUG_HERE + '    - Value will go to ' + sApiSObjectType + ' with Id ' + oOrderInputDefinitionValue.OrderItem__c);
                            bMatchingItemFound = true;
                        }

                        // Continue with next item in list
                        if (!bMatchingItemFound) {
                            continue;
                        }
                    }

                    // Set target fields according to their type
                    if (fieldType == 'currency' || fieldType == 'double') {

                        Decimal strToDec = Decimal.valueOf(sOrderInputDefinitionValue);
                        oSObjectToCopyValuesTo.put(sFieldName, strToDec);
                    }
                    else if (fieldType == 'boolean') {

                        Boolean strToBool = Boolean.valueOf(sOrderInputDefinitionValue);
                        oSObjectToCopyValuesTo.put(sFieldName, strToBool);
                    }
                    else if (fieldType == 'date') {

                        Date strToDate = null;

                        try {
                            strToDate = Date.valueOf(sOrderInputDefinitionValue);
                        }
                        catch (TypeException e) {
                            strToDate = Date.parse(sOrderInputDefinitionValue);
                        }
                        oSObjectToCopyValuesTo.put(sFieldName, strToDate);
                    }
                    else {
                        oSObjectToCopyValuesTo.put(sFieldName, sOrderInputDefinitionValue);
                    }

                    if (iSObjectCount > 1 && bMatchingItemFound) {
                        break;
                    }
                }
            }
        }

        return mapSObjectsForValueCopying;
    }

    /**
     * Extract target fields from a string
     *
     * @param targetFieldString
     *
     * @return
     * @since 2018-06-20
     */
    private static void extractTargetFields(String targetFieldString, Map<String,Set<String>> mapSObjectToFields) {

        if (String.isBlank(targetFieldString)) {
            return;
        }

        List<String> listFields = targetFieldString.replaceAll('\n{2,}', '\n').split('\n');

        for (String sField : listFields) {

            List<String> listFieldParts = sField.split('\\.');

            // Default SObject and field
            String sSObject = 'contract';
            String sSObjectField = listFieldParts.get(0).trim().toLowerCase();

            if (listFieldParts.size() == 2) {
                sSObject      = listFieldParts.get(0).trim().toLowerCase();
                sSObjectField = listFieldParts.get(1).trim().toLowerCase();
            }

            if (String.isBlank(sSObjectField)) {
                continue;
            }

            if (mapSObjectToFields.get(sSObject) == null) {
                mapSObjectToFields.put(sSObject, new Set<String>());
            }

            mapSObjectToFields.get(sSObject).add(sSObjectField);
        }
    }
}