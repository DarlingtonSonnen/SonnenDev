/**
 * LumenazaContractChangeBatch
 *
 * Batch to process all "new" Lumenaza Contracts changes.
 * 1. Get all Contracts wich have new changes
 * 2. In every execution get all changes of those Contracts
 * 3. Iterate over them and find the latest change for a field
 * 4. Sort them in to persist and to dimiss
 * 5. Trigger callouts for those to persist via LumenazaChange class
 *    and update with result
 * 6. Change the status of the ones to dismiss to "cancelled"
 *
 * Changelog
 * ---------
 *
 * v1.1.0 (2018-04-27)
 * - Bypass ContractTriggerHandler instead of deprecated LumenazaContractTriggerHandler
 *
 * v1.0.0 (2016-12-08)
 * - Initial version
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.0.0 (2016-12-08)
 */
global class LumenazaContractChangeBatch implements Database.Batchable<SObject>,Database.Stateful,Schedulable,Database.AllowsCallouts {

    public static final Integer MAX_JOBS = 5;
    public static final String DEBUG_HEADER = 'LumenazaContractChangeBatch.';

    /**
     * execute() with SchedulableContext
     */
    global void execute(SchedulableContext SC) {

        Integer iJobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Processing'].size();

        if (iJobs < MAX_JOBS) {
            System.debug(DEBUG_HEADER + 'execute(SchedulableContext) start with ' + MAX_JOBS + ' jobs');
            Database.executeBatch(new LumenazaContractChangeBatch());
        }
    }

    /**
     * start()
     */
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // If you use a QueryLocator object, the governor limit for the total number
        // of records retrieved by SOQL queries is bypassed (up to 50 million records)
        String sQuery =
            'SELECT ' +
            '    Id, ' +
            '    ContractNumber, ' +
            '    ChangesToProcess__c ' +
            'FROM ' +
            '    Contract ' +
            'WHERE ' +
            '    ChangesToProcess__c > 0';

        System.debug(DEBUG_HEADER + 'start() - SOQL: ' + sQuery);
        return Database.getQueryLocator(sQuery);
    }

    /**
     * execute() with BatchableContext
     */
    global void execute(Database.BatchableContext BC, List<SObject> scopeObjects) {

        String sDebugHere = DEBUG_HEADER + 'execute() - ';

        List<Contract> listContracts = (List<Contract>) scopeObjects;
        System.debug(sDebugHere + 'listContracts: ' + listContracts);

        // Get all changes with current status
        // By this we try to get all changes for each Contract (10000 will do)
        Map<Id,LumenazaContractChange__c> mapLumenazaContractChanges = new Map<Id,LumenazaContractChange__c>([
            SELECT
                Id,
                Name,
                Contract__c,
                OldValue__c,
                NewValue__c,
                Field__c,
                CreatedDate,
                Lumenaza_new_value__c,
                Lumenaza_changed_attribute__c,
                Lumenaza_consumer_id__c,
                Lumenaza_contract_id__c
            FROM
                LumenazaContractChange__c
            WHERE
                Status__c = 'new' AND
                Contract__c IN :listContracts
            ORDER BY
                CreatedDate ASC
            LIMIT 10000
        ]);

        // Sort changes to Contract
        Map<Id,List<LumenazaContractChange__c>> mapContractWithChanges = new Map<Id,List<LumenazaContractChange__c>>();

        for (LumenazaContractChange__c oChange : mapLumenazaContractChanges.values()) {
            Id idContract = oChange.Contract__c;
            if (mapContractWithChanges.get(idContract) == NULL) {
                mapContractWithChanges.put(idContract, new List<LumenazaContractChange__c>());
            }
            mapContractWithChanges.get(idContract).add(oChange);
        }

        // Final changes which are to persist
        List<LumenazaContractChange__c> listChangesToPersist = new List<LumenazaContractChange__c>();
        List<LumenazaContractChange__c> listChangesToDismiss = new List<LumenazaContractChange__c>();

        System.debug(sDebugHere + 'Handle ' + listContracts.size() + ' Contract(s)');

        // Iterate over each Contract which has changes to process
        for (Contract oContract : listContracts) {

            Map<Id,LumenazaContractChange__c> mapChangesToPersist = new Map<Id,LumenazaContractChange__c>();
            Map<Id,LumenazaContractChange__c> mapChangesToDismiss = new Map<Id,LumenazaContractChange__c>();

            Map<String,Map<String,String>> mapFieldValues = new Map<String,Map<String,String>>();

            // Iterate over each Change of the Contract which needs to be processed
            // and find the latest change for each field
            // Changes are sorted CreatedDate ASC so the last change counts.
            // If the latest change equals the oldest "oldValue" then the change must be dismissed.
            List<LumenazaContractChange__c> listChanges = mapContractWithChanges.get(oContract.Id);

            for (LumenazaContractChange__c oChange : listChanges) {

                String sField = oChange.Field__c;

                if (mapFieldValues.get(sField) == NULL) {
                    mapFieldValues.put(sField, new Map<String,String>{
                        'field' => sField,
                        'old' => oChange.OldValue__c
                    });
                }

                // Set latest value
                mapFieldValues.get(sField).put('new', oChange.NewValue__c);
                mapFieldValues.get(sField).put('changeToPersist', oChange.Id);
            }

            System.debug(sDebugHere + 'Handle changes for Contract ' + oContract.ContractNumber + ' (' + oContract.Id + ') with ' + mapFieldValues.values().size() + ' Changes :');

            // Check on Changes to persist and to dismiss
            for (Map<String,String> mapFieldValueForDismiss : mapFieldValues.values()) {

                // If old value != new value add change to persist
                String sOldValue = mapFieldValueForDismiss.get('old');
                String sNewValue = mapFieldValueForDismiss.get('new');
                String sField    = mapFieldValueForDismiss.get('field');
                Id idChange      = mapFieldValueForDismiss.get('changeToPersist');
                LumenazaContractChange__c oChange = mapLumenazaContractChanges.get(idChange);

                if (sNewValue != sOldValue) {
                    System.debug(sDebugHere + '    * Added change ' + oChange.Name + ' (' + idChange + ') for field "' + sField + '" ("' + sOldValue + '" -> "' + sNewValue + '"): ' + mapLumenazaContractChanges.get(idChange));
                    mapChangesToPersist.put(idChange,mapLumenazaContractChanges.get(idChange));
                }
                else {
                    System.debug(sDebugHere + '    * Changes for field "' + sField + '" can be dismissed as oldest and newest value are equal ("' + sOldValue + '")');
                    mapFieldValueForDismiss.put('dismissReason', 'noChangeOldestToNewest');
                }
            }

            // Get and process all changes which should be dismissed
            for (LumenazaContractChange__c oChange : listChanges) {
                if (mapChangesToPersist.get(oChange.Id) == NULL) {
                    mapChangesToDismiss.put(oChange.Id, oChange);
                }
            }

            // Iterate over the changes to dismiss and add some information with
            // setting the Status__c to "cancelled"
            if (!mapChangesToDismiss.isEmpty()) {

                System.debug(sDebugHere + '    ' + mapChangesToDismiss.size() + ' change(s) to dismiss:');
                Integer i = 0;

                for (LumenazaContractChange__c oChange : mapChangesToDismiss.values()) {

                    i++;
                    String sField = oChange.Field__c;
                    String dismissReason = mapFieldValues.get(sField).get('dismissReason');
                    Id idOverruleChange;
                    LumenazaContractChange__c oOverruleChange;

                    if (dismissReason == NULL) {
                        dismissReason = 'overruledByNewer';
                        idOverruleChange = mapFieldValues.get(sField).get('changeToPersist');
                        oOverruleChange = mapLumenazaContractChanges.get(idOverruleChange);
                    }

                    String dismissDescription = dismissReason + (idOverruleChange != NULL ? ' by change ' + oOverruleChange.Name + ' (' + idOverruleChange + ')' : '');
                    System.debug(sDebugHere + '        ' + i + '. ' + dismissDescription + ': ' + oChange.Name + ' (' + oChange.Id + ') created ' + oChange.CreatedDate + ' - field "' + sField + '", "' + oChange.OldValue__c + '" -> "' + oChange.NewValue__c + '"');

                    oChange.Status__c = 'cancelled';
                    oChange.StatusReason__c = dismissDescription;
                }

                // Add to global list
                listChangesToDismiss.addAll(mapChangesToDismiss.values());
            }
            else {
                System.debug(sDebugHere + '    No changes to dismiss');
            }

            // Add all changes to persist to a global list for later
            if (!mapChangesToPersist.isEmpty()) {

                System.debug(sDebugHere + '    ' + mapChangesToPersist.size() + ' change(s) to persist:');

                Integer i = 0;
                for (LumenazaContractChange__c oChange : mapChangesToPersist.values()) {
                    i++;
                    System.debug(sDebugHere + '        ' + i + '. Change ' + oChange.Name + ' (' + oChange.Id + ') created ' + oChange.CreatedDate + ' - field "' + oChange.Field__c + '" to "' + oChange.NewValue__c + '"');
                }

                // Add to global list
                listChangesToPersist.addAll(mapChangesToPersist.values());
            }
            else {
                System.debug(sDebugHere + '    No changes to persist');
            }
        } // end Iterate over each Contract

        //------------------------------------------------------------
        // CALLOUTS
        //------------------------------------------------------------
        // Limit: 100 callouts per transaction
        // -> Try to callout in Contract packages so that all changes
        //    for one contract are handled at once without breaking the
        //    callout limit
        System.debug(sDebugHere + listChangesToPersist.size() + ' changes to persist overall (in Contract bundles)');

        Map<Id, List<LumenazaContractChange__c>> mapContractToChanges = new Map<Id, List<LumenazaContractChange__c>>();

        // As a changeset can have no more changes than the count of
        // Lumenaza API fields we are in the limits even if there would
        // be only one Contract with changes
        for (LumenazaContractChange__c oChange : listChangesToPersist) {
            if (mapContractToChanges.get(oChange.Contract__c) == NULL) {
                mapContractToChanges.put(oChange.Contract__c, new List<LumenazaContractChange__c>());
            }
            mapContractToChanges.get(oChange.Contract__c).add(oChange);
        }

        List<LumenazaContractChange__c> listChangesToUpdate = new List<LumenazaContractChange__c>();

        // Loop over Contract IDs
        Integer i = 0;

        for (Id idContract : mapContractToChanges.keySet()) {

            i++;
            List<LumenazaContractChange__c> listContractChanges = mapContractToChanges.get(idContract);

            Integer iChanges = listContractChanges.size();
            Integer iCalloutLimitsLeft = Limits.getLimitCallouts() - Limits.getCallouts();

            System.debug(sDebugHere + '    #' + i + ' bundle for Contract "' + idContract + '" with ' + iChanges + ' change(s) and ' + iCalloutLimitsLeft + ' callout(s) left by limits');

            // Check if enough callouts would be left to make callouts
            // >= as one Callout is needed to get oauth token
            if (iChanges >= iCalloutLimitsLeft) {
                System.debug(sDebugHere + '        Left callouts < count of changes, break here');
                break;
            }

            Integer ii = 0;
            for (LumenazaContractChange__c oChange : listContractChanges) {

                ii++;
                LumenazaChange oLumenazaChange = new LumenazaChange(oChange);
                Boolean bSuccess = oLumenazaChange.persist();

                System.debug(sDebugHere + '            #' + ii + ' Callout for change ' + oChange.Name + ' (' + oChange.Id + ')');
                System.debug(sDebugHere + '                -> ' + (
                    bSuccess ?
                        'OK - Change ID retrieved: ' + oChange.LumenazaChangeId__c :
                        'Error - ' + oLumenazaChange.getError())
                );
            }

            listChangesToUpdate.addAll(listContractChanges);
        }

        // Now update all changes
        if (!listChangesToUpdate.isEmpty()) {
            update listChangesToUpdate;
        }

        //------------------------------------------------------------
        // DISMISS
        //------------------------------------------------------------
        System.debug(sDebugHere + listChangesToDismiss.size() + ' changes to dismiss overall');

        // Bypass ContractTriggerHandler which would be triggered again
        // because LumenazaContractChangeset__c is the detail part of the
        // master/detail relationship with Contract!
        TriggerHandler.bypass('ContractTriggerHandler');

        // Update to dismiss
        if (!listChangesToDismiss.isEmpty()) {
            for (LumenazaContractChange__c oChange : listChangesToDismiss) {
                System.debug(sDebugHere + '    * ' + oChange);
            }
            update listChangesToDismiss;
        }

        // Restore ContractTriggerHandler
        TriggerHandler.clearBypass('ContractTriggerHandler');

        System.debug(sDebugHere + 'finished');
    }

    /**
     * finish()
     */
    global void finish(Database.BatchableContext BC) {
    }

    private class LumenazaContractChangeBatchException extends Exception {}
}