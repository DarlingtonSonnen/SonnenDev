/**
 * Batch for setting Leads with Status "Long Term" and a ReminderDate
 * to "Open" again if date is reached.
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @since 2016-06-14
 * @see https://interaktiv.jira.com/browse/SOBCRM-343
 * @see BatchTests
 *
 * Changelog
 * ---------
 * v1.0.0   2016-06-14  Marko Schmalenbach          Initial
 * v1.1.0   2017-09-19  Dino Ursic                  - Long Term Leads should be assigned to the original Lead Owner once the Reminder Date
 *                                                    has been reached. (SOBCRM-1065)
 *                                                  - If a user is inactive, the Leads should be reassigned to the Team Lead, to make sure
 *                                                    that Leads are handled with priority.
 *                                                  - Added OwnerId, Owner.IsActive, ManagerId fields to the original batch context query
 * v1.2.0   2018-12-11  Marko Schmalenbach          Allow partial update and raise an consolidated error Case for all failures (SOBCRM-1311)
 *
 *
 * v1.3.0	2019-06-28	Antonio Romero				- Added Owner and RecordType fields to the Case created from Metadata LeadCaseSetting
 *
 *
 */
global class LeadStatusLongTermToOpenBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    global static final Integer MAX_JOBS = 5;
    //global static final String ERROR_CASE_SUBJECT = 'Could not update Long Term Lead in batch';
    global static final String UNIT_TEST_DML_ERROR_LEAD_NAME = 'DML Error';

    private static final String DEBUG_HEADER = 'LeadStatusLongTermToOpenBatch.';

    /**
     * execute() with SchedulableContext
     */
    global void execute(SchedulableContext SC) {

        Integer iJobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Processing'].size();

        if (iJobs < MAX_JOBS) {
            System.debug(DEBUG_HEADER + 'execute(SchedulableContext) - Start with ' + MAX_JOBS + ' jobs');
            LeadStatusLongTermToOpenBatch scheduledJob = new LeadStatusLongTermToOpenBatch();
            Database.executeBatch(scheduledJob);
        }
    }

    /**
     * start()
     */
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Query to find all Leads with Status "Long Term" and past ReminderDate.
        // If you use a QueryLocator object, the governor limit for the total number
        // of records retrieved by SOQL queries is bypassed (up to 50 million records)
        String sQuery = 'SELECT Id, OwnerId, FirstName, LastName, Name ' +
                'FROM Lead ' +
                'WHERE Status = \'Long Term\' AND ReminderDate__c != NULL AND ReminderDate__c <= TODAY';
        System.debug(DEBUG_HEADER + 'start() - SOQL: ' + sQuery);
        return Database.getQueryLocator(sQuery);
    }

    /**
     * execute() with BatchableContext
     */
    global void execute(Database.BatchableContext BC, List<SObject> scopeObjects) {

        final String DEBUG_HERE = DEBUG_HEADER + 'execute() - ';
        List<Lead> listLeads = (List<Lead>) scopeObjects;

        Set<Id> leadOwnerIds = new Set<Id>();

        for (Lead oLead : listLeads) {
            leadOwnerIds.add(oLead.OwnerId);
        }

        Map<Id, User> mapLeadOwnersById = new Map<Id, User>([SELECT Id, IsActive, ManagerId FROM User WHERE Id IN :leadOwnerIds]);

        try {

            for (Lead oLeadToUpdate : listLeads) {

                oLeadToUpdate.Status = 'Open';
                oLeadToUpdate.ReminderDate__c = null;

                System.debug(DEBUG_HERE + 'Handle Lead "' + oLeadToUpdate.Name + '" (' + oLeadToUpdate.Id + ')');

                // Force DML error for UnitTest
                if (Test.isRunningTest() && oLeadToUpdate.Name == UNIT_TEST_DML_ERROR_LEAD_NAME) {
                    System.debug(DEBUG_HERE + 'Set CountryCode to something wrong for Lead "' + UNIT_TEST_DML_ERROR_LEAD_NAME + '"');
                    oLeadToUpdate.CountryCode = 'ERROR';
                }

                // SOBCRM-1065 - Skip if current lead is owned by Queue and not by a User
                if (!mapLeadOwnersById.containsKey(oLeadToUpdate.OwnerId)) {
                    continue;
                }

                // SOBCRM-1065 - If Lead's current Owner is deactivated, assign the lead to former Owner's Manager
                if (mapLeadOwnersById.get(oLeadToUpdate.OwnerId).IsActive == false) {
                    oLeadToUpdate.OwnerId = mapLeadOwnersById.get(oLeadToUpdate.OwnerId).ManagerId;
                }

            }

            System.debug(DEBUG_HERE + 'Update ' + listLeads.size() + ' Lead\'s Status to "Open" and ReminderDate__c to null');

            List<Database.SaveResult> listSaveResults = Database.update(listLeads, false); // allOrNone = false

            final String ERROR_SEPARATOR = '\n    • ';
            Integer iIndex = 0;
            List<Case> listCases = new List<Case>();

            for (Database.SaveResult oSaveResult : listSaveResults) {

                Lead oLead = listLeads.get(iIndex);
                Id idLead = oLead.Id;
                String sLeadName = '"' + oLead.Name + '" (' + idLead + ')';

                if (!oSaveResult.isSuccess()) {

                    System.debug(DEBUG_HERE + 'Error updating Lead ' + sLeadName + ' - ' + oSaveResult);

                    List<String> listErrors = new List<String>();

                    for (Database.Error oError : oSaveResult.getErrors()) {

                        String sError = oError.getStatusCode() + ': ' + oError.getMessage();

                        if (!oError.getFields().isEmpty()) {
                            sError += ', Field(s): ' + String.join(oError.getFields(), ', ');
                        }
                        listErrors.add(sError);
                    }

                    // Select the record metadata for the Case (Sales)
                    LeadCaseSetting__mdt sett = [SELECT Id, Case_Owner__c, Record_Type__c, Description__c, Priority__c, Status__c,Subject__c FROM LeadCaseSetting__mdt WHERE Label = :'Sales'].get(0);

                    listCases.add(new Case(
                            Subject = sett.Subject__c,
                            Description = sett.Description__c + sLeadName + ':' + ERROR_SEPARATOR + String.join(listErrors, ERROR_SEPARATOR),
                            Status = sett.Status__c,
                            Priority = sett.Priority__c,
                            Lead__c = oLead.Id,
                            OwnerId = sett.Case_Owner__c,
                            RecordTypeId = sett.Record_Type__c
                    ));
                } else {
                    System.debug(DEBUG_HERE + 'Lead ' + sLeadName + ' was successfully updated');
                }

                iIndex++;
            }

            if (!listCases.isEmpty()) {
                System.debug(DEBUG_HERE + 'Creating ' + listCases.size() + ' error Case(s)');
                insert listCases;
            }
        } catch (Exception e) {
            throw new LeadStatusLongTermToOpenBatchException(e);
        }
    }

    /**
     * finish()
     */
    global void finish(Database.BatchableContext BC) {
    }

    global class LeadStatusLongTermToOpenBatchException extends Exception {
    }
}