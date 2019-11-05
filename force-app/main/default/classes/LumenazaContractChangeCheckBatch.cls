/**
 * LumenazaContractChangeCheckBatch
 *
 * Checks Lumeneaza Contract Changes with status "pending"
 * for status changes and updates them accordingly
 *
 * Changelog
 * ---------
 *
 * v1.0.0 (2016-12-13)
 * - Initial version
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.0.0 (2016-12-13)
 */
global class LumenazaContractChangeCheckBatch implements Database.Batchable<SObject>,Database.Stateful,Schedulable,Database.AllowsCallouts {

    public static final Integer MAX_JOBS = 5;
    public static final String DEBUG_HEADER = 'LumenazaContractChangeCheckBatch.';

    /**
     * execute() with SchedulableContext
     */
    global void execute(SchedulableContext SC) {

        Integer iJobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Processing'].size();

        if (iJobs < MAX_JOBS) {
            System.debug(DEBUG_HEADER + 'execute(SchedulableContext) start with ' + MAX_JOBS + ' jobs');
            Database.executeBatch(new LumenazaContractChangeCheckBatch());
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
            '    Name, ' +
            '    Status__c, ' +
            '    Contract__c, ' +
            '    LumenazaChangeId__c ' +
            'FROM ' +
            '    LumenazaContractChange__c ' +
            'WHERE ' +
            '    Status__c = \'pending\' ' +
            'ORDER BY ' +
            '    CreatedDate ASC';

        System.debug(DEBUG_HEADER + 'start() - SOQL: ' + sQuery);
        return Database.getQueryLocator(sQuery);
    }

    /**
     * execute() with BatchableContext
     */
    global void execute(Database.BatchableContext BC, List<SObject> scopeObjects) {

        String sDebugHere = DEBUG_HEADER + 'execute() - ';

        List<LumenazaContractChange__c> listChanges = (List<LumenazaContractChange__c>) scopeObjects;
        List<Case> listCases = new List<Case>();

        System.debug(sDebugHere + 'Handle ' + listChanges.size() + ' change(s)');

        for (LumenazaContractChange__c oChange : listChanges) {

            LumenazaChange oLumenazaChange = new LumenazaChange(oChange);
            Boolean bSuccess = oLumenazaChange.checkOnResult();

            System.debug(sDebugHere + 'Change: ' + oChange);

            // Create Case on these statuses
            if (oChange.Status__c == 'error' || oChange.Status__c == 'rejected') {

                Case oCase = oLumenazaChange.prepareErrorCase();
                oCase.Contract__c = oChange.Contract__c;
                oCase.LumenazaContractChange__c = oChange.Id;
                oCase.subject = 'Contract Change failed';
                oCase.description  = 'Status "' + oChange.Status__c +'", ' + oChange.StatusReason__c;

                if (oLumenazaChange.hasError()) {
                    oCase.description += '\n\nError: ' + oLumenazaChange.getError();
                }

                listCases.add(oCase);
            }
        }

        update listChanges;

        if (!listCases.isEmpty()) {
            insert listCases;
        }
    }

    /**
     * finish()
     */
    global void finish(Database.BatchableContext BC) {
    }

    private class LumenazaContractChangeCheckBatchException extends Exception {}
}