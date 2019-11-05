/**
 * Lumenaza Contract object
 *
 * Changelog
 * ---------
 *
 * v1.16.2   2018-12-17  Marko Schmalenbach         Fix: hasCustomUpsert() set contractBefore.Status == CONTRACT_STATUS_AFTER_SYNC instead of
 *                                                      CONTRACT_STATUS_LUMENAZA_SYNC as CONTRACT_STATUS_AFTER_SYNC is the status which the
 *                                                      Contract gets after the successful Lumenaza push (SOBCRM-1312)
*
 * v1.16.1   2018-11-14  Marko Schmalenbach         Fix: Removed skipping of whole ContractTriggerHandler in LumenazaContract.persist() and
 *                                                      instead only bypass ContractTriggerHandler.synchronizeToLumenaza() (SOBCRM-1301)
 *
 * v1.16.0-2018-10-10 (marko@die-interaktiven.de, SOBCRM-1262)
 * - Added new tariff types "sonnen_pilot", "sonnenPackage" and "sonnen_blanko"
 *
 * v1.15.0-2018-04-27 (marko@die-interaktiven.de, SOBCRM-1177)
 * - Bypass ContractTriggerHandler instead of deprecated LumenazaContractTriggerHandler
 *
 * v1.14.0-2018-04-13 (marko@die-interaktiven.de, SOBCRM-1175)
 * - Make use of "suppressComplexDebugMessages"
 *
 * v1.13.2-2018-04-13 (marko@die-interaktiven.de, SOBCRM-1164)
 * - Fix: Removed setting of contract's StartDate to today at contract change (I don't know why it was in it at all!)
 *
 * v1.13.1-2018-04-12 (marko@die-interaktiven.de, SOBCRM-1164)
 * - Fix: Revoke if CONTRACT_STATUS_AFTER_SYNC -> CONTRACT_STATUS_REVOKE
 *
 * v1.13.0-2018-04-11 (marko@die-interaktiven.de, SOBCRM-1164)
 * - For contract change: If the Lumenaza Customer ID is not provided in the Lumenaza
 *   response it will be set from the previous contract.
 *   Otherwise if it is provided it has to match the one from the previous contract.
 *
 * v1.12.0-2018-04-10, marko@die-interaktiven.de, SOBCRM-1164)
 * - Revised with lumenazaFields as Map<String,Object>
 * - Added contract change functionality
 *
 * v1.11.0 (MSB 2017-12-05)
 * - needsUpsert(): Check if Contract is locked for an update to prevent redundant callouts
 *
 * v1.10.0 (MSB 2017-11-09)
 * - CONTRACT_STATUS_ACTIVATED is now set by Contract.LumenazaActivationStatus__c
 *   so that the status at which sync to Lumenaza is triggered can be set individually (SOBCRM-1093)
 *
 * v1.9.0 (MSB 2017-06-20)
 * - Added handling of "sonnenStrom" (SOBCRM-984)
 *
 * v1.8.0 (MSB 2017-03-23)
 * - Added validTariffTypes as configuration property and added tariff_type "sonnenCity"
 * - validate(): Added validation for "tariff_type" according to upserMode (SOBCRM-852)
 * - Fix: Raise of validation error was turned off accidentally in an older
 *   commit - urgh :/
 *
 * v1.7.2 (MSB 2017-01-02)
 * - Fix: Prevent sending of company_name if is_business is false
 *
 * v1.7.1 (MSB 2016-12-22)
 * - Fix: If the Contract should be revoked hasCustomUpsert() must respect that
 *   as this is no field change at all. This requires a special callout to
 *   revoke at Lumenaza.
 *
 * v1.7.0 (MSB 2016-12-15)
 * - Fix in initLumenazaFields(): Field "title" was renamed to "name_title"
 * - Lumenaza fields are now reduced to the relevant depending on the introduced
 *   "upsertMode" (update, insert, insertForExistingCustomer). By this irrelevant
 *   fields are not longer validated too.
 * - Added a lot to add new Contracts to existing Lumenaza Customers (SOBCRM-763)
 *   (New methods isAccountLumenazaCustomer(), checkOnMultipleContractsByAccountIds(),
 *   setIsAccountLumenazaCustomer(), ...)
 *
 * v1.6.0 (MSB 2016-12-14)
 * - Added handling of Lumenaza Contract Changes as changes cannot be done
 *   by simple updating the Contract via Lumenaza API (see customerUpsert())
 *   (SOBCRM-669)
 * - needsUpdate(): Extended debugging
 * - Added LumenazaContractException class
 *
 * v1.5.0 (MSB 2016-11-29)
 * - persist(): Added error handling for Case
 *
 * v1.4.0 (MSB 2016-11-15)
 * - Added "sonnenFlat" (tariff_type)
 *
 * v1.3.0 (MSB 2016-10-06)
 * - Implemented revokation of contract (SOBCRM-668)
 *
 * v1.2.0 (MSB 2016-10-05)
 * - Revised for using Lumenaza API v3 (SOBCRM-667)
 *
 * v1.1.0 (MSB 2016-06-03)
 * - Luemenaza field "previous_provider" is optional on "subscription_reason" E01 and E02 (SOBCRM-361)
 * - Removed "saas_contract_id" from lumenaza fields
 * - Added optional field "sepa_reference" for lumenaza fields (SOBCRM-378)
 * - Set lumenaza field "sepa_date"
 *
 * v1.0.0 (2016-01-27)
 * - Initial
 *
 * @see LumenazaTest
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.15.0-2018-04-27
 */
public class LumenazaContract extends LumenazaObject {

    private static final String DEBUG_HEADER = 'LumenazaContract';

    private static String CONTRACT_STATUS_LUMENAZA_SYNC          = 'Concluded'; // default status which triggers the sync to Lumenaza

    public static final String CONTRACT_STATUS_REVOKE            = 'Revoked';
    public static final String CONTRACT_STATUS_AFTER_SYNC        = 'Activated';
    public static final String CONTRACT_STATUS_CHANGE_PREVIOUS   = 'TerminatedContractChange'; // status for the previous contract after a contract change

    public static final String SPECIAL_ACTION_REVOKE          = 'revoke';
    public static final String SPECIAL_ACTION_CONTRACT_CHANGE = 'contractChange';

    public static final String SUBSCRIPTION_REASON_CHANGE = 'ContractChange';

    public static String UPSERTMODE_NEW                       = 'insert';
    public static String UPSERTMODE_UPDATE                    = 'update';
    public static String UPSERTMODE_CHANGE                    = 'contractChange';
    public static String UPSERTMODE_NEW_FOR_EXISTING_CUSTOMER = 'insertForExistingCustomer';

    private Contract contract;

    private Contract contractBefore;

    private String lumenazaCustomerId;
    private String lumenazaCustomerIdOfExistingContract;

    private String lumenazaContractId;

    private String specialAction;

    private Boolean isLumenazaCustomer;

    private static Map<String,List<Map<String,List<SObject>>>> mapObjectsForCustomUpsert = new Map<String,List<Map<String,List<SObject>>>>();

    private Map<String,Set<String>> validFieldsPerUpsertMode;
    private Map<String,Set<String>> validProductSpecificsPerTariffTypeAtContractChange;

    public static final Set<String> validTariffTypes = new Set<String>{
        'household', // deprecated
        'heatpump',
        'sonnenFlat',
        'sonnenCity',
        'sonnenStrom', // since 2017-06-14, SOBCRM-984
        // since 2018-10-10, SOBCRM-1262
        'sonnen_pilot',
        'sonnen_blanko',
        'sonnenPackage' // replaces "household"
    };

    /**
     * Init LumenazaFields
     */
    protected override void initLumenazaFields() {

        this.lumenazaFields = new Map<String,Object>{
            'is_business'                     => null, // (mandatory)
            'company_name'                    => null, // (mandatory for companies)
            'salutation'                      => null, // (mandatory) „Herr“ or „Frau“
            //'titel'                         => null, // (deprecated since API v3)
            'name_title'                      => null, // (optional, „Dr.“, „Prof.“, „Prof. Dr.“ , since API v3) !Changed to name_title by v1.7.0
            'first_name'                      => null, // (of contact for companies) (mandatory)
            'last_name'                       => null, // (of contact for companies) (mandatory)
            'birthday'                        => null, // (optional) format: YYYY-MM-DD, since API v3)
            'telephone'                       => null, // (optional)
            'email'                           => null, // (mandatory)
            'deliv_address_street'            => null, // (mandatory)
            'deliv_address_house_number'      => null, // (mandatory)
            'deliv_address_zipcode'           => null, // (mandatory),
            'deliv_address_city'              => null, // (mandatory),
            'deliv_address_addition'          => null, // (optional, additions to the delivery address, since API v3, NOT IN USE),
            //'delivery_start'                => null, // (deprecated since API v3)
            'preferred_delivery_start'        => null, // (optional, format: YYYY-MM-DD, the preferred delivery start if requested by the customer. This date has to lie two weeks in the future if the subscription_reason is "E03" and up to six weeks in the past if the reason is "E01" or "E02", since API v3)
            'bill_address_street'             => null, // (if empty we assume the delivery address data),
            'bill_address_house_number'       => null, // (if empty we assume the delivery address data),
            'bill_address_zipcode'            => null, // (if empty we assume the delivery address data),
            'bill_address_city'               => null, // (if empty we assume the delivery address data),
            'bill_address_addition'           => null, // (optional, since API v3, NOT IN USE)
            'subscription_reason'             => null, // (mandatory) Move into Location (E01) | New Site (E02) | Change of Provider (E03)
            'meter_id'                        => null, // (mandatory) the ID for the meter
            'meteringpoint_id'                => null, // (optional), the meteringpoint (Zählpunkt)
            'previous_provider'               => null, // (mandatory, optional on subscription_reason E01 and E02) this should be already the Marketpartner ID of the „Alt-Lieferant". IDs are managed by BDEW (https://bdew-codes.de/Codenumbers/BDEWCodes/CodeOverview)
            'annual_consumption'              => null, // (mandatory), the yearly consumption as indicated on the latest year end bill of the customer.
            'bank_data_first_name'            => null, // (mandatory), owner of the account
            'bank_data_last_name'             => null, // (mandatory), owner of the account
            'bank_data_iban'                  => null, // (mandatory),
            'sepa_date'                       => null, // (mandatory, format: YYYY-MM-DD), the dated where the sepa reference form has been signed by the customer or the date of the online contract.
            'sepa_reference'                  => null, // (optional) SEPA reference
            'tariff_type'                     => null, // (mandatory), see property "validTariffTypes"
            'saas_customer_id'                => null, // In case the consumer_id is created by the REST API client, this field is used to communicate this information. Note: requires project specific adaptation
            'free_amount'                     => null, // (optional, integer, since API v3), in case of using a flat tariff this is the free amount (in kWh) for the first step
            // Salesforce field consumption_before_battery_inst is resolved to the longer Lumenaza name
            'consumption_before_battery_inst' => 'consumption_before_battery_installation', // (optional, integer, since API v3) in case of using a flat tariff this is the overall consumption (in kWh) before sign the contract
            // Only for contract changes
            // 2018-04-04 (SOBCRM-1164)
            'is_company'                      => null, // (mandatory) same as is_business
            'bank_data_bic'                   => null, // (optional)
            'meter_reading_date'              => null, // (mandatory) date when the meter was read
            'meter_reading_value'             => null, // (mandatory) meter value
            'product_specifics'               => null  // (mandatory according to product)
        };

        this.validFieldsPerUpsertMode = new Map<String,Set<String>>{

            // On creation of a new Lumenaza Contract
            'insert' => new Set<String>{
                'is_business',
                'company_name',
                'salutation',
                'name_title',
                'first_name',
                'last_name',
                'birthday',
                'telephone',
                'email',
                'bill_address_street',
                'bill_address_house_number',
                'bill_address_zipcode',
                'bill_address_city',
                'bill_address_addition',
                'bank_data_first_name',
                'bank_data_last_name',
                'bank_data_iban',
                'sepa_date',
                'sepa_reference',

                'annual_consumption',
                'deliv_address_street',
                'deliv_address_house_number',
                'deliv_address_zipcode',
                'deliv_address_city',
                'deliv_address_addition',
                'meter_id',
                'meteringpoint_id',
                'preferred_delivery_start',
                'previous_provider',
                'subscription_reason',
                'tariff_type',
                'saas_customer_id',
                'free_amount',
                'consumption_before_battery_installation'
            },

            // This fields CANNOT BE MODIFIED according to API v3:
            //  - subscription_reason,
            //  - meteringpoint_id
            //  - tariff_type
            //  - saas_customer_id
            //  - free_amount
            //  - consumption_before_battery_installation
            'update' => new Set<String>{
                'is_business',
                'company_name',
                'salutation',
                'name_title',
                'first_name',
                'last_name',
                'birthday',
                'telephone',
                'email',
                'bill_address_street',
                'bill_address_house_number',
                'bill_address_zipcode',
                'bill_address_city',
                'bill_address_addition',
                'bank_data_first_name',
                'bank_data_last_name',
                'bank_data_iban',
                'sepa_date',
                'sepa_reference',

                'annual_consumption',
                'deliv_address_city',
                'deliv_address_house_number',
                'deliv_address_street',
                'deliv_address_zipcode',
                'deliv_address_addition',
                'preferred_delivery_start',
                'previous_provider',
                'meter_id'
            },

            // On creation of a new Lumenaza Contract which should be
            // added to an existing customer
            'insertForExistingCustomer' => new Set<String>{
                'annual_consumption',
                'deliv_address_city',
                'deliv_address_house_number',
                'deliv_address_street',
                'deliv_address_zipcode',
                'deliv_address_addition',
                'preferred_delivery_start',
                'previous_provider',
                'subscription_reason',
                'tariff_type',
                'meter_id',
                'meteringpoint_id',
                'free_amount',
                'consumption_before_battery_installation'
            },
            // New since 2018-04-04 (SOBCRM-1164)
            'contractChange' => new Set<String>{
                'company_name',
                'first_name',
                'last_name',
                'bill_address_street',
                'bill_address_house_number',
                'bill_address_zipcode',
                'bill_address_city',
                'bill_address_addition',
                'bank_data_first_name',
                'bank_data_last_name',
                'bank_data_iban',
                'tariff_type',
                'meter_id',
                'is_company',
                'bank_data_bic',
                'meter_reading_date',
                'meter_reading_value',
                'product_specifics',
                'saas_customer_id',
                'sepa_reference'
            }
        };

        this.validProductSpecificsPerTariffTypeAtContractChange = new Map<String,Set<String>>{
            'sonnenFlat' => new Set<String>{
                'free_amount',
                'consumption_before_battery_installation'
            },
            'sonnenCity' => new Set<String>{
                'free_amount'
            },
            'sonnenStrom' => new Set<String>{
            }
        };
    }

    /**
     * Instantiate LumenazaContract by contract
     */
    public LumenazaContract(Contract contract) {

        if (contract == null) {
            throw new LumenazaContractException('Contract is null');
        }
        if (contract.Id == null) {
            throw new LumenazaContractException('Only existing contracts with ID can be passed');
        }
        this.initLumenazaFields();

        // Init by contract
        this.contract = contract;

        this.sObjectId = this.contract.Id;

        this.lumenazaCustomerId = this.contract.LumenazaCustomerId__c;
        this.lumenazaContractId = this.contract.LumenazaContractId__c;

        if (!suppressComplexDebugMessages) {
            System.debug('LumenazaContract - Constructor: ' + JSON.serializePretty(contract.getPopulatedFieldsAsMap()));
        }

        // Set contract's individual activation status (SOBCRM-1093)
        if (this.contract.LumenazaActivationStatus__c != null) {
            CONTRACT_STATUS_LUMENAZA_SYNC = this.contract.LumenazaActivationStatus__c;
        }

        // Contract is to revoke
        // (As this constructor is also called by futureUpsert()
        // it requires that needsUpdate() is call by the API before.
        // So a revoked Contract isn't revoked twice ...)
        if (this.contract.Status == CONTRACT_STATUS_REVOKE) {
            this.specialAction = SPECIAL_ACTION_REVOKE;
            System.debug('LumenazaContract - Constructor: Set special action "' + SPECIAL_ACTION_CONTRACT_CHANGE + '"');
        }
        else if (this.isContractChange()) {
            this.specialAction = SPECIAL_ACTION_CONTRACT_CHANGE;
            System.debug('LumenazaContract - Constructor: Set special action "' + SPECIAL_ACTION_CONTRACT_CHANGE + '"');
        }

        this.setLumenazaFieldsFromObject(contract);
    }

    /**
     * Return Lumenaza fields with values
     *
     * This filters all fields according to what is configured
     * for the current upsert mode
     *
     * @see getUpsertMode()
     */
    public override Map<String,Object> getLumenazaFields() {

        String sDebugHere = DEBUG_HEADER + '.getLumenazaFields() - ';

        System.debug(sDebugHere + 'Filter fields for upsert mode "' + this.getUpsertMode() + '"');

        // MUST respect upsertMode!
        String sUpsertMode = this.getUpsertMode(); // insert, update, insertForExistingCustomer, contractChange
        Set<String> lsetValidFieldsForMode = this.validFieldsPerUpsertMode.get(sUpsertMode);

        Map<String,Object> mapLumenazaFields = super.getLumenazaFields().clone();

        // Set "product_specifics" for contractChange
        if (sUpsertMode == UPSERTMODE_CHANGE) {

            String sTariffType = String.valueOf(mapLumenazaFields.get('tariff_type'));
            Set<String> lsetFields = this.validProductSpecificsPerTariffTypeAtContractChange.get(sTariffType);

            if (lsetFields != null && !lsetFields.isEmpty()) {

                Map<String,Object> mapProductSpecifics = new Map<String,Object>();

                // Get the field from the general map of lumenazaFields
                for (String sFieldName : lsetFields) {
                    mapProductSpecifics.put(sFieldName, mapLumenazaFields.get(sFieldName));
                }

                mapLumenazaFields.put('product_specifics', mapProductSpecifics);
            }
        }

        // Remove fields which are not intended to be among the
        // the update fields
        for (String sFieldName : mapLumenazaFields.keySet()) {
            if (!lsetValidFieldsForMode.contains(sFieldName)) {
                mapLumenazaFields.remove(sFieldName);
            }
        }

        Boolean bIsNotBusiness = mapLumenazaFields.get('is_business') == null || !Boolean.valueOf(mapLumenazaFields.get('is_business'));
        Boolean bIsNotCompany  = mapLumenazaFields.get('is_company') == null || !Boolean.valueOf(mapLumenazaFields.get('is_company'));

        // To avoid Lumenaza error on unnecessary fields
        if (bIsNotBusiness && bIsNotCompany) {
            mapLumenazaFields.remove('company_name');
        }

        return mapLumenazaFields;
    }

    /**
     * Returns upsert mode
     */
    public String getUpsertMode() {

        String sMode = UPSERTMODE_NEW;

        // If Contract has a Lumenaza Contract ID
        if (this.getLumenazaContractId() != null) {
            sMode = UPSERTMODE_UPDATE;
        }
        // On Contract change
        else if (this.specialAction == SPECIAL_ACTION_CONTRACT_CHANGE) {
            sMode = UPSERTMODE_CHANGE;
        }
        // If
        // - Contract has NO Lumenaza Contract ID AND
        // - Customer already exists at Lumenaza
        else if (this.isAccountLumenazaCustomer()) {
            sMode = UPSERTMODE_NEW_FOR_EXISTING_CUSTOMER;
        }

        return sMode;
    }

    /**
     * Init by contract ID
     */
    public LumenazaContract(Id contractId) {
        this((Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = :contractId'));
    }

    /**
     * Init future upsert
     */
    public override void initFutureUpsert() {
        if (Test.isRunningTest() == true) {
            System.debug(DEBUG_HEADER + '.initFutureUpsert() - persist immediately in test mode');
            new LumenazaContract(this.sObjectId).persist();
        }
        else {
            LumenazaContract.futureUpsert(this.sObjectId);
        }
    }

    /**
     * Future upsert of a LumenazaContract by a contract ID
     */
    @future(callout=true)
    public static void futureUpsert(Id contractId) {
        System.debug('LumenazaContract - futureUpsert() with contract ' + contractId);
        new LumenazaContract(contractId).persist();
    }

    /**
     * Returns if class has own upsert handling
     *
     * If Contract has Lumenaza Contract ID and there is
     *  - no revokation to do and
     *  - no contact change to do
     * then there must be a change
     * in the Contract's data
     */
    public override Boolean hasCustomUpsert() {

        // Return TRUE on update but not on revokation!
        Boolean bChangedToRevoke = (
            this.contractBefore != null &&
            this.contract != null &&
            this.contractBefore.Status == CONTRACT_STATUS_AFTER_SYNC &&
            this.contract.Status == CONTRACT_STATUS_REVOKE
        );

        // If there is a Lumenaza Customer Id the Contract must be activated
        // and synchronized to Lumenaza in the past
        return (
            this.getLumenazaContractId() != null &&
            this.getLumenazaCustomerId() != null &&
            !bChangedToRevoke &&
            !this.isContractChange()
        );
    }

    /**
     * Do custom upsert
     *
     * This covers only updates with a Changeset mechanism.
     * As changes to an existing Contract cannot be made by simple
     * updating the Contract via Lumenaza API we create Changesets
     * with Changes which are asynchronously processed by a batch
     * later.
     *
     * @see hasCustomUpsert()
     */
    public override Boolean customUpsert() {

        String debugHere = DEBUG_HEADER + '.customUpsert() - ';

        // Only Updates are handled
        String customerId = this.getLumenazaCustomerId();
        String contractId = this.getLumenazaContractId();

        if (customerId == null) {
            throw new LumenazaContractException('Missing Lumenaza Customer ID for update. Call hasCustomUpsert() first!');
        }
        if (contractId == null) {
            throw new LumenazaContractException('Missing Lumenaza Contract ID for update. Call hasCustomUpsert() first!');
        }

        Integer errors = 0;

        if (this.needsUpdate() == true) {
            if (this.validate() == false) {
                errors++;
            }
        }
        else {
            System.debug(debugHere + 'Contract with ID "' + this.sObjectId + '" needs no update');
            return true;
        }

        if (errors > 0) {
            return false;
        }

        Map<String,Map<String,String>> mapUpdateFields = this.getUpdateFields();

        System.debug(debugHere + 'Fields with changes: ' + mapUpdateFields);

        if (mapUpdateFields.isEmpty()) {
            throw new LumenazaContractException('needsUpdate() returns true but no update fields are set');
        }

        //-------------------------------------------------
        // Register Changsets and Chaonges for insert
        //-------------------------------------------------
        Map<String,List<SObject>> mapForUpsert = new Map<String,List<SObject>>();

        // Create changeset
        LumenazaContractChangeset__c oChangeset = new LumenazaContractChangeset__c(
            Contract__c = this.sObjectId
        );
        mapForUpsert.put(String.valueOf(LumenazaContractChangeset__c.class), new List<SObject>{oChangeset});

        System.debug(debugHere + 'Created Lumenaza Contract Changeset: ' + oChangeset);

        // Add changes to changeset
        List<SObject> listChangesToInsert = new List<SObject>();

        for (String field : mapUpdateFields.keySet()) {

            Map<String,String> mapOldNewValue = mapUpdateFields.get(field);

            listChangesToInsert.add(new LumenazaContractChange__c(
                Contract__c = this.sObjectId,
                Field__c    = field,
                OldValue__c = mapOldNewValue.get('old'),
                NewValue__c = mapOldNewValue.get('new')
            ));
        }
        mapForUpsert.put(String.valueOf(LumenazaContractChange__c.class), listChangesToInsert);

        System.debug(debugHere + 'Created Lumenaza Contract Changes: ' + listChangesToInsert);

        // Add objects to upsert
        this.addObjectsForUpsert('changesToChangeset', mapForUpsert);

        return TRUE;
    }

    /**
     *  Adds an object for an upsert to a list to minimize DMLs
     *
     *  @see processObjectsForUpsert()
     */
    private void addObjectsForUpsert(String upsertType, Map<String,List<SObject>> objectsForUpsert) {

        if (mapObjectsForCustomUpsert == null) {
            mapObjectsForCustomUpsert = new Map<String,List<Map<String,List<SObject>>>>();
        }
        if (mapObjectsForCustomUpsert.get(upsertType) == null) {
            mapObjectsForCustomUpsert.put(upsertType, new List<Map<String,List<SObject>>>());
        }
        mapObjectsForCustomUpsert.get(upsertType).add(objectsForUpsert);
    }

    /**
     * Process objects for upsert
     *
     * @see customUpsert()
     */
    public override Boolean processObjectsForUpsert() {

        String sDebugHere = DEBUG_HEADER + '.processObjectsForUpsert() - ';

        if (!mapObjectsForCustomUpsert.isEmpty()) {

            for (String upsertType : mapObjectsForCustomUpsert.keySet()) {

                List<Map<String,List<SObject>>> listMapTypeToObjects = mapObjectsForCustomUpsert.get(upsertType);

                // Insert changeset and changes
                if (upsertType == 'changesToChangeset') {

                    // Bypass ContractTriggerHandler which would be triggered again
                    // because LumenazaContractChangeset__c is the detail part of the
                    // master/detail relationship with Contract!
                    TriggerHandler.bypass('ContractTriggerHandler');

                    try {

                        List<LumenazaContractChangeset__c> listAllChangesets = new List<LumenazaContractChangeset__c>();
                        List<List<LumenazaContractChange__c>> listAllChangesToChangeset = new List<List<LumenazaContractChange__c>>();

                        // Iterate of all Changsets with Changes maps and collect changesets and changes
                        for (Map<String, List<SObject>> mapTypeToObjects : listMapTypeToObjects) {

                            String sClassNameChangeset = String.valueOf(LumenazaContractChangeset__c.class);
                            String sClassNameChange = String.valueOf(LumenazaContractChange__c.class);

                            List<LumenazaContractChangeset__c> listChangesets = mapTypeToObjects.get(sClassNameChangeset);
                            List<LumenazaContractChange__c> listChanges = mapTypeToObjects.get(sClassNameChange);

                            if (listChangesets == null || listChangesets.isEmpty()) {
                                throw new LumenazaContractException('No ' + sClassNameChangeset + ' found to insert');
                            }
                            if (listChangesets.size() > 1) {
                                throw new LumenazaContractException('Only one ' + sClassNameChangeset + ' expected');
                            }
                            if (listChanges == null || listChanges.isEmpty()) {
                                throw new LumenazaContractException('No ' + sClassNameChange + ' found to insert');
                            }

                            listAllChangesets.add(listChangesets.get(0));
                            listAllChangesToChangeset.add(listChanges);
                        }

                        System.debug(sDebugHere + 'Insert ' + listAllChangesets.size() + ' changeset(s)');
                        // Insert all changesets
                        insert listAllChangesets;

                        Integer iChangesetIndex = 0 ;
                        List<LumenazaContractChange__c> listChangesToInsert = new List<LumenazaContractChange__c>();

                        for (List<LumenazaContractChange__c> listChangesToSetChangesetIdFor : listAllChangesToChangeset) {

                            Id idChangeset = listAllChangesets.get(iChangesetIndex).Id;

                            for (LumenazaContractChange__c oChange : listChangesToSetChangesetIdFor) {
                                oChange.LumenazaContractChangeset__c = idChangeset;
                                listChangesToInsert.add(oChange);
                            }
                            iChangesetIndex++;
                        }

                        System.debug(sDebugHere + 'Insert ' + listChangesToInsert.size() + ' change(s)');
                        insert listChangesToInsert;
                    }
                    finally {
                        // Restore ContractTriggerHandler
                        TriggerHandler.clearBypass('ContractTriggerHandler');

                        // IMPORTANT: Finally clear all handled objects!
                        // Otherwise they might be handled ony again because mapObjectsForCustomUpsert
                        // is a static member.
                        mapObjectsForCustomUpsert.get(upsertType).clear();
                    }

                }
                else {
                    throw new LumenazaContractException('Unkown upsertType "' + upsertType + '"');
                }
            }
        }

        return TRUE;
    }

    /**
     * Persist this object
     *
     * @return Boolean Success
     */
    public override Boolean persist() {

        // Validate and if false write to contract
        if (this.validate() == false) {
            return false;
        }

        String DEBUG_HERE = DEBUG_HEADER + '.persist() - ';

        System.debug(DEBUG_HERE + 'Start persisting');

        Contract contract = this.contract;

        // Set Request time
        contract.Lumenaza_ApiRequestTime__c = System.now();

        String error = '';
        String errorDescription = '';

        // Upsert contract via API
        try {

            LumenazaApi api = new LumenazaApi();
            LumenazaApi.LumenazaApiResponse lumenazaResponse = api.upsertContract(this);

            System.debug(DEBUG_HERE + 'Got Lumenaza API Response: ' + lumenazaResponse);

            // Set request info
            contract.Lumenaza_ApiRequest__c = lumenazaResponse.requestInfo;

            if (lumenazaResponse.success == false) {
                contract.Lumenaza_ApiResponse__c = lumenazaResponse.error;
                error = lumenazaResponse.error;
            }
            else {

                contract.Lumenaza_ApiResponse__c = lumenazaResponse.response.getBody();

                if (lumenazaResponse.resultMap != null) {

                    Map<String,String> resultMap = lumenazaResponse.resultMap;

                    if (resultMap.containsKey('contract_id')) {
                        contract.LumenazaContractId__c = resultMap.get('contract_id');
                    }
                    if (resultMap.containsKey('consumer_id')) {
                        contract.LumenazaCustomerId__c = resultMap.get('consumer_id');
                    }
                }
            }

            if (lumenazaResponse.response != null) {

                if (Test.isRunningTest() && contract.Lumenaza_ApiStatusCode__c == 'TEST') {
                    System.debug(DEBUG_HERE + 'Set a fake error to raise a case');
                    error = 'TESTERROR';
                }

                contract.Lumenaza_ApiStatusCode__c = String.valueOf(lumenazaResponse.response.getStatusCode());
            }
            else {
                // Error on null response
                System.debug(DEBUG_HERE + 'lumenazaResponse.response is null');
                error = 'The lumenazaResponse.response was null so the response could not be written to the Contract';
                contract.Lumenaza_ApiResponse__c = error;
                errorDescription = '\n\nLumenazaResponse: ' + lumenazaResponse;
            }
        }
        catch (Exception e) {
            contract.Lumenaza_ApiResponse__c = e.getMessage();
            error = e.getMessage() + ' ' + e.getStackTraceString();
        }

        // Set status to CONTRACT_STATUS_AFTER_SYNC (SOBCRM-1164, since 2018-04-04)
        Boolean bIsContractChange = (this.specialAction == SPECIAL_ACTION_CONTRACT_CHANGE);

        if (bIsContractChange) {

            if (contract.LumenazaCustomerId__c != null) {
                if (contract.LumenazaCustomerId__c != this.getLumenazaPreviousCustomerId()) {
                    error = 'The Lumenaza Customer ID from the response does not match the one of the previous contract';
                }
            }
            else {
                // Set LumenazaCustomerId__c to the ID of the previous contract
                contract.LumenazaCustomerId__c = this.getLumenazaPreviousCustomerId();
            }
        }

        if (error.length() == 0
            && contract.LumenazaContractId__c != null
            && contract.LumenazaCustomerId__c != null
            && (this.specialAction == null || bIsContractChange)) {

            contract.Status = CONTRACT_STATUS_AFTER_SYNC;
            System.debug(DEBUG_HERE + 'Set contract\'s status to "' + contract.Status);

            // Contract change
            if (bIsContractChange) {

                contract.DeliveryStart__c = contract.StartDate;

                // Changes to the previous contract
                Contract oPreviousContract = new Contract(
                    Id                      = contract.ContractPrevious__c,
                    Status                  = CONTRACT_STATUS_CHANGE_PREVIOUS,
                    EndDate                 = contract.Lumenaza_meter_reading_date__c, // Usually set to StartDate - 1
                    MeterReadingValueEnd__c = contract.MeterReadingValueStart__c,
                    ContractFollowing__c    = contract.Id
                );

                try {
                    ContractTriggerHandler.bypassMethod('synchronizeToLumenaza');
                    System.debug(DEBUG_HERE + 'Contract change was done, update previous contract: ' + JSON.serializePretty(oPreviousContract.getPopulatedFieldsAsMap()));
                    update oPreviousContract;
                    ContractTriggerHandler.clearBypassMethod('synchronizeToLumenaza');
                }
                catch (Exception e) {
                    error = 'Error updating previous contract "' + contract.ContractPrevious__c + '": ' + e.getMessage() + ' ' + e.getStackTraceString();
                }
            }
        }

        try {
            ContractTriggerHandler.bypassMethod('synchronizeToLumenaza');
            System.debug(DEBUG_HERE + 'Update contract with bypassing ContractTriggerHandler.synchronizeToLumenaza(): ' + contract);
            update contract;
            ContractTriggerHandler.clearBypassMethod('synchronizeToLumenaza');
        }
        catch (Exception e) {
            error = (error.length() > 0 ? '\n\n' : '') + 'Error updating contract: ' + e.getMessage() + ' ' + e.getStackTraceString();
        }

        // Open case on error
        if (error.length() > 0) {

            System.debug(DEBUG_HERE + 'An error occurred and a Case is created: ' + error);

            // Tested by LuemenazaTest.testLumenazaContractCreationWithErrorAndCase()
            Case errorCase = this.prepareErrorCase();

            errorCase.Contract__c = contract.Id;
            errorCase.AccountId = contract.AccountId;
            errorCase.ContactId = contract.CustomerSignedId;

            errorCase.Subject = 'Error at Lumenaza Sync for Contract';
            errorCase.Description  = 'Error: ' + error + '\n\n';
            errorCase.Description += errorDescription;

            // Set Subcategory__c
            // E01, Falscher Kunden/Firmenname
            // E02, Falsche Liefer-/Rechnungsadresse
            // E03, Falsche Zählernummer
            // E04, Falscher Altlieferant
            // E05, Falsches Netzgebiet
            // E06, Falscher Wechselgrund
            // E07, Falsches Lieferdatum
            // E08, Falsche Kontodaten
            // E09, Unplausibler Jahresverbrauch
            // E10, Unplausible Dateninhalte
            // E11, Lieferstelle nicht bekannt
            // E12, Fehler in Zähler-Kunden-Zuordnung
            // E13, Sonstiges

            if (error.containsIgnoreCase('company_name')) {
                errorCase.Subcategory__c = 'E01, Falscher Kunden/Firmenname';
            }
            else if (error.containsIgnoreCase('Zipcode not found in database')) {
                errorCase.Subcategory__c = 'E02, Falsche Liefer-/Rechnungsadresse';
            }
            else if (error.containsIgnoreCase('previous provider not set') || error.containsIgnoreCase('market partner ID not found')) {
                errorCase.Subcategory__c = 'E04, Falscher Altlieferant';
            }
            else if (error.containsIgnoreCase('delivery start has to be two weeks in future')) {
                errorCase.Subcategory__c = 'E07, Falsches Lieferdatum';
            }
            else if (error.containsIgnoreCase('bank_data_first_name') || error.containsIgnoreCase('bank_data_iban')) {
                errorCase.Subcategory__c = 'E08, Falsche Kontodaten';
            }
            else if (error.containsIgnoreCase('wrong date format')
                || error.containsIgnoreCase('not unique')
                || error.containsIgnoreCase('this field is required if tariff equals to sonnenflat')
                ) {
                errorCase.Subcategory__c = 'E10, Unplausible Dateninhalte';
            }

            insert errorCase;
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

    public Contract getContract() {
        return this.contract;
    }

    public override Boolean needsUpdate() {

        String debugHere = DEBUG_HEADER + '.needsUpdate(): ';

        Set<String> lsetValidUpdateStatus = new Set<String>{
            CONTRACT_STATUS_LUMENAZA_SYNC,
            CONTRACT_STATUS_AFTER_SYNC,
            CONTRACT_STATUS_REVOKE
        };

        Boolean needsUpdate = false;

        // Updates are currently not possible!
        // (See https://interaktiv.jira.com/browse/SOBCRM-667)
        // if (this.lumenazaCustomerId != null) {
        //     System.debug('LumenazaContract - needsUpdate(): Updates are currently NOT allowed due to changes at the API v3 (see SOBCRM-667)');
        //     return false;
        // }

        if (this.isLocked('upsert')) {
            System.debug(debugHere + 'Contract is already registered for an update: skip!');
            return false;
        }
        if (this.contract.LumenazaSkipApiCall__c == true) {
            System.debug(debugHere + 'LumenazaSkipApiCall__c is active: no update');
            return false;
        }
        if (!lsetValidUpdateStatus.contains(this.contract.Status)) {
            System.debug(debugHere + 'Contract ' + this.contract.Id + ' status "' + this.contract.Status + '" is not any of ' + String.join(new List<String>(lsetValidUpdateStatus), ', ') + ': no update');
            return false;
        }

        // If this contract is created due to a change of a
        // previous contract immediately return true
        if (this.isContractChange()) {
            System.debug(debugHere + 'Contract change should happen - force update');
            return true;
        }

        // If status is CONTRACT_STATUS_LUMENAZA_SYNC or CONTRACT_STATUS_AFTER_SYNC
        if (this.contract.Status == CONTRACT_STATUS_LUMENAZA_SYNC || this.contract.Status == CONTRACT_STATUS_AFTER_SYNC) {

            // Always fore a sync if upsertMode is "insertForExistingCustomer"
            if (this.getUpsertMode() == 'insertForExistingCustomer') {
                System.debug(debugHere + 'UpsertMode is  ' + this.getUpsertMode() + ', force creation at Lumenaza');
                return true;
            }

            // If contract has no Lumenaza Customer ID and no Lumenaza Contract ID then
            // update will be FORCED AS INSERT!
            // (API checks on existing ID to distinguish between INSERT and UPDATE)
            if (this.getLumenazaContractId() == null && this.getLumenazaCustomerId() == null) {
                System.debug(debugHere + 'Contract ' + this.contract.Id + ' is ' + CONTRACT_STATUS_LUMENAZA_SYNC + ' and has no Lumenaza Customer and Contract ID, force creation at Lumenaza!');
                return true;
            }
        }

        // Only at contract UPDATES!
        if (this.contractBefore != null) {

            // No update if status is still revoked
            if (this.contractBefore.Status == CONTRACT_STATUS_REVOKE && this.contract.Status == CONTRACT_STATUS_REVOKE) {
                System.debug(debugHere + 'Contract ' + this.contract.Id + ' status is "' + CONTRACT_STATUS_REVOKE + '" and has not changed: no update');
                return false;
            }

            // CONTRACT_STATUS_AFTER_SYNC -> CONTRACT_STATUS_REVOKE
            if (this.contractBefore.Status == CONTRACT_STATUS_AFTER_SYNC && this.contract.Status == CONTRACT_STATUS_REVOKE) {

                System.debug(debugHere + 'Contract ' + this.contract.Id + ' should be revoked');

                if (this.lumenazaContractId == null) {
                    System.debug(debugHere + 'Missing Lumenaza Contract ID: no update');
                    return false;
                }
                if (this.lumenazaCustomerId == null) {
                    System.debug(debugHere + 'Missing Lumenaza Customer ID: no update');
                    return false;
                }

                return true;
            }

            System.debug(debugHere + 'Status was "' + this.contractBefore.Status + '" before and now is "' + this.contract.Status + '", check all relevant fields for update');

            System.debug(debugHere + 'Get old values by creating a fake LumenazaContract object');
            LumenazaContract lumenazaContractOld = new LumenazaContract(this.contractBefore);

            Map<String,Object> mapOld = lumenazaContractOld.getLumenazaFields();
            Map<String,Object> mapNew = this.getLumenazaFields();

            // Clear update fields
            this.updateFields = new Map<String,Map<String,String>>();

            for (String fieldName : mapNew.keySet()) {

                String valueNew = String.valueOf(mapNew.get(fieldName));
                String valueOld = String.valueOf(mapOld.get(fieldName));

                System.debug(debugHere + 'Compare "' + fieldName + '" before "' + valueOld + '", now "' + valueNew + '"');

                if (valueNew != valueOld) {

                    this.updateFields.put(fieldName, new Map<String,String>{
                        'old' => valueOld,
                        'new' => valueNew
                    });

                    System.debug(debugHere + 'Field "' + fieldName + '" -> old "' + valueOld + '"" <> new "' + valueNew + '"');
                    needsUpdate = true;
                }
            }
        }

        System.debug(debugHere + 'Needs update: ' + (needsUpdate ? 'yes' : 'no'));
        return needsUpdate;
    }

    /**
     * Validates the object
     */
    public override Boolean validate() {

        String sDebugHere = DEBUG_HEADER + '.validate() - ';

        // This returns only the fields which can be used for
        // the given upsertMode!
        Map<String,Object> mapLumenazaFields = this.getLumenazaFields();

        while (TRUE) {

            if (this.specialAction == SPECIAL_ACTION_REVOKE) {
                if (this.contract.Status != CONTRACT_STATUS_REVOKE) {
                    this.setError('Status must be "' + CONTRACT_STATUS_REVOKE + '" for Revokation of Contract');
                    break;
                }
                if (this.lumenazaContractId == null) {
                    this.setError('Contract has no Lumenaza Contract ID');
                    break;
                }
                if (this.lumenazaCustomerId == null) {
                    this.setError('Contract has no Lumenaza Customer ID');
                    break;
                }
                break;
            }
            // Since 2018-04-04 (SOBCRM-1164)
            else if (this.specialAction == SPECIAL_ACTION_CONTRACT_CHANGE) {

                if (this.contract.LumenazaPreviousContractId__c == null) {
                    this.setError('For a contract change a previous contract with a Lumenaza Contract ID has to be set');
                    break;
                }

                if (this.contract.LumenazaContractId__c != null) {
                    this.setError('This contract already has a Lumenaza Contract ID');
                    break;
                }

                if (this.contract.LumenazaCustomerId__c != null && this.contract.LumenazaCustomerId__c != this.contract.LumenazaPreviousCustomerId__c) {
                    this.setError('Lumenaza Customer ID must match the one ID of the previous contract');
                    break;
                }
            }
            else if (this.getUpsertMode() == UPSERTMODE_NEW_FOR_EXISTING_CUSTOMER) {

                if (this.getLumenazaContractId() != null) {
                    this.setError('Cannot insert contract for existing customer with existing Lumenaza Contract ID');
                    break;
                }

                if (this.getLumenazaCustomerIdOfExistingContract() == null) {
                    this.setError('Missing Lumenaza Customer ID of existing contract');
                    break;
                }

                if (this.getLumenazaCustomerId() != null && this.getLumenazaCustomerId() != this.getLumenazaCustomerIdOfExistingContract()) {
                    this.setError('Cannot insert contract for existing customer without existing Lumenaza Contract ID');
                    break;
                }
            }

            System.debug(sDebugHere + 'Fields to validate: ' + mapLumenazaFields);

            // Check if any changes which were done in the past failed and are not resolved
            Decimal dFailedChanges = this.contract.ChangesFailedCount__c;

            if (dFailedChanges > 0) {
                this.setError('Contract has ' + dFailedChanges + ' unresolved failed change' + (dFailedChanges > 1 ? 's' : '') + '. Please resolve them before making any new changes!');
                break;
            }

            for (String fieldName : mapLumenazaFields.keySet()) {

                String value = (mapLumenazaFields.get(fieldName) == null) ? '' : String.valueOf(mapLumenazaFields.get(fieldName)).trim();

                Boolean bIsBusiness = mapLumenazaFields.get('is_business') == null || Boolean.valueOf(mapLumenazaFields.get('is_business'));
                Boolean bIsCompany  = mapLumenazaFields.get('is_company') == null || Boolean.valueOf(mapLumenazaFields.get('is_company'));

                if (
                    (
                            fieldName == 'is_business' ||
                            fieldName == 'salutation' ||
                            fieldName == 'first_name' ||
                            fieldName == 'last_name' ||
                            fieldName == 'email' ||
                            fieldName == 'deliv_address_street' ||
                            fieldName == 'deliv_address_house_no' ||
                            fieldName == 'deliv_address_zipcode' ||
                            fieldName == 'deliv_address_city' ||
                            fieldName == 'bill_address_street' ||
                            fieldName == 'bill_address_house_no' ||
                            fieldName == 'bill_address_zipcode' ||
                            fieldName == 'bill_address_city' ||
                            fieldName == 'subscription_reason' ||
                            fieldName == 'meter_id' ||
                            fieldName == 'annual_consumption' ||
                            fieldName == 'bank_data_first_name' ||
                            fieldName == 'bank_data_last_name' ||
                            fieldName == 'bank_data_iban' ||
                            fieldName == 'sepa_date' ||
                            fieldName == 'meter_reading_value' ||
                            fieldName == 'meter_reading_date' ||
                            ((bIsBusiness || bIsCompany) && fieldName == 'company_name')
                    ) && value.length() == 0) {
                    this.setError('Field "' + fieldName + '" is mandatory for Lumenaza API');
                    break;
                }

                if (fieldName == 'previous_provider' && mapLumenazaFields.get('subscription_reason') == 'E03' && value.length() == 0) {
                    this.setError('Field "' + fieldName + '" must be set if subscription_reason ist E03');
                    break;
                }
                if (fieldName == 'salutation' && value != 'Herr' && value != 'Frau') {
                    this.setError('Field "' + fieldName + '" must be "Herr" or "Frau"');
                    break;
                }
                if (fieldName == 'tariff_type' && !validTariffTypes.contains(value)) {
                    this.setError('Field "' + fieldName + '" must be one of the following: ' + String.join(new List<String>(validTariffTypes), ', '));
                    break;
                }
                if (fieldName == 'titel' && value != '' && value != 'Dr.' && value != 'Prof.' && value != 'Prof. Dr.') {
                    this.setError('Field "' + fieldName + '" must be "Dr.", "Prof." or "Prof. Dr."');
                    break;
                }
                if (fieldName == 'email' && Pattern.compile('[^@\\s]+@[^@\\s]+\\.[a-zA-Z]{2,}').matcher(value).matches() == false) {
                    this.setError('Invalid email address');
                    break;
                }
            }

            // Validation according selected tariff_type and upsertMode (2017-03-23, SOBCRM-852)
            Set<String> lsetTariffTypes = new Set<String>{
                'household', // deprecated
                'sonnenFlat',
                'sonnenCity',
                'sonnenStrom', // since 2017-06-14, SOBCRM-984
                // since 2018-10-10, SOBCRM-1262
                'sonnen_pilot',
                'sonnen_blanko',
                'sonnenPackage' // replaces "household"
            };

            Set<String> lsetValidFields = this.validFieldsPerUpsertMode.get(this.getUpsertMode());

            String sTariffType = String.valueOf(mapLumenazaFields.get('tariff_type'));

            if (lsetTariffTypes.contains(sTariffType)) {

                if (lsetValidFields.contains('saas_customer_id') && (mapLumenazaFields.get('saas_customer_id') == null || String.valueOf(mapLumenazaFields.get('saas_customer_id')) == '')) {
                    this.setError('Field "saas_customer_id" at type "' + sTariffType + '" is mandatory');
                    break;
                }
                if (lsetValidFields.contains('sepa_reference') && (mapLumenazaFields.get('sepa_reference') == null || String.valueOf(mapLumenazaFields.get('sepa_reference')) == '')) {
                    this.setError('Field "sepa_reference" at type "' + sTariffType + '" is mandatory');
                    break;
                }
                if ((sTariffType == 'sonnenFlat' || sTariffType == 'sonnenCity')
                    && lsetValidFields.contains('free_amount')
                    && (mapLumenazaFields.get('free_amount') == null || Double.valueOf(mapLumenazaFields.get('free_amount')) <= 0)) {
                    this.setError('Field "free_amount" at type "' + sTariffType + '" is mandatory');
                    break;
                }
                if (sTariffType == 'sonnenFlat'
                    && lsetValidFields.contains('consumption_before_battery_installation')
                    && (mapLumenazaFields.get('consumption_before_battery_installation') == null || Double.valueOf(mapLumenazaFields.get('consumption_before_battery_installation')) <= 0)) {
                    this.setError('Field "consumption_before_battery_installation" at type "' + sTariffType + '" is mandatory');
                    break;
                }
            }

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
     * Alias for isAccountLumenazaCustomer()
     */
    public Boolean getIsAccountLumenazaCustomer() {
        return this.isAccountLumenazaCustomer();
    }

    /**
     * Alias for checkOnMultipleContractsByAccountIds(Set<Id> lsetAccountIds)
     */
    public static Map<Id,List<String>> checkOnMultipleContractsByAccountIds(Id idAccount) {
        return checkOnMultipleContractsByAccountIds(new Set<Id>{idAccount});
    }

    /**
     * Determine if Contract's Account already has a Contract at Lumenaza.
     * This makes a difference as the customer_no is then registered already and
     * creation of the a new Contract would fail with an "saas_customer_id not unique"
     * error.
     */
    public static Map<Id,List<String>> checkOnMultipleContractsByAccountIds(Set<Id> lsetAccountIds) {

        Map<Id,List<String>> mapAccountIdToLumenazaCustomerIds = new Map<Id,List<String>>();

        if (!lsetAccountIds.isEmpty()) {

            List<AggregateResult> oAggregateResults = new List<AggregateResult>([
                SELECT
                    AccountId,
                    LumenazaCustomerId__c,
                    COUNT(Id) countOfContracts
                FROM
                    Contract
                WHERE
                AccountId IN :lsetAccountIds AND
                LumenazaCustomerId__c != null
                GROUP BY
                        AccountId,
                        LumenazaCustomerId__c
            ]);

            // Sort LumenazaCustomerIds to AccountIds
            for (AggregateResult oAggregateResult : oAggregateResults) {

                Id idAccount = (Id)oAggregateResult.get('AccountId');
                String sLumenazaCustomerId = (String)oAggregateResult.get('LumenazaCustomerId__c');

                if (mapAccountIdToLumenazaCustomerIds.get(idAccount) == null) {
                    mapAccountIdToLumenazaCustomerIds.put(idAccount, new List<String>());
                }
                mapAccountIdToLumenazaCustomerIds.get(idAccount).add(sLumenazaCustomerId);
            }

            for (Id idAccount : lsetAccountIds) {
                if (mapAccountIdToLumenazaCustomerIds.get(idAccount) == null) {
                    mapAccountIdToLumenazaCustomerIds.put(idAccount, new List<String>());
                }
            }
        }

        return mapAccountIdToLumenazaCustomerIds;
    }

    /**
     * Returns if this Contract's account is already a
     * Lumenaza customer
     */
    public Boolean isAccountLumenazaCustomer() {

        String sDebugHere = DEBUG_HEADER + '.isAccountLumenazaCustomer() - ';

        // Should never be the case!
        if (this.contract.AccountId == null) {
            return FALSE;
        }

        if (this.isLumenazaCustomer == null) {

            Id idAccount = this.contract.AccountId;
            Map<Id,List<String>> mapAccountIdToLumenazaCustomerIds = checkOnMultipleContractsByAccountIds(idAccount);

            if (mapAccountIdToLumenazaCustomerIds.get(idAccount).size() > 1) {

                List<String> listLumenazaCustomerIds = mapAccountIdToLumenazaCustomerIds.get(idAccount);

                String sError = 'Contract\'s (' + this.contract.Id + ') Account (' + this.contract.AccountId + ') has Contracts with multiple Lumenaza Customer IDs (' + String.join(listLumenazaCustomerIds, ', ') + ')!';

                try {
                    Case oCase = this.prepareErrorCase();

                    oCase.Contract__c = this.contract.Id;
                    oCase.AccountId = this.contract.AccountId;
                    oCase.ContactId = this.contract.CustomerSignedId;

                    oCase.subject = 'Error at Lumenaza Sync for Contract';
                    oCase.description  = 'Error: ' + sError + '\n\n';
                    insert oCase;
                }
                catch (Exception e) {
                }

                throw new LumenazaContractException(sError);
            }

            this.isLumenazaCustomer = !mapAccountIdToLumenazaCustomerIds.get(idAccount).isEmpty();

            // Set customer ID
            if (this.isLumenazaCustomer) {
                this.lumenazaCustomerIdOfExistingContract = mapAccountIdToLumenazaCustomerIds.get(idAccount).get(0);
                System.debug(sDebugHere + 'Set lumenazaCustomerIdOfExistingContract to "' + this.lumenazaCustomerIdOfExistingContract + '"');
            }
        }

        return this.isLumenazaCustomer;
    }

    /**
     * Sets if the Contract's Customer is already a Lumenaza Customer
     */
    public void setIsAccountLumenazaCustomer(Boolean isAccountLumenazaCustomer, String lumenazaCustomerId) {
        System.debug(DEBUG_HEADER + '.setIsAccountLumenazaCustomer() - Contract\'s Account is already Lumenaza Customer: ' + (isAccountLumenazaCustomer ? 'YES (set lumenazaCustomerIdOfExistingContract to "' + lumenazaCustomerId + '")' : 'NO'));
        this.isLumenazaCustomer = isAccountLumenazaCustomer;
        this.lumenazaCustomerIdOfExistingContract = lumenazaCustomerId;
    }

    /**
     * Returns the Lumenaza Customer ID
     */
    public String getLumenazaCustomerId() {
        return (this.lumenazaCustomerId != null && this.lumenazaCustomerId.length() > 0) ? this.lumenazaCustomerId : null;
    }

    /**
     * Returns the Lumenaza Contract ID
     */
    public String getLumenazaContractId() {
        return (this.lumenazaContractId != null && this.lumenazaContractId.length() > 0) ? this.lumenazaContractId : null;
    }

    /**
     * Returns the Lumenaza Contract ID of the previous contract
     */
    public String getLumenazaPreviousContractId() {
        return this.contract.LumenazaPreviousContractId__c;
    }

    /**
     * Returns the Lumenaza Customer ID of the previous contract
     */
    public String getLumenazaPreviousCustomerId() {
        return this.contract.LumenazaPreviousCustomerId__c;
    }

    /**
     * Returns the Lumenaza Contract ID of an existing Customer at Lumenaza
     *
     * This is the case if the Customer already has made a previous Contract
     */
    public String getLumenazaCustomerIdOfExistingContract() {
        this.isAccountLumenazaCustomer(); // to init an existing Customer ID at Lumenaza
        return (this.lumenazaCustomerIdOfExistingContract != null && this.lumenazaCustomerIdOfExistingContract.length() > 0) ? this.lumenazaCustomerIdOfExistingContract : null;
    }

    /**
     * Returns the special action (e.g. revoke)
     */
    public String getSpecialAction() {
        return this.specialAction;
    }

    /**
     * Returns if a contract change is happening
     *
     * @since 2018-04-04
     */
    public Boolean isContractChange() {
        // - Contract's status is CONTRACT_STATUS_LUMENAZA_SYNC
        // - SubscriptionReason is SUBSCRIPTION_REASON_CHANGE (This reason is NOT evaluated at Lumenaza, it's just to trigger a change)
        // - Contract has no Lumenaza Contract ID yet
        return (this.contract.Status == CONTRACT_STATUS_LUMENAZA_SYNC && this.contract.SubscriptionReason__c == SUBSCRIPTION_REASON_CHANGE);
    }

    public class LumenazaContractException extends Exception {}
}