/**
 * LumenazaMeterInstallation
 *
 * Changelog
 * ---------
 *
 * v1.2.0-2018-04-06 (marko@die-interaktiven.de)
 * - Revised with lumenazaFields as Map<String,Object>
 *
 * v1.1.1-2018-03-28 (SOBCRM-1050)
 * - Extended validate() to immediately validate updateable meters
 * - meterIsUpdateable() now uses LumenazaZ1Synced and LumenazaZ2Synced
 *
 * v1.1.0-2018-03-28 (SOBCRM-1050)
 * - Added Contract ID as "unique_id" for Lumenaza
 * - Revision due to removal of "measurement_location_id"
 * - If a meter is successfully synced (Status 201) it won't be updated anymore
 *
 * v1.0.1-2018-03-26
 * - If response has an error only log error
 *
 * v1.0.0-2017-10-30
 * - Initial
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.2.0-2018-04-06
 * @see LumenazaTest
 */
public class LumenazaMeterInstallation extends LumenazaObject {

    private MeterInstallation__c meterInstallation;
    private MeterInstallation__c meterInstallationBefore; // Currently not in use!

    private final static String DEBUG_HEADER = 'LumenazaMeterInstallation';

    public final Set<String> VALID_METER_NAMES = new Set<String>{'Z2'};

    /**
     * Init LumenazaFields
     */
    protected override void initLumenazaFields() {

        this.lumenazaFields = new Map<String,Object>{
            'customer_id'                   => null, // string (Customer No (Sonnen))
            'contract_id'                   => null, // string (Contract Number)
            'is_consumer'                   => null, // boolean
            'Z1_meter_id'                   => null, // string (Grid Meter ID (Z1) oder Consumption Meter ID (Z2))
            'Z1_meter_role'                 => null, // "Z1" or "Z2"
            'Z1_installation_start'         => null, // date
            'Z2_meter_id'                   => null,
            'Z2_meter_role'                 => null,
            'Z2_installation_start'         => null, // date
            'unique_id'                     => null
        };
    }

    /**
     * Instantiate LumenazaMeterInstallation by MeterInstallation__c
     */
    public LumenazaMeterInstallation(MeterInstallation__c meterInstallation) {

        if (meterInstallation == null) {
            throw new LumenazaObjectException('MeterInstallation object is null');
        }

        this.initLumenazaFields();

        // Init by bonus
        this.meterInstallation = meterInstallation;
        this.sObjectId = this.meterInstallation.Id;

        this.setLumenazaFieldsFromObject(meterInstallation);
    }

    /**
     * Init by MeterInstallation ID
     */
    public LumenazaMeterInstallation(Id id) {
        this((MeterInstallation__c)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('MeterInstallation__c') + ' FROM MeterInstallation__c WHERE Id = :id'));
    }

    /**
     * Init future upsert
     */
    public override void initFutureUpsert() {
        if (Test.isRunningTest() == true) {
            LumenazaMeterInstallation oLumenazaMeterInstallation =  new LumenazaMeterInstallation(this.sObjectId);
            oLumenazaMeterInstallation.persist();
        }
        else {
            LumenazaMeterInstallation.futureUpsert(this.sObjectId);
        }
    }

    /**
     * Future upsert of a LumenazaMeterInstallation by ID
     */
    @future(callout=true)
    public static void futureUpsert(Id id) {
        System.debug(DEBUG_HEADER + '.futureUpsert() with MeterInstallation ID "' + id + '"');
        new LumenazaMeterInstallation(id).persist();
    }

    /**
     * Get the Lumenaza field values for a given meter
     *
     * @param meterName
     *
     * @return
     */
    public Map<String,Object> getLumenazaFieldsForMeter(String meterName) {

        Pattern oPattern = Pattern.compile('^(Z[0-9]+)_(.+)');
        Map<String,Object> mapFieldsToReturn = new Map<String,Object>();

        for (String sFieldName : this.lumenazaFields.keySet()) {

            Object oFieldValue = this.lumenazaFields.get(sFieldName);

            mapFieldsToReturn.put(sFieldName, oFieldValue);

            Matcher oMatches = oPattern.matcher(sFieldName);

            // If field is a meter field starting with Z<No.>_
            if (oMatches.find()) {
                if (oMatches.group(1) == meterName) {
                    mapFieldsToReturn.put(oMatches.group(2), oFieldValue);
                }
                mapFieldsToReturn.remove(sFieldName);
            }
        }

        return mapFieldsToReturn;
    }

    /**
     * Persist this object
     */
    public override Boolean persist() {

        String DEBUG_HERE = DEBUG_HEADER + '.persist() - ';

        // Validate
        if (this.validate() == false) {
            return false;
        }

        MeterInstallation__c meterInstallation = this.meterInstallation;
        System.debug(DEBUG_HERE + ': MeterInstallation ' + meterInstallation);

        // Iterate over all meters on the SAME MeterInstallation object
        // and set fields accordingly
        for (String sMeterName : VALID_METER_NAMES) {

            List<String> listErrors = new List<String>();
            String sResponse = '';

            if (!this.meterIsUpdateable(sMeterName)) {
                System.debug(DEBUG_HERE + 'Meter "' + sMeterName + '" is not updateable - skipping');
                continue;
            }

            if (!this.validateMeter(sMeterName)) {
                System.debug(DEBUG_HERE + 'Meter "' + sMeterName + '" validation failed - skipping');
                continue;
            }

            try {

                // Set Request time
                meterInstallation.put('LumenazaApiRequestTime' + sMeterName + '__c', System.now());

                // Set Lumenaza fields according to meter
                Map<String,Object> mapLumenazaFieldsBackup = this.lumenazaFields;
                this.lumenazaFields = this.getLumenazaFieldsForMeter(sMeterName);

                System.debug(DEBUG_HERE + 'Fields for ' + sMeterName + ': ' + JSON.serializePretty(this.lumenazaFields));

                // Lumenaza Callout
                LumenazaApi api = new LumenazaApi();
                LumenazaApi.LumenazaApiResponse lumenazaResponse = api.upsertMeter(this);

                // Reset old Lumenaza fields
                this.lumenazaFields = mapLumenazaFieldsBackup;

                System.debug(DEBUG_HERE + 'Lumenaza API Response: ' + lumenazaResponse);

                // Set request info
                meterInstallation.put('LumenazaApiRequest' + sMeterName + '__c', this.ensureMaxLength(lumenazaResponse.requestInfo, 5000));

                if (lumenazaResponse.response != null) {
                    // HTTP Status Code
                    meterInstallation.put('LumenazaApiStatusCode' + sMeterName + '__c', String.valueOf(lumenazaResponse.response.getStatusCode()));

                    sResponse = lumenazaResponse.response.getBody();
                }
                else {
                    // Error on null response
                    System.debug(DEBUG_HERE + 'lumenazaResponse.response is null');
                    listErrors.add('lumenazaResponse.response was null so the response!');
                }

                if (lumenazaResponse.success == false) {
                    listErrors.add(lumenazaResponse.error);
                }
            }
            catch (Exception e) {
                listErrors.add(e.getMessage() + ' ' + e.getStackTraceString());
            }

            // If response is empty set errors to response
            if (!listErrors.isEmpty()) {
                sResponse = String.join(listErrors, '\n').trim();
            }

            // Set final response
            meterInstallation.put('LumenazaApiResponse' + sMeterName + '__c', this.ensureMaxLength(sResponse, 5000));
        }

        System.debug(DEBUG_HERE + ': MeterInstallation ' + JSON.serializePretty(meterInstallation));

        try {
            MeterInstallationTriggerHandler.bypassMethod('syncToLumenaza');
            update meterInstallation;
            MeterInstallationTriggerHandler.clearBypassMethod('syncToLumenaza');
        }
        catch (Exception e) {
            error = e.getMessage() + ' ' + e.getStackTraceString();
        }

        /*
        // Open case on error
        if (error.length() > 0) {
            Case errorCase = new Case();
            errorCase.subject = 'Error at Lumenaza Sync for MeterInstallation';
            errorCase.description  = 'Error: ' + error + '\n\n';
            errorCase.description += 'Bonus ' + System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + bonus.Id;
            errorCase.description += errorDescription;
            insert errorCase;
        }
        */

        return TRUE;
    }

    /**
     * Is called by LumenazaApi to check if object needs an update
     */
    public override Boolean needsUpdate() {

        String DEBUG_HERE = DEBUG_HEADER + '.needsUpdate() - ';

        if (!this.meterInstallation.LumenazaApiIsSyncable__c) {
            System.debug(DEBUG_HERE + 'LumenazaApiIsSyncable__c is not true: no upsert');
            return false;
        }

        if (this.isLocked('upsert')) {
            System.debug(DEBUG_HERE + 'MeterInstallation is already registered for an update: skip!');
            return false;
        }

        // Check if any meter is updateable
        for (String sMeterName : VALID_METER_NAMES) {
            if (this.meterIsUpdateable(sMeterName)) {
                return true;
            }
        }

        return true;
    }

    /**
     * Checks if its reasonable to update the given meter
     *
     * @param meterName
     *
     * @return
     */
    private Boolean meterIsUpdateable(String meterName) {

        String DEBUG_HERE = DEBUG_HEADER + '.meterIsUpdateable(' + meterName + ') - ';

        if (Boolean.valueOf(this.meterInstallation.get('Lumenaza' + meterName + 'Synced__c'))) {
            System.debug(DEBUG_HERE + 'MeterInstallation is already synced to Lumenaza: skip!');
            return false;
        }

        System.debug(DEBUG_HERE + 'is updateable');
        return true;
    }

    /**
     * Validates the object on common fields
     */
    public override Boolean validate() {

        System.debug(DEBUG_HEADER + '.validate() - fields: ' + JSON.serializePretty(this.lumenazaFields));

        for (String fieldName : this.lumenazaFields.keySet()) {

            String value = (this.lumenazaFields.get(fieldName) == null) ? '' : String.valueOf(this.lumenazaFields.get(fieldName)).trim();

            if (new Set<String>{'customer_id', 'contract_id', 'unique_id'}.contains(fieldName) && value.length() == 0) {
                this.setError('Field "' + fieldName + '" is mandatory for Lumenaza');
                return false;
            }
        }

        // Validate only updateable meters
        for (String sMeterName : VALID_METER_NAMES) {
            if (this.meterIsUpdateable(sMeterName) && !this.validateMeter(sMeterName)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Validates a meter
     *
     * @param meterName
     *
     * @return
     */
    public Boolean validateMeter(String meterName) {

        String DEBUG_HERE = DEBUG_HEADER + '.validateMeter(' + meterName+ ') - ';

        Map<String,Object> mapLumenazaFields = this.getLumenazaFieldsForMeter(meterName);

        for (String sField : mapLumenazaFields.keySet()) {

            String value = (mapLumenazaFields.get(sField) == null) ? '' : String.valueOf(mapLumenazaFields.get(sField)).trim();

            if (new Set<String>{'meter_id', 'customer_id', 'contract_id', 'unique_id', 'installation_start'}.contains(sField) && value.length() == 0) {
                this.setError('Field "' + sField + '" is mandatory for Lumenaza');
                return false;
            }

            if (sField == 'meter_role' && !(VALID_METER_NAMES.contains(value))) {
                this.setError('Field "' + sField + '" should be: ' + VALID_METER_NAMES);
                return false;
            }
        }

        return true;
    }

    /**
     * Workaround for untyped Lumenaza fields
     * (If this should be fixed one day look at how it's
     * done in the AwattarObject!)
     */
    public static Map<String,Object> toTypedLumenazaFields(Map<String,String> mapLumenazaFields) {

        Map<String,Object> mapLumenazaFieldsTyped = new Map<String,Object>();

        for (String sField : mapLumenazaFields.keySet()) {

            String sValue = mapLumenazaFields.get(sField);

            if (sField == 'is_consumer') {
                mapLumenazaFieldsTyped.put(sField, (sValue == 'true'));
            }
            else {
                mapLumenazaFieldsTyped.put(sField, sValue);
            }
        }

        return mapLumenazaFieldsTyped;
    }

    /**
     * Return the MeterInstallation object
     */
    public MeterInstallation__c getMeterInstallation() {
        return this.meterInstallation;
    }

    /**
     * Set the contract before to check if the
     * object has to be updated
     */
    public void setMeterInstallationBefore(MeterInstallation__c meterInstallationBefore) {
        this.meterInstallationBefore = meterInstallationBefore;
    }
}