/**
 * AwattarContract
 *
 * Changelog
 * ---------
 *
 * v1.1.2-2018-01-11 (marko@die-interaktiven.de)
 * - Added methods lock() and isLocked() to prevent redundant callouts
 *
 * v1.1.1-2017-11-16 (marko@die-interaktiven.de)
 * - Renamed "sonnenbasic" to "sonnencommunity" (SOBCRM-905)
 *
 * v1.1.0-2017-10-09 (marko@die-interaktiven.de)
 * - Revision with initAction() method which makes actions more flexible
 * - Implemented method actionEmailToCustomer() (SOBCRM-1034)
 *
 * v1.0.0-2017-08-10
 * - initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.1.2-2018-01-11
 */
public class AwattarContract extends AwattarObject {

    private static final String DEBUG_HEADER = 'AwattarContract';
    public static String CONTRACT_STATUS_REVOKE    = 'Revoked';
    public static String CONTRACT_STATUS_ACTIVATED = 'Activated';
    public static String CONTRACT_STATUS_DRAFT     = 'Draft';

    public static String ACTION_CONTRACT_REVOKE   = 'revoke';
    public static String ACTION_EMAIL_TO_CUSTOMER   = 'emailToCustomer';

    private Contract contract;

    private Contract contractBefore;

    private String awattarContractId;

    private String specialAction;

    private static Map<String,List<Map<String,List<SObject>>>> mapObjectsForCustomUpsert = new Map<String,List<Map<String,List<SObject>>>>();

    private Map<String,Set<String>> validFieldsPerUpsertMode;

    /**
     * Init AwattarFields
     */
    protected override void initAwattarFields() {

        this.awattarFields = new Map<String,Object>{
            'metadata'              => new Map<String,String>{
                'sonnen_id' => NULL
            },
            'company'               => NULL,
            'salutation'            => NULL,
            'firstname'             => NULL,
            'surname'               => NULL,
            'dateofbirth'           => NULL,
            'email'                 => NULL,
            'phone'                 => NULL,
            'zipcode'               => NULL,
            'city'                  => NULL,
            'streetname'            => NULL,
            'housenumber'           => NULL,
            //'stairs'                => NULL,
            //'level'                 => NULL,
            //'doornumber'            => NULL,
            'switchtype'            => NULL,
            'supplydate'            => NULL,
            'bankaccountowner'      => NULL,
            'iban'                  => NULL,
            'bic'                   => NULL,
            'meteringpoints'        => new List<Object>(),
            'agbs'                  => NULL,
            'comment'               => NULL
        };

        this.validFieldsPerUpsertMode = new Map<String,Set<String>>{

            // On creation of a new Awattar Contract
            'insert' => new Set<String>{
            },

            'update' => new Set<String>{
            }
        };
    }

    /**
     * Instantiate AwattarContract by contract
     */
    public AwattarContract(Contract contract) {

        if (contract == NULL) {
            throw new AwattarContractException('Contract is null');
        }
        if (contract.Id == NULL) {
            throw new AwattarContractException('Only existing contracts with ID can be passed');
        }
        this.initAwattarFields();

        // Init by contract
        this.contract = contract;

        this.sObjectId = this.contract.Id;

        this.awattarContractId = this.contract.AwattarContractId__c;

        System.debug('AwattarContract - Constructor: ' + contract);

        // Contract is to revoke
        // (As this constructor is also called by futureActionUpsert()
        // it requires that needsUpdate() is call by the API before.
        // So a revoked Contract isn't revoked twice ...)
        if (this.contract.Status == CONTRACT_STATUS_REVOKE) {
            this.specialAction = ACTION_CONTRACT_REVOKE;
        }

        this.setAwattarFieldsFromObject(contract);
    }

    /**
     *
     */
    protected override void setAwattarFieldsFromObjectMap(Map<String,Object> mapFields) {

        String DEBUG_HERE = DEBUG_HEADER + '.setAwattarFieldsFromObjectMap(): ';

        // Set sonnen ID
        ((Map<String,Object>)this.awattarFields.get('metadata')).put('sonnen_id', mapFields.get('reference_id'));

        // Set standard fields
        for (String sFieldName : mapFields.keySet()) {
            if (this.awattarFields.containsKey(sFieldName)) {
                this.awattarFields.put(sFieldName, mapFields.get(sFieldName));
            }
        }

        // Check if billing address must be set
        // This is the case if it differs from the standard (shipping) address
        String sBillingCompare = String.join(new List<String>{
            this.getValueForComparisonFromMap('billing_firstname', mapFields),
            this.getValueForComparisonFromMap('billing_surname', mapFields),
            this.getValueForComparisonFromMap('billing_zipcode', mapFields),
            this.getValueForComparisonFromMap('billing_streetname', mapFields),
            this.getValueForComparisonFromMap('billing_housenumber', mapFields)
        }, ' ');
        String sShippingCompare = String.join(new List<String>{
            this.getValueForComparisonFromMap('firstname', mapFields),
            this.getValueForComparisonFromMap('surname', mapFields),
            this.getValueForComparisonFromMap('zipcode', mapFields),
            this.getValueForComparisonFromMap('streetname', mapFields),
            this.getValueForComparisonFromMap('housenumber', mapFields)
        }, ' ');

        if (sBillingCompare.trim().length() > 0 && sBillingCompare != sShippingCompare) {

            System.debug(DEBUG_HERE + 'Billing address differs from shipping address: ' + sBillingCompare + ' != ' + sShippingCompare);

            Map<String,Object> mapBillingAddress = new Map<String,String>{
                'salutation'    => NULL,
                'firstname'     => NULL,
                'surname'       => NULL,
                'zipcode'       => NULL,
                'city'          => NULL,
                'streetname'    => NULL,
                'housenumber'   => NULL
                //'doornumber'    => NULL,
                //'level'         => NULL,
                //'stairs'        => NULL
            };

            for (String sFieldName : mapBillingAddress.keySet()) {
                String sKey = 'billing_' + sFieldName;
                if (mapFields.containsKey(sKey)) {
                    mapBillingAddress.put(sFieldName, mapFields.get(sKey));
                }
            }
            this.awattarFields.put('billing', mapBillingAddress);
        }
        else {
            System.debug(DEBUG_HERE + 'Billing address equals shipping address');
        }

        //========================================
        // Meteringpoints
        //========================================
        // e.g.
        // "meteringpoints": [
        // {
        //      "id": "AT0010000000000000001000015046001",
        //      "tarif":   "sonnencommunity-consumption",
        //      "sonnencommunity": {
        //          "consumption": 2000
        //      }
        // },
        // {
        //      "id": "AT0010000000000000001000015046002",
        //      "tarif": "sonnencommunity-generation"
        // }],
        List<Object> listMeteringpoints = (List<Object>)this.awattarFields.get('meteringpoints');

        Map<String,Object> mapForecastConsumption = new Map<String,Object>();
        Map<String,Object> mapForecastGeneration  = new Map<String,Object>();

        //------------------
        // - CONSUMPTION
        //------------------
        Map<String,Object> mapConsumption = new Map<String,Object>();

        if (this.contract.AwattarTarif__c == 'sonnencommunity') {
            mapConsumption.put('consumption', mapFields.get('mpt_con_consumption'));
        }
        else if (this.contract.AwattarTarif__c == 'sonnenflat') {
            mapConsumption.put('totalconsumption', this.getNullOrNumber(mapFields.get('mpt_con_totalconsumption')));
            // forecast
            mapForecastConsumption.put('consumption', this.getNullOrNumber(mapFields.get('forecast_consumption')));
            mapForecastConsumption.put('ownconsumption', this.getNullOrNumber(mapFields.get('forecast_ownconsumption')));
        }

        Map<String,Object> mapMeteringpointConsumption = new Map<String,Object>{
            'id'    => mapFields.get('mpt_con_id'),
            'tarif' => mapFields.get('mpt_con_tarif'),
            this.contract.AwattarTarif__c => mapConsumption
        };

        // add forecast if not empty
        if (!mapForecastConsumption.isEmpty()) {
            mapMeteringpointConsumption.put('forecast', mapForecastConsumption);
        }

        listMeteringpoints.add(mapMeteringpointConsumption);

        //------------------
        // - GENERATION
        //------------------
        Map<String,Object> mapMeteringpointGeneration = new Map<String,Object>{
            'id'    => mapFields.get('mpt_gen_id'),
            'tarif' => mapFields.get('mpt_gen_tarif')
        };

        if (this.contract.AwattarTarif__c == 'sonnenflat') {
            mapForecastGeneration.put('generation', this.getNullOrNumber(mapFields.get('forecast_generation')));
        }

        // add forecast if not empty
        if (!mapForecastGeneration.isEmpty()) {
            mapMeteringpointGeneration.put('forecast', mapForecastGeneration);
        }
        listMeteringpoints.add(mapMeteringpointGeneration);

        // Debug
        System.debug(DEBUG_HERE + 'Object fields: ');
        for (String sFieldName : mapFields.keySet()) {
            System.debug(DEBUG_HERE + '    - ' + sFieldName + ': ' + mapFields.get(sFieldName));
        }

        System.debug(DEBUG_HERE + 'aWATTar fields: ');
        for (String sFieldName : this.awattarFields.keySet()) {
            System.debug(DEBUG_HERE + '    - ' + sFieldName + ': ' + this.awattarFields.get(sFieldName));
        }

        System.debug(DEBUG_HERE + 'JSON: ' + JSON.serializePretty(this.awattarFields));
    }

    /**
     *
     */
    private Integer getNullOrNumber(Object numberAsObject) {
        String sValue = String.valueOf(numberAsObject);
        if (sValue == '0') return NULL;
        return Integer.valueOf(sValue);
    }

    /**
     *
     */
    private String getValueForComparisonFromMap(String key, Map<String,Object> valueMap) {
        return valueMap.containsKey(key) ? (valueMap.get(key) == NULL ? '' : String.valueOf(valueMap.get(key)).trim().toLowerCase().replaceAll('[^a-z0-9]', '')) : '';
    }

    /**
     * Return Awattar fields with values
     *
     * This filters all fields according to what is configured
     * for the current upsert mode
     *
     * @see getUpsertMode()
     */
    public override Map<String,Object> getAwattarFields() {

        String sDebugHere = DEBUG_HEADER + '.getAwattarFields() - ';

        System.debug(sDebugHere + 'Filter fields for upsert mode "' + this.getUpsertMode() + '"');

        // MUST respect upsertMode!
        String sUpsertMode = this.getUpsertMode(); // insert, update
        Set<String> lsetValidFieldsForMode = this.validFieldsPerUpsertMode.get(sUpsertMode);

        Map<String,Object> mapAwattarFields = super.getAwattarFields().clone();

        // If valid fields for upsert mode is not empty
        // otherwise return all fields
        if (!lsetValidFieldsForMode.isEmpty()) {
            for (String sFieldName : mapAwattarFields.keySet()) {
                if (!lsetValidFieldsForMode.contains(sFieldName)) {
                    mapAwattarFields.remove(sFieldName);
                }
            }
        }

        return mapAwattarFields;
    }

    /**
     * Returns upsert mode
     */
    public String getUpsertMode() {

        String sMode = 'insert';

        // If Contract has a Awattar Contract ID
        if (this.getAwattarContractId() != NULL) {
            sMode = 'update';
        }

        return sMode;
    }

    /**
     * Init by contract ID
     */
    public AwattarContract(Id contractId) {
        this((Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = :contractId'));
    }

    /**
     * Init an action
     */
    public override void initAction(String action) {

        if (action == ACTION_UPSERT) {
            if (Test.isRunningTest() == true) {
                new AwattarContract(this.sObjectId).actionPersist();
            }
            else {
                AwattarContract.futureActionUpsert(this.sObjectId);
            }
            return;
        }

        if (action == ACTION_EMAIL_TO_CUSTOMER) {
            if (Test.isRunningTest() == true) {
                new AwattarContract(this.sObjectId).actionEmailToCustomer();
            }
            else {
                AwattarContract.futureActionEmailToCustomer(this.sObjectId);
            }
            return;
        }

        throw new AwattarContractException('Unknown action "' + action + '"');
    }

    /**
     * Future upsert of a AwattarContract by a contract ID
     */
    @future(callout=true)
    public static void futureActionUpsert(Id contractId) {
        System.debug('AwattarContract - futureActionUpsert() with contract ' + contractId);
        new AwattarContract(contractId).actionPersist();
    }

    /**
     * Future email to customer
     */
    @future(callout=true)
    public static void futureActionEmailToCustomer(Id contractId) {
        System.debug('AwattarContract - futureActionEmailToCustomer() with contract ' + contractId);
        new AwattarContract(contractId).actionEmailToCustomer();
    }

    /**
     * Action to trigger email to customer via API
     *
     * @since v1.1.0-2017-10-09
     */
    public void actionEmailToCustomer() {

        String DEBUG_HERE = DEBUG_HEADER + '.actionEmailToCustomer() - ';
        String sError;

        Contract contract = this.contract;

        try {

            AwattarApi api = new AwattarApi();
            AwattarApi.AwattarApiResponse awattarResponse = api.triggerEmailToCustomerForContract(this);

            System.debug(DEBUG_HERE + 'Got Awattar API Response: ' + awattarResponse);

            if (awattarResponse.success == false) {
                sError = awattarResponse.error;
                contract.AwattarApiCustomerEmailError__c = (sError != NULL && sError.length() > 500) ? sError.substring(0, 55) : sError;
            }
            else {
                contract.AwattarApiCustomerEmailInitialized__c = System.now();
            }

            contract.AwattarApiCustomerEmailTrigger__c = false;

        }
        catch (Exception e) {
            contract.AwattarApiCustomerEmailError__c = e.getMessage();
        }

        try {
            // Bypass aWATTar trigger methods
            ContractTriggerHandler.bypassMethod('initEmailToCustomerAtAwattar');
            ContractTriggerHandler.bypassMethod('synchronizeToAwattar');
            System.debug(DEBUG_HERE + 'Update contract with bypassing ContractTriggerHandler.initEmailToCustomerAtAwattar() and ContractTriggerHandler.synchronizeToAwattar(): ' + contract);
            update contract;
            ContractTriggerHandler.clearBypassMethod('initEmailToCustomerAtAwattar');
            ContractTriggerHandler.clearBypassMethod('synchronizeToAwattar');
        }
        catch (Exception e) {
            sError = e.getMessage() + ' ' + e.getStackTraceString();
        }

        if (sError != NULL) {
            System.debug(DEBUG_HERE + 'Error: ' + sError);
        }
    }

    /**
     * Persist this object
     *
     * @return Boolean Success
     */
    public override Boolean actionPersist() {

        String DEBUG_HERE = DEBUG_HEADER + '.actionPersist() - ';

        // Validate and if false write to contract
        if (this.validate() == false) {
            return false;
        }

        Contract contract = this.contract;

        // Set Request time
        contract.AwattarApiRequestTime__c = System.now();

        String error = '';
        String errorDescription = '';

        // Upsert contract via API
        try {

            AwattarApi api = new AwattarApi();
            AwattarApi.AwattarApiResponse awattarResponse = api.upsertContract(this);

            System.debug(DEBUG_HERE + 'Got Awattar API Response: ' + awattarResponse);

            // Set request info
            contract.AwattarApiRequest__c = awattarResponse.requestInfo;

            if (awattarResponse.success == false) {
                contract.AwattarApiResponse__c = awattarResponse.error;
                error = awattarResponse.error;
            }
            else {

                contract.AwattarApiResponse__c = awattarResponse.response.getBody();

                if (awattarResponse.resultMap != NULL) {

                    Map<String,Object> resultMap = awattarResponse.resultMap;

                    System.debug(DEBUG_HERE + 'Response result map: ' + resultMap);

                    if (this.getUpsertMode() == 'insert') {
                        if (resultMap.containsKey('id')) {
                            contract.AwattarContractId__c = String.valueOf(resultMap.get('id'));
                        }
                        else {
                            error = 'No contract ID returned';
                        }
                    }
                    else if (this.getUpsertMode() == 'update' && (!resultMap.containsKey('status') || resultMap.get('status') != 'success')) {
                        error = 'No success returned';
                    }
                }

                if (contract.AwattarApiForceSync__c) {
                    System.debug(DEBUG_HERE + 'Reset AwattarApiForceSync__c');
                    contract.AwattarApiForceSync__c = FALSE;
                }
            }

            if (awattarResponse.response != NULL) {
                contract.AwattarApiStatusCode__c = String.valueOf(awattarResponse.response.getStatusCode());
            }
            else {
                // Error on NULL response
                System.debug(DEBUG_HERE + 'awattarResponse.response is NULL');
                error = 'The awattarResponse.response was NULL so the response could not be written to the Contract';
                contract.AwattarApiResponse__c = error;
                errorDescription = '\n\nAwattarResponse: ' + awattarResponse;
            }
        }
        catch (Exception e) {
            contract.AwattarApiResponse__c = e.getMessage();
            error = e.getMessage() + ' ' + e.getStackTraceString();
        }

        try {
            ContractTriggerHandler.bypassMethod('synchronizeToAwattar');
            System.debug(DEBUG_HERE + 'Update contract with bypassing ContractTriggerHandler.synchronizeToAwattar(): ' + contract);
            update contract;
            ContractTriggerHandler.clearBypassMethod('synchronizeToAwattar');

        }
        catch (Exception e) {
            error = e.getMessage() + ' ' + e.getStackTraceString();
        }

        // Open case on error
        if (error.length() > 0) {

            Case errorCase = this.prepareErrorCase();

            errorCase.Contract__c = contract.Id;
            errorCase.AccountId = contract.AccountId;
            errorCase.ContactId = contract.CustomerSignedId;

            errorCase.Subject = 'Error at Awattar Sync for Contract';
            errorCase.Description  = 'Error: ' + error + '\n\n';
            errorCase.Description += errorDescription;

            try {
                insert errorCase;
            }
            catch (Exception e) {
                System.debug(DEBUG_HERE + 'Exception: ' + e.getMessage());
            }
        }

        return true;
    }

    /**
     * Set the contract before to check if the
     * object has to be updated
     */
    public void setContractBefore(Contract contractBefore) {
        this.contractBefore = contractBefore;
    }

    /**
     * Return the wrapped contract object
     */
    public Contract getContract() {
        return this.contract;
    }

    /**
     * Check if the wrapped contract needs to be updated by the API
     */
    public override Boolean needsSync() {

        String DEBUG_HERE = DEBUG_HEADER + '.needsSync(): ';

        Boolean needsSync = false;

        // General activation of sync
        if (!this.contract.AwattarApiSyncActivated__c) {
            System.debug(DEBUG_HERE + 'AwattarApiSyncActivated__c is NOT active: no update');
            return false;
        }

        // Check on upsert lock
        if (this.isLocked(ACTION_UPSERT)) {
            System.debug(DEBUG_HERE + 'Contract is already registered for an update: skip!');
            return false;
        }

        // If Contract has no aWATTar ID yet
        if (this.getAwattarContractId() == NULL) {
            System.debug(DEBUG_HERE + 'No aWATTar contract ID yet - force sync');
            return TRUE;
        }

        // Force update if AwattarApiForceSync__c is set
        if (this.contract.AwattarApiForceSync__c) {
            System.debug(DEBUG_HERE + 'AwattarApiForceSync__c is TRUE - force update');
            needsSync = TRUE;
        }
        else {
            System.debug(DEBUG_HERE + 'Contract has an aWATTar ID (initially pushed) and AwattarApiForceSync__c is FALSE - no update');
            return FALSE;
        }

        if (this.contractBefore != NULL) {

            System.debug(DEBUG_HERE + 'Get old values by creating a fake AwattarContract object');
            AwattarContract awattarContractOld = new AwattarContract(this.contractBefore);

            Map<String,Object> mapOld = awattarContractOld.getAwattarFields();
            Map<String,Object> mapNew = this.getAwattarFields();

            // Clear update fields
            this.updateFields = new Map<String,Map<String,String>>();

            // Check on updates
            this.compareFieldsForUpdate(mapNew, mapOld);

            if (!this.updateFields.isEmpty()) {
                System.debug(DEBUG_HERE + 'Changes: ' + JSON.serializePretty(this.updateFields));
                needsSync = TRUE;
            }

        }
        System.debug(DEBUG_HERE + 'Needs sync: ' + (needsSync ? 'yes' : 'no'));
        return needsSync;
    }

    /**
     * Wrapps compareFieldsForUpdate() without path
     */
    private void compareFieldsForUpdate(Map<String,Object> mapNew, Map<String,Object> mapOld) {
        this.compareFieldsForUpdate(mapNew, mapOld, NULL);
    }

    /**
     * Compare fields to track a contract update
     */
    private void compareFieldsForUpdate(Map<String,Object> mapNew, Map<String,Object> mapOld, String path) {

        for (String sField : mapNew.keySet()) {

            Object newValue = mapNew.get(sField);

            String sFieldPath = (path != NULL ? path + '.' : '') + sField;

            if (!mapOld.containsKey(sField)) {
                this.updateFields.put(sFieldPath, new Map<String,String>{
                    'old' => '',
                    'new' => 'New field/key ' + sField
                });
                continue;
            }

            Object oldValue = mapOld.get(sField);

            if (newValue instanceof Map<String,Object>) {
                this.compareFieldsForUpdate((Map<String,Object>)newValue, (Map<String,Object>)oldValue, sFieldPath);
                continue;
            }
            else if (sField == 'meteringpoints') {

                Map<String,Object> mapOldMeteringpoints = new Map<String,Object>();
                Map<String,Object> mapNewMeteringpoints = new Map<String,Object>();

                List<Object> listOldMeteringpoints = (List<Object>)oldValue;
                List<Object> listNewMeteringpoints = (List<Object>)newValue;

                // Tarif is always set and can be used as key
                for (Object oMeteringpoint : listNewMeteringpoints) {
                    Map<String,Object> mapMeteringpoint = (Map<String,Object>)oMeteringpoint;
                    String tariff = String.valueOf(mapMeteringpoint.get('tarif'));
                    mapNewMeteringpoints.put(tariff, mapMeteringpoint);
                }
                for (Object oMeteringpoint : listOldMeteringpoints) {
                    Map<String,Object> mapMeteringpoint = (Map<String,Object>)oMeteringpoint;
                    String tariff = String.valueOf(mapMeteringpoint.get('tarif'));
                    mapOldMeteringpoints.put(tariff, mapMeteringpoint);
                }

                this.compareFieldsForUpdate(mapNewMeteringpoints, mapOldMeteringpoints, sFieldPath);
                continue;
            }

            String sNewValue = String.valueOf(newValue);
            String sOldValue = String.valueOf(oldValue);
            
            if (sNewValue != sOldValue) {
                this.updateFields.put(sFieldPath, new Map<String,String>{
                    'old' => sOldValue,
                    'new' => sNewValue
                });
            }
        }
    }

    /**
     * Validates the object
     */
    public override Boolean validate() {

        String sDebugHere = DEBUG_HEADER + '.validate() - ';

        // This returns only the fields which can be used for
        // the given upsertMode!
        Map<String,Object> mapAwattarFields = this.getAwattarFields();

        while (TRUE) {

            if (this.specialAction == ACTION_CONTRACT_REVOKE) {
                this.setError('Revoke action is actually not handled by aWATTar API!');
            }

            System.debug(sDebugHere + 'Fields to validate: ' + mapAwattarFields);

            for (String fieldName : mapAwattarFields.keySet()) {

                String value = this.getEmptyStringFromNull(mapAwattarFields.get(fieldName));

                if (
                    (fieldName == 'zipcode' ||
                     fieldName == 'city' ||
                     fieldName == 'streetname' ||
                     fieldName == 'housenumber' ||
                     fieldName == 'supplydate' ||
                     fieldName == 'iban' ||
                     fieldName == 'bic'
                    ) && value.length() == 0) {
                    this.setError('Field "' + fieldName + '" is mandatory for Awattar API');
                    break;
                }

                if (fieldName == 'email' && Pattern.compile('[^@\\s]+@[^@\\s]+\\.[a-zA-Z]{2,}').matcher(value).matches() == false) {
                    this.setError('Invalid email address');
                    break;
                }

                if (fieldName == 'meteringpoints') {

                    if (mapAwattarFields.get(fieldName) == NULL || ((List<Object>)mapAwattarFields.get(fieldName)).isEmpty()) {
                        this.setError('No meteringpoint given');
                        break;
                    }

                    List<Object> listMeteringpoints = (List<Object>)mapAwattarFields.get(fieldName);

                    for (Object oMeteringpoint : listMeteringpoints) {

                        Map<String,Object> mapMeteringpoint = (Map<String,Object>)oMeteringpoint;

                        if (mapMeteringpoint.get('id') == NULL) {
                            this.setError('Meteringpoint needs ID');
                            break;
                        }
                    }

                    if (this.hasError()) {
                        break;
                    }
                }
            }

            //Set<String> lsetValidFields = this.validFieldsPerUpsertMode.get(this.getUpsertMode());

            break;
        }

        if (this.hasError()) {
            System.debug(sDebugHere + 'Validation error occurred: ' + this.getError());
            return FALSE;
        }

        System.debug(sDebugHere + 'Validation OK');

        return TRUE;
    }

    /**
     * Get empty string on NULL values
     */
    private String getEmptyStringFromNull(Object objectValue) {
        return objectValue == NULL ? '' : String.valueOf(objectValue).trim();
    }

    /**
     * Returns the Awattar Contract ID
     */
    public String getAwattarContractId() {
        return (this.awattarContractId != NULL && this.awattarContractId.length() > 0) ? this.awattarContractId : NULL;
    }

    /**
     * Returns the special action (e.g. revoke)
     */
    public String getSpecialAction() {
        return this.specialAction;
    }

    public class AwattarContractException extends Exception {}
}