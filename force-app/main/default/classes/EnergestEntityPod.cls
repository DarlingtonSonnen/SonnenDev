/**
 * EnergestEntityPod
 *
 * Represents an Energest POD (Point of Delivery) and wraps it for processing
 *
 * v1.0.0   2019-03-04  Marko Schmalenbach          Initial
 * v1.1.0   2019-03-08  Marko Schmalenbach          Added error methods
 * v1.2.0   2019-06-04  Marko Schmalenbach          Skip call for bypassing ContractTriggerHandler if already set
 * v1.3.0   2019-08-19  Marko Schmalenbach          Added use of Duplicate Rules to match existing Account (Datacloud.FindDuplicates.findDuplicates)
 *
 * @see https://interaktiv.jira.com/browse/SOBCRM-1321
 */
public without sharing class EnergestEntityPod {

    private static final String DEBUG_HEADER = 'EnergestEntityPod.';

    //public static final Boolean CAN_CREATE_BUSINESS_ACCOUNTS = false;
    public static final String CONTRACT_RECORD_TYPE_DEVELOPER_NAME = 'EnergiaIt';
    public static final String MULTIPLE_DUPLICATES_CASE_SUBJECT = 'Duplicates found at Energest POD handling';
    public static final String FUZZY_MATCH_CASE_SUBJECT = 'Fuzzy match taken at Energest POD handling';

    // Allow updating of found duplicates
    public static final Boolean ALLOW_DUPLICATE_UPDATE = true;

    public EnergestPod sourcePod;
    private String jsonSource;

    public EnergestAccount energestAccount { get; private set; }
    public EnergestContract energestContract { get; private set; }
    public EnergestBankData energestBankData { get; private set; }

    public EnergestPod__c oEnergestPod { get; private set; }

    // For ALL handled PODs!
    public static Map<Id, Map<Id, Boolean>> mapDuplicateMatchesByPodId = new Map<Id, Map<Id, Boolean>>();

    // Cases created upon multiple duplicates
    public static Map<Id, Case> mapDuplicateCaseByPodIds = new Map<Id, Case>();

    // Cases created upon relation of fuzzy found exsting SObjects
    // related to PODs
    public static List<Case> listFuzzyCases = new List<Case>();

    private String error;

    /**
     * Construct by JSON
     *
     * @param jsonString
     */
    public EnergestEntityPod(String jsonString) {
        this.jsonSource = jsonString;
        this.sourcePod = (EnergestPod)JSON.deserialize(jsonString, EnergestPod.class);
        this.init();
    }

    /**
     * Construct by EnergestPod__c
     *
     * @param oEnergestPod
     */
    public EnergestEntityPod(EnergestPod__c oEnergestPod) {
        this.oEnergestPod = oEnergestPod;
        this.jsonSource = oEnergestPod.DataAsJson__c;
        this.sourcePod = (EnergestPod)JSON.deserialize(oEnergestPod.DataAsJson__c, EnergestPod.class);
        this.init();
    }

    public static void addDuplicateMatchByPodId(Id podId, Id SObjectId, Boolean isFuzzy) {

        if (!mapDuplicateMatchesByPodId.containsKey(podId)) {
            mapDuplicateMatchesByPodId.put(podId, new Map<Id, Boolean>());
        }

        mapDuplicateMatchesByPodId.get(podId).put(SObjectId, isFuzzy);
    }

    /**
     * Init
     */
    private void init() {

        // Normalize incoming values
        this.normalizeSourcePod();

        // Create SObjects
        this.initSObjects();
    }

    /**
     * Set an error
     *
     * @param error
     */
    public void setError(String error) {

        this.error = error;

        if (this.oEnergestPod != null) {
            this.oEnergestPod.Error__c = (error.length() > 255) ? error.substring(0, 255) : error;
        }
    }

    /**
     * Returns if an error was set
     *
     * @return
     */
    public Boolean hasError() {
        return (this.error != null && this.error.length() > 0);
    }

    /**
     * Get all SObject fields related to EnergestPod__c
     *
     * @return
     */
    public Map<String, Set<String>> getSObjectFieldsForSoql() {

        Map<String, Set<String>> mapFieldsBySObject = new Map<String, Set<String>>();

        mergeFieldMap(mapFieldsBySObject, this.energestAccount.getSObjectFields(true));
        mergeFieldMap(mapFieldsBySObject, this.energestContract.getSObjectFields(true));
        mergeFieldMap(mapFieldsBySObject, this.energestBankData.getSObjectFields(true));

        return mapFieldsBySObject;
    }

    /**
     * Merge a field map
     *
     * @param mapFieldsBySObject
     * @param mapFieldsToMerge
     */
    public static void mergeFieldMap(Map<String, Set<String>> mapFieldsBySObject, Map<String, Set<String>> mapFieldsToMerge) {

        for (String sSObjectName : mapFieldsToMerge.keySet()) {

            if (!mapFieldsBySObject.containsKey(sSObjectName)) {
                mapFieldsBySObject.put(sSObjectName, new Set<String>());
            }

            mapFieldsBySObject.get(sSObjectName).addAll(mapFieldsToMerge.get(sSObjectName));
        }
    }

    /**
     * Initialize all SObjects
     *
     * @return
     */
    public void initSObjects() {

        this.energestAccount  = new EnergestAccount(this);
        this.energestContract = new EnergestContract(this);
        this.energestBankData = new EnergestBankData(this);
    }

    /**
     * Get a normalized version of this object
     *
     * This basically strips whitespaces from string values
     * and sets them to null if they have no length
     *
     * @param jsonString
     *
     * @return
     */
    private void normalizeSourcePod() {

        Map<String, Object> mapValues = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(this.sourcePod));

        // Normalize values
        for (String sPropertyName : mapValues.keySet()) {

            Object oValue = mapValues.get(sPropertyName);

            if (oValue instanceof String) {

                String sValue = ((String)oValue).trim();

                if (sValue.length() == 0) {
                    sValue = null;
                }

                mapValues.put(sPropertyName, sValue);
            }
        }

        String sValuesAsJson = JSON.serialize(mapValues);
        this.sourcePod = (EnergestPod)JSON.deserialize(sValuesAsJson, EnergestPod.class);
    }

    /**
     * Returns changes of related SObjects if there are any
     *
     * @return
     */
    public Map<String, EnergestSObjectWrapper> getChanges() {

        final String DEBUG_HERE = DEBUG_HEADER + 'getChanges() - ';

        Map<String, EnergestSObjectWrapper> mapChangedSObjects = new Map<String, EnergestSObjectWrapper>();

        if (this.hasError()) {
            return mapChangedSObjects;
        }

        // Order matters here!
        if (this.energestAccount.hasChange()) {
            mapChangedSObjects.put(this.energestAccount.ENERGEST_POD_LOOKUP_FIELD, this.energestAccount);
            System.debug(DEBUG_HERE + 'Account "' + this.energestAccount.oAccount.LastName + '" has changes');
        }
        if (this.energestBankData.hasChange()) {
            mapChangedSObjects.put(this.energestBankData.ENERGEST_POD_LOOKUP_FIELD, this.energestBankData);
            System.debug(DEBUG_HERE + 'Bank Data "' + this.energestBankData.oBankData.IBAN__c + '" has changes');
        }
        if (this.energestContract.hasChange()) {
            mapChangedSObjects.put(this.energestContract.ENERGEST_POD_LOOKUP_FIELD, this.energestContract);
            System.debug(DEBUG_HERE + 'Contract "' + this.energestContract.oContract.EnergestInternalId__c + '" has changes');
        }

        return mapChangedSObjects;
    }

    /**
     *
     *
     * @return
     */
    public List<DuplicateCheckPresentation> getDuplicateCheckPresentations() {

        List<DuplicateCheckPresentation> listCheckPresentations = new List<EnergestEntityPod.DuplicateCheckPresentation>();

        if (this.energestAccount.getDuplicateCheckPresentation() != null) {
            listCheckPresentations.add(this.energestAccount.getDuplicateCheckPresentation());
        }

        if (this.energestContract.getDuplicateCheckPresentation() != null) {
            listCheckPresentations.add(this.energestContract.getDuplicateCheckPresentation());
        }

        if (this.energestBankData.getDuplicateCheckPresentation() != null) {
            listCheckPresentations.add(this.energestBankData.getDuplicateCheckPresentation());
        }

        return listCheckPresentations;
    }

    /**
     * Returns the source POD as JSON
     *
     * @return
     */
    public String getSourcePodAsJson() {
        return JSON.serializePretty(JSON.deserializeUntyped(this.jsonSource));
    }

    public class DuplicateCheckPresentation {

        private final String DEBUG_HEADER = 'DuplicateCheckPresentation.';

        public String lookupField;
        public String externalField;
        public String value;
        public Id energestPodId;
        public String sobjectName;
        public Boolean useDuplicateRule = false;
        public SObject duplicateCheckSObject;

        public Map<Id, DuplicateCheckPresentation> mapPresentationByEnergestPodId = new Map<Id, DuplicateCheckPresentation>();
        public Map<String, Id> mapSObjectIdByExternalId = new Map<String, Id>();

        /**
         *
         */
        public void startCheck() {

            final String DEBUG_HERE = DEBUG_HEADER + 'startCheck() - ';

            if (this.mapPresentationByEnergestPodId.isEmpty()) {
                return;
            }

            if (this.useDuplicateRule) {

                System.debug(DEBUG_HERE + 'Use duplicate rules to find duplicates on SObject "' + this.sobjectName + '"');

                List<SObject> listSObjectsToCheck = new List<SObject>();
                Map<String, Id> mapPodIdByExternalId = new Map<String, Id>();

                for (DuplicateCheckPresentation oDuplicateCheckPresentation : this.mapPresentationByEnergestPodId.values()) {

                    System.assertNotEquals(null, oDuplicateCheckPresentation.duplicateCheckSObject, 'Expected duplicateCheckSObject to be set if useDuplicateRule is active');

                    listSObjectsToCheck.add(oDuplicateCheckPresentation.duplicateCheckSObject);

                    mapPodIdByExternalId.put(
                        String.valueOf(oDuplicateCheckPresentation.duplicateCheckSObject.get(this.externalField)),
                        oDuplicateCheckPresentation.energestPodId
                    );
                }

                List<Datacloud.FindDuplicatesResult> listResult = Datacloud.FindDuplicates.findDuplicates(listSObjectsToCheck);

                if (!listResult.isEmpty()) {

                    Integer i = 0;

                    for (Datacloud.FindDuplicatesResult oResult : listResult) {

                        // This is the SObject to find Duplicate(s) for:
                        SObject oSObjectToSearchFor = listSObjectsToCheck.get(i);
                        String sObjectType = String.valueOf(oSObjectToSearchFor.getSObjectType());

                        System.debug(DEBUG_HERE + 'SObject to check: ' + oSObjectToSearchFor);
                        i++;

                        if (oResult.isSuccess()) {

                            List<Datacloud.DuplicateResult> listDuplicateResults = oResult.getDuplicateResults();

                            if (!listDuplicateResults.isEmpty()) {

                                List<Datacloud.MatchResult> listMatchResults = listDuplicateResults.get(0).getMatchResults();

                                if (!listMatchResults.isEmpty()) {

                                    List<Datacloud.MatchRecord> listMatchRecords = listMatchResults.get(0).getMatchRecords();

                                    if (!listMatchRecords.isEmpty()) {

                                        Map<String, Datacloud.MatchRecord> mapMatchesByMatchString = this.getOrderedMatchRecords(listMatchRecords);

                                        // Take first match
                                        Boolean bMatchTaken = false;

                                        String sExternalId = String.valueOf(oSObjectToSearchFor.get(this.externalField));
                                        Id idEnergestPod = mapPodIdByExternalId.get(sExternalId);

                                        SObject oExistingSObject;
                                        String sExistingSObjectId;
                                        List<SObject> listExistingDuplicates = new List<SObject>();

                                        for (String sUniqueConfidenceString : mapMatchesByMatchString.keySet()) {

                                            Datacloud.MatchRecord oMatchRecord = mapMatchesByMatchString.get(sUniqueConfidenceString);

                                            oExistingSObject = oMatchRecord.getRecord();
                                            sExistingSObjectId = String.valueOf(oExistingSObject.get('Id'));

                                            // Check confidence
                                            // Example: 1-50-04-01
                                            // 1 = Match on External ID (best)
                                            // 50 = Salesforce confidence in percent
                                            // 04 = fields that matched
                                            // 01 = only for internal uniqueness
                                            List<String> listParts = sUniqueConfidenceString.split('-');

                                            // Remark this match as fuzzy match
                                            Boolean bIsFuzzy = (listParts.get(0) != '1' && listParts.get(1) != '100');

                                            if (!bMatchTaken) {

                                                bMatchTaken = true;

                                                System.debug(
                                                    DEBUG_HERE + 'Take existing duplicate ' + sObjectType + ' for field ' +
                                                        this.externalField + ' "' + sExternalId + '" ' +
                                                        'with confidence string "' + sUniqueConfidenceString + '" (' + (bIsFuzzy ? 'fuzzy' : 'exact') + '): ' +
                                                        JSON.serializePretty(oExistingSObject)
                                                );
                                                this.mapSObjectIdByExternalId.put(sExternalId, sExistingSObjectId);


                                                if (bIsFuzzy) {

                                                    System.debug(DEBUG_HERE + 'Account ' + oExistingSObject);
                                                    Case oCase = new Case(
                                                        Status         = 'Open',
                                                        Priority       = 'Low',
                                                        Type           = 'Problem',
                                                        Subject        = EnergestEntityPod.FUZZY_MATCH_CASE_SUBJECT,
                                                        Description    = 'Related existing ' + sObjectType + ' to POD ' + idEnergestPod +
                                                            'to prevent duplicates. But this ' + sObjectType + ' is no 100% match. ' +
                                                            'Furthermore it was left untouched and was not updated with data from Enersis.\n\n' +
                                                            'This data came from Enersis:\n\n' +
                                                            JSON.serializePretty(oSObjectToSearchFor) + '\n\n' +
                                                            'This was the existing fuzzy match:\n\n' +
                                                            JSON.serializePretty(oExistingSObject) + '\n\n' +
                                                            'Please check the match and update it accordingly if required.',
                                                        Origin         = 'IT - website',
                                                        EnergestPod__c = idEnergestPod
                                                    );

                                                    EnergestEntityPod.listFuzzyCases.add(oCase);
                                                }
                                            }

                                            EnergestEntityPod.addDuplicateMatchByPodId(idEnergestPod, sExistingSObjectId, bIsFuzzy);
                                            listExistingDuplicates.add(oExistingSObject);
                                        }

                                        // Create Case if multiple SObjects would have matched
                                        if (listExistingDuplicates.size() > 1) {

                                            System.debug(DEBUG_HERE + 'Found ' + listExistingDuplicates.size() + ' duplicates - create a Case: ' + JSON.serializePretty(listMatchRecords));

                                            Case oCase = new Case(
                                                Status         = 'Open',
                                                Priority       = 'Low',
                                                Type           = 'Problem',
                                                Subject        = EnergestEntityPod.MULTIPLE_DUPLICATES_CASE_SUBJECT,
                                                Description    = '',
                                                Origin         = 'IT - website',
                                                EnergestPod__c = idEnergestPod
                                            );

                                            String sDescription = 'Multiple duplicates found at searching for an existing "' + this.sobjectName + '" for POD ' + idEnergestPod + ':\n';
                                            sDescription += JSON.serializePretty(listExistingDuplicates);

                                            if (mapDuplicateCaseByPodIds.containsKey(idEnergestPod)) {
                                                oCase = mapDuplicateCaseByPodIds.get(idEnergestPod);
                                            }
                                            else {
                                                mapDuplicateCaseByPodIds.put(idEnergestPod, oCase);
                                            }

                                            oCase.Description += '\n\n' + sDescription;
                                            oCase.Description = oCase.Description.trim();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else {

                Set<String> lsetExternalIds = new Set<String>();

                for (DuplicateCheckPresentation oDuplicateCheckPresentation : this.mapPresentationByEnergestPodId.values()) {
                    lsetExternalIds.add(oDuplicateCheckPresentation.value);
                }

                String sSoql = 'SELECT Id, ' + this.externalField +  ' FROM ' + this.sobjectName + ' WHERE ' + this.externalField + ' IN :lsetExternalIds';
                List<SObject> listSObjects = Database.query(sSoql);

                System.debug(DEBUG_HERE + 'SOQL: ' + sSoql);

                for (SObject oSObject : listSObjects) {
                    this.mapSObjectIdByExternalId.put(
                        String.valueOf(oSObject.get(this.externalField)),
                        String.valueOf(oSObject.get('Id'))
                    );
                }

                System.debug(DEBUG_HERE + 'Found external ID <-> SObject matches for "' + this.sobjectName + '": ' + this.mapSObjectIdByExternalId);
            }
        }

        public void addDuplicateCheckPresentationForDuplicateCheck(DuplicateCheckPresentation duplicateCheckPresentation) {
            this.mapPresentationByEnergestPodId.put(duplicateCheckPresentation.energestPodId, duplicateCheckPresentation);
        }

        public Id getExistingSObjectIdByEnergestPodId(Id energestPodId) {

            if (!mapPresentationByEnergestPodId.containsKey(energestPodId)) {
                return null;
            }

            String externalId = mapPresentationByEnergestPodId.get(energestPodId).value;

            return mapSObjectIdByExternalId.get(externalId);
        }

        /**
         * Get ordered Datacloud.MatchRecords ordered by best match ASC
         *
         * @param listToOrder
         *
         * @return
         */
        public Map<String, Datacloud.MatchRecord> getOrderedMatchRecords(List<Datacloud.MatchRecord> listToOrder) {

            final String DEBUG_HERE = DEBUG_HEADER + 'getOrderedMatchRecords() - ';

            Map<String, List<Datacloud.MatchRecord>> mapMatchRecordsByConfidence = new Map<String, List<Datacloud.MatchRecord>>();
            List<Datacloud.MatchRecord> listOrdered = new List<Datacloud.MatchRecord>();
            Set<String> lsetConfidenStrings = new Set<String>();

            for (Datacloud.MatchRecord oMatchRecord : listToOrder) {

                String sMatchConfidence = String.valueOf(oMatchRecord.getMatchConfidence().round()).leftPad(3, '0');
                Integer iSameValue = 0;
                Integer iCountFields = 0;
                Boolean bMatchOnExternalField = false;

                if (!oMatchRecord.getFieldDiffs().isEmpty()) {
                    for (Datacloud.FieldDiff oFieldDiff : oMatchRecord.getFieldDiffs()) {

                        iCountFields++;

                        if (oFieldDiff.getDifference() == 'Same') {

                            iSameValue++;

                            if (oFieldDiff.getName() == this.externalField) {
                                bMatchOnExternalField = true;
                            }
                        }
                    }
                }

                // If only external does not match but all the others
                // then push confidence to 100%
                if (!bMatchOnExternalField && (iCountFields-1) == iSameValue) {
                    sMatchConfidence = '100';
                }

                String sConfidenceString =
                    (bMatchOnExternalField ? '1' : '0') + '-' +
                    sMatchConfidence + '-' +
                    String.valueOf(iSameValue).leftPad(2, '0');

                lsetConfidenStrings.add(sConfidenceString);

                if (!mapMatchRecordsByConfidence.containsKey(sConfidenceString)) {
                    mapMatchRecordsByConfidence.put(sConfidenceString, new List<Datacloud.MatchRecord>());
                }

                mapMatchRecordsByConfidence.get(sConfidenceString).add(oMatchRecord);
            }

            //System.debug('mapMatchRecordsByConfidence: ' + JSON.serializePretty(mapMatchRecordsByConfidence));

            List<String> listConfidentStrings = new List<String>(lsetConfidenStrings);
            listConfidentStrings.sort();

            Map<String, Datacloud.MatchRecord> mapMatchRecordsByConfidenceFinal = new Map<String, Datacloud.MatchRecord>();

            // Sort DESC
            Integer iMatches = 1;
            for (Integer i = (listConfidentStrings.size()-1); i>=0; i--) {

                String sConfidenceString = listConfidentStrings.get(i);
                List<Datacloud.MatchRecord> listMatchRecordsForConfidenceString = mapMatchRecordsByConfidence.get(sConfidenceString);

                System.debug(DEBUG_HERE + 'Confidence String "' + sConfidenceString + '": ' + JSON.serializePretty(listMatchRecordsForConfidenceString));

                for (Datacloud.MatchRecord oMatchRecord : listMatchRecordsForConfidenceString) {
                    String sUniqueConfidenceString = sConfidenceString + '-' + String.valueOf(iMatches).leftPad(2, '0');
                    mapMatchRecordsByConfidenceFinal.put(sUniqueConfidenceString, oMatchRecord);
                    iMatches++;
                }
            }

            return mapMatchRecordsByConfidenceFinal;
        }

    }

    //==================================================================================================================
    // POD
    //==================================================================================================================
    /**
     * Source POD from Energest
     */
    public class EnergestPod {

        public Long ContractInternalId { get; private set; }
        public Long PoDInternalId { get; private set; }
        public String PoDNumber { get; private set; }
        public Integer Type { get; private set; }
        public String SupplyAddress { get; private set; }
        public String SupplyPostalCode { get; private set; }
        public String SupplyHouseNumber { get; private set; }
        public String SupplyMunicipality { get; private set; }
        public String SupplyMunicipalityICode { get; private set; }
        public String SupplyDistrict { get; private set; }
        public String SupplyDistrictCode { get; private set; }
        public String SupplyPlace { get; private set; }
        public String SupplyCountry { get; private set; }
        public String LegalAddress { get; private set; }
        public String LegalPostalCode { get; private set; }
        public String LegalHouseNumber { get; private set; }
        public String LegalMunicipality { get; private set; }
        public String LegalMunicipalityICode { get; private set; }
        public String LegalDistrict { get; private set; }
        public String LegalDistrictCode { get; private set; }
        public String LegalPlace { get; private set; }
        public String LegalCountry { get; private set; }
        public String CustomerERPCode { get; private set; }
        public Long CustomerInternalId { get; private set; }
        public String CustomerName { get; private set; }
        public String CustomerSurname { get; private set; }
        public String CustomerCompany { get; private set; }
        public String CustomerVATId { get; private set; }
        public String CustomerFiscalCode { get; private set; }
        public String CustomerEmail { get; private set; }
        public String CustomerPhoneNumber { get; private set; }
        public String CustomerMobileNumber { get; set; }
        public String PreviousSupplier { get; private set; }
        public String AttorneyName { get; private set; }
        public String AttorneySurname { get; private set; }
        public String AttorneyEmail { get; private set; }
        public String AttorneyPhoneNumber { get; private set; }
        public String AttorneyMobileNumber { get; private set; }
        public String AttorneyUsername { get; private set; }
        public String PaymentTerms { get; private set; }
        public String PaymentSDDMandateCode { get; private set; }
        public String PaymentIBAN { get; private set; }
        public Decimal Power { get; private set; }
        public Decimal Voltage { get; private set; }
        public String TransportOption { get; private set; }
        public String CTE { get; private set; }
        public String Distributor { get; private set; }
        public String DistributorTollFreeNumber { get; private set; }
        public Datetime StartDate { get; private set; }
        public Datetime EndDate { get; private set; }
        public Datetime CallbackDate { get; private set; }
        public Decimal HistoricalConsumption { get; private set; }
        public Datetime InsertedDate { get; private set; }
        public Datetime UpdatedDate { get; private set; }
    }

    //==================================================================================================================
    // SObjects
    //==================================================================================================================
    /**
     * Account
     */
    public class EnergestAccount extends EnergestSObjectWrapper {

        public Account oAccount { get; private set; }

        private final String DEBUG_HEADER = 'EnergestAccount.';

        private final Id RECORD_TYPE_ID_ACCOUNT_BUSINESS = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BusinessAccount').getRecordTypeId();
        private final Id RECORD_TYPE_ID_ACCOUNT_PRIVATE  = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();

        public EnergestAccount(EnergestEntityPod parentEnergestEntityPod) {
            super(parentEnergestEntityPod);
        }

        /**
         * Return duplicate presentation
         *
         * @return
         */
        public override DuplicateCheckPresentation getDuplicateCheckPresentation() {

            if (this.parentEnergestEntityPod.oEnergestPod.get(ENERGEST_POD_LOOKUP_FIELD) != null) {
                return null;
            }

            DuplicateCheckPresentation oDuplicateCheckPresentation = new DuplicateCheckPresentation();
            oDuplicateCheckPresentation.lookupField      = ENERGEST_POD_LOOKUP_FIELD;
            oDuplicateCheckPresentation.externalField    = 'EnergestCustomerID__c';
            oDuplicateCheckPresentation.value            = this.oAccount.EnergestCustomerID__c;
            oDuplicateCheckPresentation.energestPodId    = this.parentEnergestEntityPod.oEnergestPod.Id;
            oDuplicateCheckPresentation.sobjectName      = 'Account';

            // since 2019-08-19 (see Duplicate Rules in Salesforce)
            oDuplicateCheckPresentation.useDuplicateRule = true;
            oDuplicateCheckPresentation.duplicateCheckSObject = (SObject)this.oAccount;

            return oDuplicateCheckPresentation;
        }

        /**
         * Returns SObject fields
         *
         * @param inRelationToEnergestPod
         *
         * @return
         */
        public override Map<String, Set<String>> getSObjectFields(Boolean inRelationToEnergestPod) {

            Map<String, Set<String>> mapFieldsBySObject = new Map<String, Set<String>>();

            Set<String> lsetFields = this.oAccount.getPopulatedFieldsAsMap().keySet().clone();

            if (inRelationToEnergestPod) {
                lsetFields = this.addRelationPrefixForSoqlFields(ENERGEST_POD_LOOKUP_FIELD_RELATION, lsetFields);
                lsetFields.add(ENERGEST_POD_LOOKUP_FIELD);
            }

            mapFieldsBySObject.put('Account', lsetFields);

            //if (this.oContact != null) {
                //mapFieldsBySObject.put('Contact', this.oContact.getPopulatedFieldsAsMap().keySet());
            //}

            return mapFieldsBySObject;
        }

        /**
         *
         */
        protected override void init() {

            ENERGEST_POD_LOOKUP_FIELD = 'Account__c';
            ENERGEST_POD_LOOKUP_FIELD_RELATION = 'Account__r';

            this.oAccount = new Account(
                FirstName              = this.CustomerFirstName,
                LastName               = this.CustomerLastName,
                BillingStreet          = this.BillingStreetAndNo,
                BillingPostalCode      = this.BillingPostalCode,
                BillingCity            = this.BillingCity,
                BillingCountryCode     = this.BillingCountryCode,
                BillingStateCode       = this.BillingStateCode,
                ShippingStreet         = this.ShippingStreetAndNo,
                ShippingPostalCode     = this.ShippingPostalCode,
                ShippingCity           = this.ShippingCity,
                ShippingCountryCode    = this.ShippingCountryCode,
                ShippingStateCode      = this.ShippingStateCode,
                EnergestCustomerID__c  = String.valueOf(this.pod.CustomerInternalId),
                VATId__c               = this.pod.CustomerVATId,
                IdentificationNumber__c= this.pod.CustomerFiscalCode,
                Phone                  = this.CustomerPhone
            );

            // Business Account
            // THIS SHOULD BE DONE IN AN OWN WRAPPER!
            //if (CAN_CREATE_BUSINESS_ACCOUNTS && String.isNotBlank(this.pod.CustomerVATId)) {
            //
            //    this.oAccount.RecordTypeId   = RECORD_TYPE_ID_ACCOUNT_BUSINESS;
            //    this.oAccount.Name           = this.pod.CustomerCompany;
            //    this.oAccount.VATId__c       = this.pod.CustomerVATId;
            //
            //    // Create Contact
            //    this.oContact = new Contact(
            //        FirstName            = this.oAccount.FirstName,
            //        LastName             = this.oAccount.LastName,
            //        MailingStreet        = this.oAccount.BillingStreet,
            //        MailingPostalCode    = this.oAccount.BillingPostalCode,
            //        MailingCity          = this.oAccount.BillingCity,
            //        MailingCountryCode   = this.oAccount.BillingCountryCode,
            //        MailingStateCode     = this.oAccount.BillingStateCode
            //    );
            //
            //    this.oContact = (Contact)sanitizeSObject(this.oContact);
            //}
            // Person Account
            //else {
                oAccount.RecordTypeId               = RECORD_TYPE_ID_ACCOUNT_PRIVATE;
                oAccount.PersonMailingStreet        = oAccount.BillingStreet;
                oAccount.PersonMailingPostalCode    = oAccount.BillingPostalCode;
                oAccount.PersonMailingCity          = oAccount.BillingCity;
                oAccount.PersonMailingCountryCode   = oAccount.BillingCountryCode;
                oAccount.PersonMailingStateCode     = oAccount.BillingStateCode;
                oAccount.PersonMobilePhone          = this.CustomerMobile;
                oAccount.PersonEmail                = this.CustomerEmail;
                oAccount.PersonHomePhone            = this.CustomerPhone;
                oAccount.Language__pc               = 'it';
            //}

            this.oAccount = (Account)sanitizeSObject(this.oAccount);

            Map<String, Object> mapValues = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(this.oAccount));
            mapValues.put('PersonContactId', null); // Could otherwise to be added

            this.oAccount = this.createAccountFromMap(mapValues);
            this.oSObject = this.oAccount;
        }

        /**
         * Reinit SObject
         *
         * @param oSObject
         */
        public override void reinitSObject(SObject oSObject) {
            this.oSObject = oSObject;
            this.oAccount = (Account)oSObject;
        }

        /**
         * Create an Account from a Map
         *
         * @param mapValues
         *
         * @return
         */
        private Account createAccountFromMap(Map<String, Object> mapValues) {
            return (Account)JSON.deserialize(JSON.serialize(mapValues), Account.class);
        }

        /**
         * Return changes
         *
         * @param energestPod
         *
         * @return
         */
        protected override Boolean hasChange() {

            final String DEBUG_HERE = DEBUG_HEADER + 'hasChange() - ';
            Boolean hasChange = false;

            EnergestPod__c energestPod = this.parentEnergestEntityPod.oEnergestPod;

            //System.debug('this.oAccount.Id: ' + this.oAccount.Id);
            //System.debug('this.oAccount.LastName: ' + this.oAccount.LastName);
            //System.debug('this.oAccount.PersonContactId: ' + this.oAccount.PersonContactId);

            // Insert
            // - if energestPod has no Account ID set yet AND
            // - if local Account wasn't created yet
            if (energestPod.Account__r == null && this.oAccount.Id == null) {
                hasChange = true;
            }
            // Update
            // - if energestPod has an related Account AND
            // - this Account differs from local temporary Account
            else if (energestPod.Account__r != null) {

                // Set ID of existing Account
                this.oAccount.Id = energestPod.Account__c;

                // Needed to set PersonContactId to the Account!
                // This is special for Account as PersonContactId is not writable but
                // has to be provided here.
                Map<String, Object> mapValues = this.oAccount.getPopulatedFieldsAsMap().clone();
                mapValues.put('PersonContactId', energestPod.Account__r.PersonContactId);
                this.oAccount = this.createAccountFromMap(mapValues);

                Boolean bFoundByDuplicateSearchFuzzy = false;
                Boolean bFoundByDuplicateSearch = false;

                if (EnergestEntityPod.mapDuplicateMatchesByPodId.containsKey(energestPod.Id)) {

                    Map<Id, Boolean> mapSObjectDuplicateFuzzy = EnergestEntityPod.mapDuplicateMatchesByPodId.get(energestPod.Id);

                    if (mapSObjectDuplicateFuzzy.containsKey(this.oAccount.Id)) {
                        bFoundByDuplicateSearch = true;
                        bFoundByDuplicateSearchFuzzy = mapSObjectDuplicateFuzzy.get(this.oAccount.Id);
                    }
                }

                // Update only allowed if not found by duplicate search OR
                // otherwise update on existing object is allowed but then only
                // if it was found as an exact match NOT fuzzy
                if (getChecksum(energestPod.Account__r) != getChecksum(this.oAccount)) {

                    System.debug(DEBUG_HERE + 'Existing Account (' + this.oAccount.FirstName + ' ' + this.oAccount.LastName + ') has changes');

                    if (bFoundByDuplicateSearch) {
                        System.debug(DEBUG_HERE + 'Account found ' + (bFoundByDuplicateSearchFuzzy ? 'fuzzy' : 'exactly') + ' by duplicate search');
                    }

                    if ((!bFoundByDuplicateSearch || (EnergestEntityPod.ALLOW_DUPLICATE_UPDATE && !bFoundByDuplicateSearchFuzzy))) {
                        System.debug(DEBUG_HERE + 'Account allowed to be updated');
                        hasChange = true;
                        energestPod.Account__r = this.oAccount.clone();
                    }
                    else if (bFoundByDuplicateSearch) {

                        if (!EnergestEntityPod.ALLOW_DUPLICATE_UPDATE) {
                            System.debug(DEBUG_HERE + 'Update on existing Accounts NOT allowed');
                        }
                        else if (bFoundByDuplicateSearchFuzzy) {
                            System.debug(DEBUG_HERE + 'Update on existing Accounts allowed but not on fuzzy found');
                        }
                    }
                }
            }

            return hasChange;
        }
    }

    /**
     * Contract
     */
    public class EnergestContract extends EnergestSObjectWrapper {

        public Contract oContract  { get; private set; }

        private final String DEBUG_HEADER = 'EnergestContract.';

        private final Map<String, String> mapPaymentMapping = new Map<String, String>{
            'SDD Core' => 'SEPA direct debit'
        };

        /**
         * Constructor
         *
         * @param parentEnergestEntityPod
         */
        public EnergestContract(EnergestEntityPod parentEnergestEntityPod) {
            super(parentEnergestEntityPod);

            if (!TriggerHandler.isBypassed('ContractTriggerHandler')) {
                System.debug('EnergestEntityPod.EnergestContract() - Bypass ContractTriggerHandler');
                TriggerHandler.bypass('ContractTriggerHandler');
            }
        }

        /**
         * Return duplicate presentation
         *
         * @return
         */
        public override DuplicateCheckPresentation getDuplicateCheckPresentation() {

            if (this.parentEnergestEntityPod.oEnergestPod.get(ENERGEST_POD_LOOKUP_FIELD) != null) {
                return null;
            }

            DuplicateCheckPresentation oDuplicateCheckPresentation = new DuplicateCheckPresentation();
            oDuplicateCheckPresentation.lookupField     = ENERGEST_POD_LOOKUP_FIELD;
            oDuplicateCheckPresentation.externalField   = 'EnergestInternalId__c';
            oDuplicateCheckPresentation.value           = this.oContract.EnergestInternalId__c;
            oDuplicateCheckPresentation.energestPodId   = this.parentEnergestEntityPod.oEnergestPod.Id;
            oDuplicateCheckPresentation.sobjectName     = 'Contract';

            return oDuplicateCheckPresentation;
        }

        /**
         *  Returns SObject fields
         *
         * @param inRelationToEnergestPod
         *
         * @return
         */
        public override Map<String, Set<String>> getSObjectFields(Boolean inRelationToEnergestPod) {

            Map<String, Set<String>> mapFieldsBySObject = new Map<String, Set<String>>();

            Set<String> lsetFields = this.addRelationPrefixForSoqlFields(ENERGEST_POD_LOOKUP_FIELD_RELATION, this.oContract.getPopulatedFieldsAsMap().keySet());
            lsetFields.add(ENERGEST_POD_LOOKUP_FIELD);

            mapFieldsBySObject.put('Contract', lsetFields);
            return mapFieldsBySObject;
        }

        /**
         * Init Contract
         */
        protected override void init() {

            ENERGEST_POD_LOOKUP_FIELD = 'Contract__c';
            ENERGEST_POD_LOOKUP_FIELD_RELATION = 'Contract__r';

            this.oContract = new Contract(
                Status                          = 'Draft',
                EnergestInternalId__c           = String.valueOf(this.pod.PoDInternalId),
                EnergestContractInternalId__c   = String.valueOf(this.pod.ContractInternalId),
                RecordTypeId                    = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get(CONTRACT_RECORD_TYPE_DEVELOPER_NAME).getRecordTypeId(),
                StartDate                       = convertDatetimeToDate(this.pod.StartDate),
                EndDate                         = convertDatetimeToDate(this.pod.EndDate),
                MeterId__c                      = this.pod.PoDNumber,
                // Billing Address
                BillingStreet__c                = this.BillingStreet,
                BillingStreetNumber__c          = this.BillingStreetNo,
                BillingPostalCode__c            = this.BillingPostalCode,
                BillingCity__c                  = this.BillingCity,
                BillingCountry__c               = this.BillingCountryCode,
                BillingStateProvince__c         = this.BillingStateCode,
                // Shipping Address
                ShippingStreet__c               = this.ShippingStreet,
                ShippingStreetNumber__c         = this.ShippingStreetNo,
                ShippingPostalCode__c           = this.ShippingPostalCode,
                ShippingCity__c                 = this.ShippingCity,
                ShippingStateProvince__c        = this.ShippingStateCode,
                ShippingCountry__c              = this.ShippingCountryCode,
                PaymentMethod__c                = this.mapPaymentMapping.get(this.pod.PaymentTerms),

                // Contracting Party
                ContractingPartnerFirstname__c  = this.CustomerFirstName,
                ContractingPartnerLastname__c   = this.CustomerLastName,
                ContractingPartyEmail__c        = this.CustomerEmail,
                ContractingPartyPhone__c        = this.CustomerPhone,
                //ContractingPartyAccountName__c  = this.pod.CustomerCompany,
                CustomerSignedDate              = convertDatetimeToDate(this.pod.CallbackDate),

                // Supply
                PreviousProviderName__c         = this.pod.PreviousSupplier,
                PowerOfMeter__c                 = this.pod.Power,
                AnnualConsumptionTotal__c       = this.pod.HistoricalConsumption,
                ExternalOrderId__c              = String.valueOf(this.pod.PoDInternalId),
                HasSonnenBattery__c             = true,
                SubscriptionReason__c           = 'Change of Provider (E03)',
                ContractTerm                    = 1,

                BankDataIBAN__c                 = (this.pod.PaymentIBAN != null) ? this.pod.PaymentIBAN.replaceAll('\\s', '') : null,
                BankDataFirstname__c            = capitalizeEachWord(this.pod.AttorneyName),
                BankDataLastname__c             = capitalizeEachWord(this.pod.AttorneySurname),
                FinancialServiceProvider__c     = 'Enersis',
                Type__c                         = 'sonnenFlat-IT', // since 2019-08-20

                AccountId                       = null,
                BankData__c                     = null,
                CustomerSignedId                = null
            );

            this.oSObject = this.oContract;
        }

        /**
         * Check if values where changed
         *
         * @param energestPod
         *
         * @return
         */
        protected override Boolean hasChange() {

            Boolean hasChange = false;

            final String DEBUG_HERE = DEBUG_HEADER + 'getChanges() - ';

            EnergestPod__c energestPod = this.parentEnergestEntityPod.oEnergestPod;

            // Insert after Account or Bank Data was created
            // At least Account is required!
            if (energestPod.Contract__r == null) {

                // Relate Account (REQUIRED!)
                Account oAccount = this.parentEnergestEntityPod.energestAccount.oAccount;

                if (oAccount != null && oAccount.Id != null && this.oContract.AccountId != oAccount.Id) {

                    System.debug(DEBUG_HERE + 'Contract will be related to Account "' + oAccount.LastName + '" (' + oAccount.Id + ', EnergestCustomerID__c: ' + oAccount.EnergestCustomerID__c + ')');

                    this.oContract.AccountId        = oAccount.Id;
                    this.oContract.CustomerSignedId = oAccount.PersonContactId;

                    hasChange = true;
                }

                // Relate Bank Data (OPTIONAL)
                BankData__c oBankData = this.parentEnergestEntityPod.energestBankData.oBankData;

                if (oBankData != null && oBankData.Id != null && this.oContract.BankData__c != oBankData.Id) {

                    System.debug(DEBUG_HERE + 'Contract will be related to BankData "' + oBankData.IBAN__c + '" (' + oBankData.Id + ')');
                    this.oContract.BankData__c = oBankData.Id;

                    hasChange = true;
                }

                // Update status (only Contract doesn't exist yet!)
                if (this.oContract.Id != null && this.oContract.Status == 'Draft') {

                    this.oContract.Status = 'Activated';
                    System.debug(DEBUG_HERE + 'Activate Contract ' + this.oContract.Id);
                    hasChange = true;
                }
            }
            // Update
            else {

                // Set special values
                this.oContract.Id               = energestPod.Contract__c;
                this.oContract.Status           = energestPod.Contract__r.Status;
                this.oContract.AccountId        = energestPod.Contract__r.AccountId;
                this.oContract.CustomerSignedId = energestPod.Contract__r.CustomerSignedId;

                if (getChecksum(energestPod.Contract__r) != getChecksum(this.oContract)) {
                    hasChange = true;
                    energestPod.Contract__r = this.oContract.clone();
                }
            }

            return hasChange;
        }

        /**
         * Reinit SObject
         *
         * @param oSObject
         */
        public override void reinitSObject(SObject oSObject) {
            this.oSObject = oSObject;
            this.oContract = (Contract)oSObject;
        }
    }

    /**
     * BankData__c
     */
    public class EnergestBankData extends EnergestSObjectWrapper {

        public BankData__c oBankData  { get; private set; }

        private final String DEBUG_HEADER = 'EnergestBankData.';

        public EnergestBankData(EnergestEntityPod parentEnergestEntityPod) {
            super(parentEnergestEntityPod);
        }

        /**
         * Returns SObject fields
         *
         * @param inRelationToEnergestPod
         *
         * @return
         */
        public override Map<String, Set<String>> getSObjectFields(Boolean inRelationToEnergestPod) {

            Map<String, Set<String>> mapFieldsBySObject = new Map<String, Set<String>>();

            Set<String> lsetFields = this.addRelationPrefixForSoqlFields(ENERGEST_POD_LOOKUP_FIELD_RELATION, this.oBankData.getPopulatedFieldsAsMap().keySet());
            lsetFields.add(ENERGEST_POD_LOOKUP_FIELD);

            mapFieldsBySObject.put('BankData', lsetFields);
            return mapFieldsBySObject;
        }

        /**
         * Init
         */
        protected override void init() {

            ENERGEST_POD_LOOKUP_FIELD = 'BankData__c';
            ENERGEST_POD_LOOKUP_FIELD_RELATION = 'BankData__r';

            // Bank Data
            this.oBankData = new BankData__c(
                IBAN__c             = (this.pod.PaymentIBAN != null) ? this.pod.PaymentIBAN.replaceAll('\\s', '') : null,
                FirstName__c        = capitalizeEachWord(this.pod.AttorneyName),
                LastName__c         = capitalizeEachWord(this.pod.AttorneySurname),
                SepaDate__c         = convertDatetimeToDate(this.pod.CallbackDate),
                Account__c          = null
            );

            this.oSObject = this.oBankData;
        }

        /**
         * Return duplicate presentation
         *
         * @return
         */
        public override DuplicateCheckPresentation getDuplicateCheckPresentation() {

            if (this.parentEnergestEntityPod.oEnergestPod.get(ENERGEST_POD_LOOKUP_FIELD) != null) {
                return null;
            }

            DuplicateCheckPresentation oDuplicateCheckPresentation = new DuplicateCheckPresentation();
            oDuplicateCheckPresentation.lookupField     = ENERGEST_POD_LOOKUP_FIELD;
            oDuplicateCheckPresentation.externalField   = 'EnergestPseudoId__c';
            oDuplicateCheckPresentation.value           = this.pod.CustomerInternalId + '-' + this.oBankData.IBAN__c;
            oDuplicateCheckPresentation.energestPodId   = this.parentEnergestEntityPod.oEnergestPod.Id;
            oDuplicateCheckPresentation.sobjectName     = 'BankData__c';

            return oDuplicateCheckPresentation;
        }

        /**
         * Reinit SObject
         *
         * @param oSObject
         */
        public override void reinitSObject(SObject oSObject) {
            this.oSObject = oSObject;
            this.oBankData = (BankData__c)oSObject;
        }

        /**
         * Check if values where changed
         *
         * @param energestPod
         *
         * @return
         */
        protected override Boolean hasChange() {

            Boolean hasChange = false;

            final String DEBUG_HERE = DEBUG_HEADER + 'getChanges() - ';

            EnergestPod__c energestPod = this.parentEnergestEntityPod.oEnergestPod;

            if (this.oBankData.IBAN__c == null) {
                return false;
            }

            // Account must be set and have an ID to relate BankData to it!
            Account oAccount = this.parentEnergestEntityPod.energestAccount.oAccount;

            // Insert
            // After Account was created
            if (energestPod.BankData__r == null) {

                if (oAccount != null && oAccount.Id != null && this.oBankData.Account__c != oAccount.Id) {

                    System.debug(DEBUG_HERE + 'Bank Data will be related to Account "' + oAccount.LastName + '" (' + oAccount.Id + ', EnergestCustomerID__c: ' + oAccount.EnergestCustomerID__c + ')');
                    this.oBankData.Account__c = oAccount.Id;

                    hasChange = true;
                }
            }
            // Update
            else {

                this.oBankData.Id = energestPod.BankData__c;

                if (getChecksum(energestPod.BankData__r) != getChecksum(this.oBankData)) {
                    hasChange = true;
                    energestPod.BankData__r = this.oBankData.clone();
                }
            }

            return hasChange;
        }
    }

    public class EnergestEntityPodException extends Exception {}
}