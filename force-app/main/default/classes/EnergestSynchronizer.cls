/**
 * EnergestSynchronizer
 *
 * In scheduler mode: Fetches and processes new PODs.
 * In batch mode: Processes only unprocessed EnergestPod__r records.
 *
 * v1.0.0   2019-02-28  Marko Schmalenbach          Initial
 * v1.1.0   2019-03-08  Marko Schmalenbach          - Added periodOfDaysToFetch to filter for PODs with special StartDate
 *                                                  - Added batch size
 *                                                  - Implemented partial upserts
 * v1.2.0   2019-08-20  Marko Schmalenbach          Added test for finding existing Accounts with duplicate search
 *
 * Run scheduler with fetching and processing from anonymous Apex:
 *
 *  new EnergestSynchronizer().execute(null);
 *
 *
 * Get updates of last 5 days and process them in a batch
 *
 *  EnergestSynchronizer oSynchronizer = new EnergestSynchronizer();
 *  oSynchronizer.fetch(5); // last 5 days
 *  Database.executeBatch(oSynchronizer);
 *
 * @see https://interaktiv.jira.com/browse/SOBCRM-1321
 * @see EnergestSynchronizerTest
 */
public without sharing class EnergestSynchronizer implements Database.Batchable<SObject>, Database.Stateful, Schedulable, Database.AllowsCallouts {

    private static final String DEBUG_HEADER = 'EnergestSynchronizer.';

    @TestVisible
    private static Integer DEFAULT_PERIOD_OF_TIME_DAYS = 1;

    private static final Integer MAX_CHANGE_ITERATIONS = 10;
    private static final Integer API_MAX_ROWS_PER_PAGE = 50;

    /**
     * Max batch size
     *
     * It's strongly recommended to keep this to 1 as it's difficult to locate the
     * POD which raises the error as SObjects of one type are all saved by one single DML.
     */
    private static final Integer DEFAULT_BATCH_SIZE = 10;

    @TestVisible
    private static final String ERROR_CASE_SUBJECT = 'Error on synchronizing italian contracts (Enersis)';

    private static final Boolean UPDATES_ALLOWED = false;

    public Boolean fetchDone = false;

    public Integer periodOfDaysToFetch = DEFAULT_PERIOD_OF_TIME_DAYS;

    public Integer defaultBatchSize = DEFAULT_BATCH_SIZE;

    /**
     * Min Start Date for POD
     */
    public Date minPodStartDate = Date.newInstance(2019, 3, 1);

    /**
     * execute() with SchedulableContext
     */
    public void execute(SchedulableContext SC) {
        Database.executeBatch(this, this.defaultBatchSize);
    }

    /**
     * fetch() with default period of days
     */
    public void fetch() {
        this.fetch(this.periodOfDaysToFetch);
    }

    /**
     * Fetches italian contracts (PODs) and inserts them as EnergestPod__c records
     *
     * @param periodOfDays
     */
    public void fetch(Integer periodOfDays) {

        final String DEBUG_HERE = DEBUG_HEADER + 'fetch() - ';

        if (periodOfDays == null || periodOfDays <= 0) {
            throw new EnergestSynchronizerException('Period of days has to be defined and > 0');
        }

        System.debug(DEBUG_HERE + 'Fetch for a period of ' + periodOfDays + ' day(s)');

        this.fetchDone = true;

        Long lUpdatedAfterTimestamp = (System.now().getTime()/1000) - (86400 * periodOfDays);
        EnergestApi.Response oResponse;
        Integer iPage = 1;
        Integer iCurrentRows;

        EnergestApi oApi = new EnergestApi();

        List<EnergestEntityPod> listFetchedPods = new List<EnergestEntityPod>();

        do {
            oResponse = oApi.apiGetPodList(lUpdatedAfterTimestamp, iPage, API_MAX_ROWS_PER_PAGE);
            List<EnergestEntityPod> listPods = (List<EnergestEntityPod>)oResponse.result;

            if (oApi.lastError != null) {
                throw new EnergestSynchronizerException('API error: ' + oApi.lastError);
            }
            if (listPods == null) {
                throw new EnergestSynchronizerException('Response was null or in an unexpected format: ' + oResponse);
            }

            iCurrentRows = listPods.size();

            listFetchedPods.addAll(listPods);
            iPage++;
        }
        while (iCurrentRows == API_MAX_ROWS_PER_PAGE);

        System.debug(DEBUG_HERE + 'Fetched ' + listFetchedPods.size() + ' record(s) after calling ' + (iPage-1) + ' page(s) with ' + API_MAX_ROWS_PER_PAGE + ' record(s) per page');

        if (listFetchedPods.isEmpty()) {
            return;
        }

        // Get POD numbers
        Set<String> lsetPodNumbers = new Set<String>();
        for (EnergestEntityPod oPod : listFetchedPods) {
            lsetPodNumbers.add(String.valueOf(oPod.sourcePod.PoDInternalId));
        }

        // Get existing PODs by numbers
        Map<String, EnergestPod__c> mapExistingPodsByNo = new Map<String, EnergestPod__c>();
        for (EnergestPod__c oPod : [SELECT Id, EnergestLastModified__c, PodInternalId__c FROM EnergestPod__c WHERE PodInternalId__c IN :lsetPodNumbers]) {
            mapExistingPodsByNo.put(oPod.PodInternalId__c, oPod);
        }

        // Check on upsert
        List<EnergestPod__c> listEnergestPodsToUpsert = new List<EnergestPod__c>();

        Integer iToInsert = 0;
        Integer iToUpdate = 0;

        Integer iPotentialInserts = 0;

        for (EnergestEntityPod oFetchedPod : listFetchedPods) {

            // Dismiss PODs without StartDate!
            if (oFetchedPod.sourcePod.StartDate == null) {
                continue;
            }

            Date dateStart = EnergestSObjectWrapper.convertDatetimeToDate(oFetchedPod.sourcePod.StartDate);

            // Skip POD if min StartDate is set which is not accomplished
            if (this.minPodStartDate != null && dateStart < this.minPodStartDate) {
                System.debug(DEBUG_HERE + 'POD\'s StartDate ' + dateStart + ' is lower than minPodStartDate ' + this.minPodStartDate + ' - skipped!');
                continue;
            }
            iPotentialInserts++;

            EnergestPod__c oEnergestPod = new EnergestPod__c();
            String sPodInternalId = String.valueOf(oFetchedPod.sourcePod.PoDInternalId);

            // If POD doesn't exist yet
            if (!mapExistingPodsByNo.containsKey(sPodInternalId)) {
                oEnergestPod.PodInternalId__c = sPodInternalId;
                oEnergestPod.PodNo__c         = oFetchedPod.sourcePod.PoDNumber;
                oEnergestPod.Name             = 'POD-' + sPodInternalId;
                oEnergestPod.PodStartDate__c  = dateStart;
                iToInsert++;
            }
            // Else if it exists but UpdatedDate changed
            else if (String.valueOf(mapExistingPodsByNo.get(sPodInternalId).EnergestLastModified__c) != String.valueOf(oFetchedPod.sourcePod.UpdatedDate)) {

                if (!UPDATES_ALLOWED) {
                    System.debug(DEBUG_HERE + 'UpdatedDate for ' + sPodInternalId + ' differs existing EnergestLastModified__c but Updates are currently deactivated!');
                    continue;
                }

                oEnergestPod = mapExistingPodsByNo.get(sPodInternalId);
                iToUpdate++;
            }
            else {
                continue;
            }

            oEnergestPod.DataAsJson__c           = oFetchedPod.getSourcePodAsJson();
            oEnergestPod.EnergestLastModified__c = oFetchedPod.sourcePod.UpdatedDate;

            listEnergestPodsToUpsert.add(oEnergestPod);
        }

        System.debug(DEBUG_HERE + 'Potential inserts: ' + iPotentialInserts);

        if (!listEnergestPodsToUpsert.isEmpty()) {
            System.debug(DEBUG_HERE + listEnergestPodsToUpsert.size() + ' EnergestPod__c record(s) to upsert (Insert: ' + iToInsert + ', Update: ' + iToUpdate + ')');
            upsert listEnergestPodsToUpsert;
        }
        else {
            System.debug(DEBUG_HERE + 'Nothing to upsert');
        }
    }

    //==================================================================================================================
    // Batch
    //==================================================================================================================
    /**
     * start()
     */
    public Database.QueryLocator start(Database.BatchableContext batchableContext) {

        final String DEBUG_HERE = DEBUG_HEADER + 'start(Database.BatchableContext) - ';

        // Get new PODs from Energest API
        if (!this.fetchDone) {

            Integer iPeriodDays = this.getPeriodOfDaysToFetchFromSettings();

            if (iPeriodDays != null) {
                this.periodOfDaysToFetch = iPeriodDays;
            }

            this.fetch();
        }

        // If you use a QueryLocator object, the governor limit for the total number
        // of records retrieved by SOQL queries is bypassed (up to 50 million records)
        String sQuery = 'SELECT Id, Name, DataAsJson__c FROM EnergestPod__c WHERE NeedsCheck__c = TRUE';
        System.debug(DEBUG_HERE + 'Query: ' + sQuery);

        return Database.getQueryLocator(sQuery);
    }

    /**
     *
     *
     * @return
     */
    @TestVisible
    private Integer getPeriodOfDaysToFetchFromSettings() {

        Integer iPeriodDays;

        // Get max period of days from Settings
        List<GeneralSetting__mdt> listSetting;

        if (Test.isRunningTest()) {
            listSetting = new List<GeneralSetting__mdt>{
                new GeneralSetting__mdt(
                    DeveloperName = 'EnergestPeriodOfDaysToFetch',
                    TextValue__c = String.valueOf(DEFAULT_PERIOD_OF_TIME_DAYS)
                )
            };
        }
        else {
            listSetting = [
                SELECT DeveloperName, TextValue__c
                FROM GeneralSetting__mdt
                WHERE DeveloperName = 'EnergestPeriodOfDaysToFetch' AND TextValue__c != NULL
            ];
        }

        if (!listSetting.isEmpty()) {

            GeneralSetting__mdt oGeneralSettingPeriod = listSetting.get(0);

            if (oGeneralSettingPeriod.TextValue__c.isNumeric()) {

                Integer iDays = Integer.valueOf(oGeneralSettingPeriod.TextValue__c);

                if (iDays > 0) {
                    iPeriodDays = iDays;
                }
            }
        }

        return iPeriodDays;
    }

    /**
     * execute() with BatchableContext
     */
    public void execute(Database.BatchableContext batchableContext, List<SObject> scopeObjects) {

        final String DEBUG_HERE = DEBUG_HEADER + 'execute(Database.BatchableContext) - ';
        System.debug(DEBUG_HERE + 'Start');

        String sError;

        List<EnergestPod__c> listEnergestPods = (List<EnergestPod__c>)scopeObjects;
        try {

            List<EnergestPod__c> listUpdatedEnergestPods = this.processChanges(listEnergestPods);

            List<String> listErrors = new List<String>();

            for (EnergestPod__c oEnergestPod : listUpdatedEnergestPods) {
                if (String.isNotBlank(oEnergestPod.Error__c)) {
                    listErrors.add(oEnergestPod.Name + ' (' + oEnergestPod.Id + '): ' + oEnergestPod.Error__c);
                }
            }

            if (!listErrors.isEmpty()) {
                sError = 'An error occurred on synchronizing the following italian contracts (POD):\n\n• ' + String.join(listErrors, '\n• ');
            }
        }
        catch (Exception e) {

            List<String> listPodNames = new List<String>();
            for (EnergestPod__c oEnergestPod : listEnergestPods) {
                listPodNames.add(oEnergestPod.Name + ' (' + oEnergestPod.Id + ')');
            }

            sError = 'An error occurred on synchronizing the following italian contracts (POD):\n\n• ' +
                    String.join(listPodNames, '\n• ') + '\n\n' +
                    'Error:\n' +
                    e.getMessage() + '\n' +
                    e.getStackTraceString();
        }

        if (String.isNotBlank(sError)) {

            insert new Case(
                Subject     = ERROR_CASE_SUBJECT,
                Description = sError,
                Status      = 'Open',
                Priority    = 'Normal'
            );
        }
    }

    /**
     *
     *
     * @param soql
     * @param lsetIds
     *
     * @return
     */
    private Map<Id, EnergestEntityPod> getEnergestEntityPods(String soql, Set<Id> lsetEnergestPodIds) {

        final String DEBUG_HERE = DEBUG_HEADER + 'getEnergestEntityPods() - ';

        // Get all relevant related child objects and fields
        List<EnergestPod__c> listEnergestPod = (List<EnergestPod__c>)Database.query(soql);

        // Convert all EnergestPod__c records to EnergestEntityPod
        Map<Id, EnergestEntityPod> mapEnergestEntityPods = new Map<Id, EnergestEntityPod>();

        for (EnergestPod__c oEnergestPod : listEnergestPod) {
            mapEnergestEntityPods.put(oEnergestPod.Id, new EnergestEntityPod(oEnergestPod));
        }

        System.debug(DEBUG_HERE + 'DMLs left: ' + this.getDmlStatementsLeft());
        return mapEnergestEntityPods;
    }

    /**
     * Process changed
     *
     * @param listEnergestPod EnergestPod__c records
     */
    public List<EnergestPod__c> processChanges(List<EnergestPod__c> listEnergestPod) {

        final String DEBUG_HERE = DEBUG_HEADER + 'processChanges() - ';
        System.debug(DEBUG_HERE + 'Handle ' + listEnergestPod.size() + ' Energest POD(s)');

        if (listEnergestPod.isEmpty()) {
            return null;
        }

        Map<String, Set<String>> mapFieldsBySObject = new Map<String, Set<String>>();

        Set<Id> lsetEnergestPodIds = new Set<Id>();

        // - Get SOQL fields to request
        // - Collect SObjects for duplicate check
        for (EnergestPod__c oEnergestPod : listEnergestPod) {
            lsetEnergestPodIds.add(oEnergestPod.Id);
            EnergestEntityPod oNewPod = new EnergestEntityPod(oEnergestPod);
            EnergestEntityPod.mergeFieldMap(mapFieldsBySObject, oNewPod.getSObjectFieldsForSoql());
        }

        Set<String> lsetAllFields = new Set<String>();

        for (String sLookupField : mapFieldsBySObject.keySet()) {
            lsetAllFields.addAll(mapFieldsBySObject.get(sLookupField));
        }

        String sSOQL = 'SELECT ' +
            'Id, Name, EnergestLastModified__c, Error__c, DataAsJson__c, ' +
            String.join(new List<String>(lsetAllFields), ', ') + ' ' +
            'FROM EnergestPod__c ' +
            'WHERE Id IN :lsetEnergestPodIds AND NeedsCheck__c = true';
        System.debug(DEBUG_HERE + 'sSOQL: ' + sSOQL);

        //------------------------------------------------------
        // Duplicate check by External ID
        //------------------------------------------------------
        System.debug(DEBUG_HERE + 'Start search for existing objects to prevent duplicates');
        List<EnergestEntityPod.DuplicateCheckPresentation> listDuplicateCheckPresentations = new List<EnergestEntityPod.DuplicateCheckPresentation>();

        // Get existing EnergestPod__c records by given IDs
        Map<Id, EnergestEntityPod> mapEnergestEntityPods = this.getEnergestEntityPods(sSOQL, lsetEnergestPodIds);

        listEnergestPod.clear();

        // Search for existing SObjects by their external ID
        for (Id idEnergestPod : mapEnergestEntityPods.keySet()) {
            EnergestEntityPod oEnergestEntityPod = mapEnergestEntityPods.get(idEnergestPod);
            listEnergestPod.add(oEnergestEntityPod.oEnergestPod);
            listDuplicateCheckPresentations.addAll(oEnergestEntityPod.getDuplicateCheckPresentations());
        }

        // Map all Duplicate Check Presentation objects by lookup field name (Account__c, Contract__c, ...)
        // Lookup Field -> DuplicateCheckPresentation
        Map<String, EnergestEntityPod.DuplicateCheckPresentation> mapDuplicateCheckPresentationByLookupfield = new Map<String, EnergestEntityPod.DuplicateCheckPresentation>();

        for (EnergestEntityPod.DuplicateCheckPresentation oDuplicateCheckPresentation : listDuplicateCheckPresentations) {

            String sLookupfield = oDuplicateCheckPresentation.lookupField;

            // The first oDuplicateCheckPresentation is used for collecting all external IDs for ONE lookup field
            if (!mapDuplicateCheckPresentationByLookupfield.containsKey(sLookupfield)) {
                mapDuplicateCheckPresentationByLookupfield.put(sLookupfield, oDuplicateCheckPresentation);
            }

            // Add external Id by EnergestPod__c Id for each lookup field
            mapDuplicateCheckPresentationByLookupfield.get(sLookupfield).addDuplicateCheckPresentationForDuplicateCheck(oDuplicateCheckPresentation);
        }

        Map<Id, EnergestPod__c> mapEnergestPodsToUpdateForDuplicates = new Map<Id, EnergestPod__c>();

        for (EnergestEntityPod.DuplicateCheckPresentation oDuplicateCheckPresentation : mapDuplicateCheckPresentationByLookupfield.values()) {

            // This will start the duplicate check for ALL collected external IDs
            oDuplicateCheckPresentation.startCheck();

            String sLookupfield = oDuplicateCheckPresentation.lookupField;

            // Iterate over each EnergestPod__c record to get possible SObject duplicate
            for (EnergestPod__c oEnergestPod : listEnergestPod) {

                Id idEnergestPod = oEnergestPod.Id;
                Id idSObject = oDuplicateCheckPresentation.getExistingSObjectIdByEnergestPodId(idEnergestPod);

                if (idSObject != null) {

                    System.assertEquals(null, oEnergestPod.get(sLookupfield), 'Expected lookup field "' + sLookupfield + '" to be not set yet (' + oEnergestPod.Name + ')');

                    // Assign
                    oEnergestPod.put(sLookupfield, idSObject);

                    System.debug(DEBUG_HERE + 'Relate existing SObject for "' + sLookupfield + '" on EnergestPod__c "' + oEnergestPod.Name + '" (' + oEnergestPod.Id + ')');

                    if (!mapEnergestPodsToUpdateForDuplicates.containsKey(idEnergestPod)) {
                        mapEnergestPodsToUpdateForDuplicates.put(idEnergestPod, oEnergestPod);
                    }
                }
            }
        }

        if (!mapEnergestPodsToUpdateForDuplicates.isEmpty()) {

            // Update PODs with relations to existing SObjects
            update mapEnergestPodsToUpdateForDuplicates.values();

            // Reinit EnergestPod__c records
            mapEnergestEntityPods = this.getEnergestEntityPods(sSOQL, lsetEnergestPodIds);
        }
        else {
            System.debug(DEBUG_HERE + 'End search for existing SObjects: No existing SObjects found to relate to');
        }

        System.debug(DEBUG_HERE + 'SOQLs left: ' + this.getSoqlsLeft());
        System.debug(DEBUG_HERE + 'DMLs left: ' + this.getDmlStatementsLeft());

        //------------------------------------------------------
        // Upserts
        //------------------------------------------------------
        Map<String, List<EnergestSObjectWrapper>> mapSObjectsToUpdate = new Map<String, List<EnergestSObjectWrapper>>();
        Map<String, List<EnergestSObjectWrapper>> mapSObjectsToInsert = new Map<String, List<EnergestSObjectWrapper>>();

        Integer iIteration = 0;

        while (true) {

            iIteration++;
            System.debug(DEBUG_HERE + 'Iteration #' + iIteration);

            if (iIteration > MAX_CHANGE_ITERATIONS) {
                throw new EnergestSynchronizerException('Max iterations reached! 😱');
            }

            // Clear maps do prevent double handling on processed SOobjects
            mapSObjectsToUpdate.clear();
            mapSObjectsToInsert.clear();

            for (Id idEnergestPod : mapEnergestEntityPods.keySet()) {

                EnergestEntityPod oEnergestEntityPod = mapEnergestEntityPods.get(idEnergestPod);

                Map<String, EnergestSObjectWrapper> mapSObjects = oEnergestEntityPod.getChanges();

                if (!mapSObjects.isEmpty()) {

                    for (String sLookupFieldName : mapSObjects.keySet()) {

                        EnergestSObjectWrapper oEnergestSObjectWrapper = mapSObjects.get(sLookupFieldName);

                        Boolean isNew = (oEnergestSObjectWrapper.oSObject.get('Id') == null);

                        if (isNew) {
                            if (!mapSObjectsToInsert.containsKey(sLookupFieldName)) {
                                mapSObjectsToInsert.put(sLookupFieldName, new List<EnergestSObjectWrapper>());
                            }
                            mapSObjectsToInsert.get(sLookupFieldName).add(oEnergestSObjectWrapper);
                            //mapIndexToEnergyPodInsert.put(sLookupFieldName + '-' + mapSObjectsToInsert.get(sLookupFieldName).size(), oEnergestEntityPod.oEnergestPod);
                        }
                        else {
                            if (!mapSObjectsToUpdate.containsKey(sLookupFieldName)) {
                                mapSObjectsToUpdate.put(sLookupFieldName, new List<EnergestSObjectWrapper>());
                            }
                            mapSObjectsToUpdate.get(sLookupFieldName).add(oEnergestSObjectWrapper);
                        }
                    }
                }
            }

            if (mapSObjectsToInsert.isEmpty() && mapSObjectsToUpdate.isEmpty()) {
                System.debug(DEBUG_HERE + 'No ' + (iIteration > 1 ? 'further ' : '') + 'changes to make');
                break;
            }

            //------------------------------------------------------
            // Insertions
            //------------------------------------------------------
            if (!mapSObjectsToInsert.isEmpty()) {

                for (String sLookupFieldName : mapSObjectsToInsert.keySet()) {

                    List<EnergestSObjectWrapper> listEnergestSObjectWrappers = mapSObjectsToInsert.get(sLookupFieldName);
                    List<SObject> listSObjectsToInsert = getSObjectsFromWrappers(listEnergestSObjectWrappers);

                    String sSObjectName = String.valueOf(listSObjectsToInsert.get(0).getSObjectType());

                    System.debug(DEBUG_HERE + 'Creating ' + listSObjectsToInsert.size() + ' ' + sSObjectName + (listSObjectsToInsert.size() > 1 ? 's' : '') + ': ' + listSObjectsToInsert);

                    // Insert allowing partial success
                    List<Database.SaveResult> listSaveResults = Database.insert(listSObjectsToInsert, false); // allOrNone = false

                    Integer iIndex = 0;

                    for (Database.SaveResult oSaveResult : listSaveResults) {

                        EnergestSObjectWrapper oEnergestSObjectWrapper = listEnergestSObjectWrappers.get(iIndex);
                        EnergestEntityPod oEnergestEntityPod = oEnergestSObjectWrapper.parentEnergestEntityPod;
                        EnergestPod__c oEnergestPod = oEnergestEntityPod.oEnergestPod;

                        if (!oSaveResult.isSuccess()) {

                            System.debug(DEBUG_HERE + 'Error inserting ' + sSObjectName + ' for POD ' + oEnergestPod.Name + ' (' + oEnergestPod.Id + '): ' + oSaveResult);

                            List<String> listErrors = new List<String>();

                            for (Database.Error oError : oSaveResult.getErrors()) {

                                String sError = oError.getStatusCode() + ': ' + oError.getMessage();

                                if (!oError.getFields().isEmpty()) {
                                    sError += ', Field(s): ' + String.join(oError.getFields(), ', ');
                                }
                                listErrors.add(sError);
                            }

                            oEnergestEntityPod.setError(String.join(listErrors, '\n'));

                            // IMPORTANT to keep consistency concerning index
                            listEnergestSObjectWrappers.remove(iIndex);
                            listSObjectsToInsert.remove(iIndex);

                            System.debug(DEBUG_HERE + 'Remove index ' + iIndex + ', list size is now ' + listSObjectsToInsert.size());
                        }
                        else {
                            iIndex++;
                        }
                    }

                    if (!listSObjectsToInsert.isEmpty()) {

                        // Reinit SObjects
                        Set<String> lsetFields = listSObjectsToInsert.get(0).getPopulatedFieldsAsMap().keySet();
                        String sSoqlReinit = 'SELECT ' + String.join(new List<String>(lsetFields), ', ') + ' FROM ' + sSObjectName + ' WHERE Id IN :listSObjectsToInsert';
                        System.debug(DEBUG_HERE + 'Reinit: ' + sSoqlReinit);
                        listSObjectsToInsert = Database.query(sSoqlReinit);

                        iIndex = 0;

                        // Relate EnergestPod__c to SObjects
                        for (SObject oSObject : listSObjectsToInsert) {

                            EnergestSObjectWrapper oEnergestSObjectWrapper = listEnergestSObjectWrappers.get(iIndex);

                            oEnergestSObjectWrapper.reinitSObject(oSObject);

                            // Get related EnergestPod__c from the wrapper and set the lookup field
                            EnergestPod__c oEnergestPodToUpdate = oEnergestSObjectWrapper.parentEnergestEntityPod.oEnergestPod;

                            System.debug(DEBUG_HERE + 'Relate ' + oSObject.get('Id') + ' to ' + sLookupFieldName + ' on EnergestPod__c "' + oEnergestPodToUpdate.Name + '"');

                            oEnergestPodToUpdate.put(sLookupFieldName, oSObject.get('Id'));
                            iIndex++;
                        }
                    }
                    else {
                        System.debug(DEBUG_HERE + 'listSObjectsToInsert is not empty');
                    }
                }
            }
            else {
                System.debug(DEBUG_HERE + 'No related SObject to insert');
            }

            //------------------------------------------------------
            // Updates
            //------------------------------------------------------
            if (!mapSObjectsToUpdate.isEmpty()) {

                for (String sLookupFieldName : mapSObjectsToUpdate.keySet()) {

                    List<EnergestSObjectWrapper> listEnergestSObjectWrappers = mapSObjectsToUpdate.get(sLookupFieldName);
                    List<SObject> listSObjectsToUpdate = getSObjectsFromWrappers(listEnergestSObjectWrappers);

                    String sSObjectName = String.valueOf(listEnergestSObjectWrappers.get(0).oSObject.getSObjectType());

                    System.debug(DEBUG_HERE + 'Updating ' + listSObjectsToUpdate.size() + ' ' + sSObjectName + (listSObjectsToUpdate.size() > 1 ? 's' : '') + ': ' + listSObjectsToUpdate);

                    // Insert allowing partial success
                    List<Database.SaveResult> listSaveResults = Database.update(listSObjectsToUpdate, false); // allOrNone = false

                    Integer iIndex = 0;

                    for (Database.SaveResult oSaveResult : listSaveResults) {

                        EnergestSObjectWrapper oEnergestSObjectWrapper = listEnergestSObjectWrappers.get(iIndex);
                        EnergestEntityPod oEnergestEntityPod = oEnergestSObjectWrapper.parentEnergestEntityPod;
                        EnergestPod__c oEnergestPod = oEnergestEntityPod.oEnergestPod;

                        if (!oSaveResult.isSuccess()) {

                            System.debug(DEBUG_HERE + 'Error updating ' + sSObjectName + ' for POD ' + oEnergestPod.Name + ' (' + oEnergestPod.Id + '): ' + oSaveResult);

                            List<String> listErrors = new List<String>();

                            for (Database.Error oError : oSaveResult.getErrors()) {

                                String sError = oError.getStatusCode() + ': ' + oError.getMessage();

                                if (!oError.getFields().isEmpty()) {
                                    sError += ', Field(s): ' + String.join(oError.getFields(), ', ');
                                }
                                listErrors.add(sError);
                            }

                            oEnergestEntityPod.setError(String.join(listErrors, '\n'));

                            // IMPORTANT to keep consistency concerning index
                            listEnergestSObjectWrappers.remove(iIndex);
                            listSObjectsToUpdate.remove(iIndex);
                        }
                        else {
                            iIndex++;
                        }
                    }
                }
            }
            else {
                System.debug(DEBUG_HERE + 'No related SObject to update');
            }
        }

        System.debug(DEBUG_HERE + 'DMLs left: ' + this.getDmlStatementsLeft());
        System.debug(DEBUG_HERE + 'EnergestPod__c records to update:');

        List<EnergestPod__c> listEnergestPodsToUpdate = new List<EnergestPod__c>();

        // Sanitize EnergestPod__c records for update
        for (EnergestEntityPod oEnergestEntityPod : mapEnergestEntityPods.values()) {

            EnergestPod__c oEnergestPodToUpdate = this.getSanitizedEnergestPodForUpdate(oEnergestEntityPod.oEnergestPod);
            System.debug(DEBUG_HERE + JSON.serializePretty(oEnergestPodToUpdate.getPopulatedFieldsAsMap()));

            // Set checked date
            if (String.isBlank(oEnergestPodToUpdate.Error__c)) {
                oEnergestPodToUpdate.LastCheckedModifiedDatetime__c = oEnergestEntityPod.sourcePod.UpdatedDate;
            }

            listEnergestPodsToUpdate.add(oEnergestPodToUpdate);
        }

        // Update all handled EnergestPods
        update listEnergestPodsToUpdate;

        // Insert possible Cases
        List<Case> listCasesToInsert = new List<Case>();

        if (!EnergestEntityPod.mapDuplicateCaseByPodIds.isEmpty()) {
            System.debug(DEBUG_HERE + 'Insert ' + EnergestEntityPod.mapDuplicateCaseByPodIds.size() + ' Duplicate Case(s)');
            listCasesToInsert.addAll(EnergestEntityPod.mapDuplicateCaseByPodIds.values());
        }

        if (!EnergestEntityPod.listFuzzyCases.isEmpty()) {
            System.debug(DEBUG_HERE + 'Insert ' + EnergestEntityPod.listFuzzyCases.size() + ' fuzzy Case(s)');
            listCasesToInsert.addAll(EnergestEntityPod.listFuzzyCases);
        }

        if (!listCasesToInsert.isEmpty()) {
            insert listCasesToInsert;
        }

        return listEnergestPodsToUpdate;
    }

    /**
     *
     *
     * @param listEnergestSObjectWrappers
     *
     * @return
     */
    private static List<SObject> getSObjectsFromWrappers(List<EnergestSObjectWrapper> listEnergestSObjectWrappers) {

        List<SObject> listSObjects = new List<SObject>();

        for (EnergestSObjectWrapper oEnergestSObjectWrapper : listEnergestSObjectWrappers) {
            listSObjects.add(oEnergestSObjectWrapper.oSObject);
        }

        return listSObjects;
    }

    /**
     * Sanitizes a EnergestPod__c to be able to update
     *
     * Basically removes all __r references and DataAsJson__c
     *
     * @param oEnergestPod
     *
     * @return
     */
    private EnergestPod__c getSanitizedEnergestPodForUpdate(EnergestPod__c oEnergestPod) {


        Map<String, Object> mapValues = oEnergestPod.getPopulatedFieldsAsMap().clone();
        mapValues.remove('DataAsJson__c');

        for (String sFieldName : mapValues.keySet()) {
            if (Pattern.matches('.+__r', sFieldName)) {
                mapValues.remove(sFieldName);
            }
        }

        return (EnergestPod__c)JSON.deserialize(JSON.serialize(mapValues), EnergestPod__c.class);
    }

    /**
     * Get left DML statements
     *
     * @return
     */
    private Integer getDmlStatementsLeft() {
        return Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    }

    /**
     * Get left DML statements
     *
     * @return
     */
    private Integer getSoqlsLeft() {
        return Limits.getLimitQueries() - Limits.getQueries();
    }

    /**
     * finish()
     */
    public void finish(Database.BatchableContext batchableContext) {
    }

    class EnergestSynchronizerException extends Exception {}
}