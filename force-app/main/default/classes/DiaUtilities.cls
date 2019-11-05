global class DiaUtilities {

    public static String stringValueOrNull(SObject objectToAsk, String property) {
        if (objectToAsk.get(property) != NULL) {
            return String.valueOf(objectToAsk.get(property));
        }
        return NULL;
    }

    public static Boolean isEmpty(Id id) {
        return (id == NULL || String.valueOf(id).length() == 0);
    }

    public static Boolean isEmpty(String str) {
        return (str == NULL || str.length() == 0);
    }

    public static Id getRecordTypeIdByObjectAndName(String objectName, String name) {
        List<RecordType> listRecordTypes = new List<RecordType>([SELECT Id, Name FROM RecordType WHERE SobjectType = :objectName and Name = :name LIMIT 1]);

        if (!listRecordTypes.isEmpty()) {
            return listRecordTypes.get(0).Id;
        }
        return NULL;
    }

    public static String getClassName(Object obj) {
        return String.valueOf(obj).substring(0,String.valueOf(obj).indexOf(':'));
    }



    /**
	 * Gibt aus einem Adress-String die Hausnummer-Komponente zurücl
 	 *
     * @param String Adressen
     * @return String Hausnummernbestandteile
     */
    public static Map<String,String> extractStreetNumber(String street) {

        Map<String,String> address = new Map<String,String>{
        	'street' => street,
            'number' => ''
        };

        Matcher pm = Pattern.compile('^(.+)\\s([\\d]+[\\D\\s/-]*)$|^(\\d+)[,\\s]*\\D+$').matcher(street);

        if (pm.matches()) {
            address.put('street', pm.group(1).trim());
        	address.put('number', (pm.group(2) != NULL) ? pm.group(2).trim() : pm.group(3).trim());
        }

        return address;
    }

    public static List<String> returnAllFieldsAsList(String objectName) {

        try {
	        List<String> fieldNames = new List<String>();
    	    Map<String,Schema.SObjectType> objectApiNameToObjectType;
			Map<String, Schema.SObjectField> fieldApiNameToField;
			Schema.DescribeSObjectResult objectDescription;

			objectApiNameToObjectType = Schema.getGlobalDescribe();
			objectDescription = objectApiNameToObjectType.get(ObjectName).getDescribe();
			fieldApiNameToField = objectDescription.fields.getMap();

			for (String fieldName : fieldApiNameToField.keySet()) {
				fieldNames.add(fieldName);
			}

			return fieldNames;
        }
        catch (Exception e) {
            system.debug('DIA exception: ' + e);
            return null;
        }
    }

    public static String returnAllFieldsAsString(String objectName) {

        List<String> fieldNames = returnAllFieldsAsList(objectName);

        if (fieldNames != null && fieldNames.size() > 0) {
            return String.join(fieldNames, ', ');
        }
        else {
            return '';
        }
    }

	public static String returnSelectAllQuery(String objectName) {

        String fieldNames = returnAllFieldsAsString(objectName);

        if(fieldNames != null) {
            return 'SELECT ' + fieldNames + ' FROM ' + objectName;
        }
        else {
            return '';
        }
    }

    public static String generateRandomString(Integer length) {

        final String chars = '_-.ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String random = '';

        while (random.length() < length) {
           Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
           random += chars.substring(idx, idx+1);
        }
        return random;
    }

    public static Integer generateRandomNumber(Integer maxlength) {

        Double base = Math.pow(10, maxlength);
        Decimal baseNumber = base - 1;
        Integer result = Math.floor(basenumber * Math.random() + 1).intValue();
        result -= (result == base) ? 1 : 0;
        return result;
    }

    public static string padWithZero (String s, Integer length) {

        if (s.length() >= length ) {
            return s;
        }
        else {
            while (s.length() < length) {
                s = '0' + s;
            }
        }
        return s;
    }

    public static Map<String,Map<String,Id>> getRecordTypeMap(List<String> objectNames) {

        Map<String,Map<String,Id>> recordTypeDeveloperNameToId = new Map<String,Map<String,String>>();
        List<RecordType> recordTypes = new List<RecordType>([SELECT Id, Name, DeveloperName, SObjectType FROM RecordType WHERE IsActive = true AND SObjectType IN :objectNames]);

        for (RecordType recordType : recordTypes) {
            if (recordTypeDeveloperNameToId.get(recordType.SObjectType) == NULL) {
                recordTypeDeveloperNameToId.put(recordType.SObjectType, new Map<String,String>());
            }
            recordTypeDeveloperNameToId.get(recordType.SObjectType).put(recordType.DeveloperName, recordType.Id);
        }
		return recordTypeDeveloperNameToId;
    }

    /**
     * Get Record Type ID by SObject name and DeveloperName
     *
     * @param SObjectName
     * @param developerName
     *
     * @return
     */
    public static Id getRecordTypeId(String SObjectName, String developerName) {

        Schema.RecordTypeInfo oRecordTypeInfo = Schema.getGlobalDescribe().get(SObjectName).getDescribe().getRecordTypeInfosByDeveloperName().get(developerName);
        return (oRecordTypeInfo == null) ? null : oRecordTypeInfo.getRecordTypeId();
    }

    /**
     * Get all RecordType IDs for an SObject by DeveloperName
     *
     * @param SObjectName
     * @param lowerCase
     *
     * @return
     */
    public static Map<String, Id> getRecordTypeIds(String SObjectName, Boolean lowerCase) {

        Map<String, RecordTypeInfo> mapRecordTypesByDeveloperName = Schema.getGlobalDescribe().get(SObjectName).getDescribe().getRecordTypeInfosByDeveloperName();
        Map<String, Id> mapRecordTypeIdByDeveloperName = new Map<String, Id>();

        if (!mapRecordTypesByDeveloperName.isEmpty()) {
            for (String sDeveloperName : mapRecordTypesByDeveloperName.keySet()) {

                mapRecordTypeIdByDeveloperName.put(
                    lowerCase ? sDeveloperName.toLowerCase() : sDeveloperName,
                    mapRecordTypesByDeveloperName.get(sDeveloperName).getRecordTypeId()
                );
            }
        }

        return mapRecordTypeIdByDeveloperName;
    }

    /**
     * Overload getRecordTypeIds()
     *
     * @param SObjectName
     *
     * @return
     */
    public static Map<String, Id> getRecordTypeIds(String SObjectName) {
        return getRecordTypeIds(SObjectName, false);
    }


    /**
     * Returns if Org is a sandbox without DML
     *
     * @return bool
     */
    public static Boolean orgIsSandbox() {
        return orgIsSandbox(FALSE);
    }

    /**
     * Returns if Org is a sandbox
     *
     * @param bool If TRUE determine by SOQL otherwise by Host
     * @return bool
     */
    public static Boolean orgIsSandbox(Boolean bySOQL) {

        if (bySOQL) {
            return (Boolean)[SELECT isSandbox FROM Organization LIMIT 1].isSandbox;
        }

        String sHost = System.URL.getSalesforceBaseUrl().getHost();
        return Pattern.matches('.+\\.cs[0-9]+\\..+', sHost);
    }

    /**
     * Returns an SObject as map
     *
     * Another way would be to get them by sobject.getPopulatedFieldsAsMap()
     * but this was causing problems with date fields which were returned
     * as Y-m-d H:i:s (with hours)
     */
    public static Map<String,String> getObjectValuesAsMap(SObject objectToConvert) {

        String objectAsJson = JSON.serialize(objectToConvert);

        Map<String,Object> mapDeserialized = (Map<String,Object>)JSON.deserializeUntyped(objectAsJson);
        Map<String,String> mapKeyValues = new Map<String,String>();

        // Make plain 1-dimensional map
        for (String sKey : mapDeserialized.keySet()) {
            if (!(mapDeserialized.get(sKey) instanceof Map<String,Object>)) {
                mapKeyValues.put(sKey, String.valueOf(mapDeserialized.get(sKey)));
            }
        }

        //for (String sKey : mapKeyValues.keySet()) System.debug(sKey + ': ' + mapKeyValues.get(sKey));

        return mapKeyValues;
    }

    /**
     * Debugs a message with output of method and line
     *
     * Unfortunately Salesforce offers no option to output
     * method and line in System.debug(). So this is a workaround
     * for that by tolerating that an Exception is raised to
     * get the location by stack trace.
     * Notice: Stack trace isn't available with custom exceptions!
     *
     * @param message
     */
    public static void debug(String message) {

        try {
            // Provoke an exception 🤡
            Integer i = 42/0;
        }
        catch (Exception e) {

            List<String> listTrace = e.getStackTraceString().split('\n');
            String sPlace = listTrace[1];
            sPlace = sPlace.replaceAll(': line ([0-9]+), column [0-9]+', ' (l. $1)');

            System.debug(sPlace + ' - ' + message);
        }
    }
}