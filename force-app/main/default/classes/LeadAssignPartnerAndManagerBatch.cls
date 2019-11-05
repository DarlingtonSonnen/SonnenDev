/**
 * LeadAssignPartnerAndManagerBatch
 *
 * Batch class to assign
 * - Area Managers (Users) and
 * - Partners (Accounts)
 * to Leads
 *
 * Tested by class "BatchTests"
 *
 * Changelog
 * ---------
 *
 * v1.4.1 (Polina Tsuban-Drobot 2018-04-10) - SOBCRM-1172
 * - fixed setting WasHandledByPartnerAssignBatch__c
 * - removed batch limit, instead of it set number of records we process per chunk
 * - removed execution only if number of jobs in progress is < 5
 *
 * v1.4.0 (Andrey Safronenko 2018-03-09) - SOBCRM-1153
 * - Partners assignment only if the TargetCountry is not Italy
 *
 * v1.3.0 (2017-02-13) - SOBCRM-795
 * - Batch scope query modified to retrieve only the Leads where at least PLZ is not null.
 *
 * v1.2.0 (2016-12-13)
 * - Added handling of Lead.WasHandledByPartnerAssignBatch__c and
 *   Lead.WasHandledByAreaManagerAssignBatch__c to check if already
 *   processed (see also SOBCRM-755)
 * - Handle only Leads which are not converted yet
 *
 * v1.0.1 (2016-10-13)
 * - Fix: execute() scheduled wrong job (d'oh)
 * - Added exception info string
 *
 * v1.0.0 (2016-10-11)
 * - Initial version
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @see https://interaktiv.jira.com/browse/SOBCRM-670
 * @see BatchTests
 * @version 1.0.0 (2016-10-11)
 */
global class LeadAssignPartnerAndManagerBatch implements Database.Batchable<SObject>,Database.Stateful,Schedulable {

    global string sMessage = '';

    public static final Integer MAX_JOBS = 5;
    public static final Integer RECORDS_PER_CHUNK = 50;

    public static final String DEBUG_HEADER = 'LeadAssignPartnerAndManager::';

    // SOBCRM-1153 - TargetCountry__c value for Italy area
    public static final String ITALY = 'IT';

    /**
     * execute() with SchedulableContext
     */
    global void execute(SchedulableContext SC) {
        Database.executeBatch(new LeadAssignPartnerAndManagerBatch(), RECORDS_PER_CHUNK);
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
                '    WasHandledByAreaManagerAssignBatch__c, ' +
                '    WasHandledByPartnerAssignBatch__c, ' +
                '    AssignSBC__c, ' +
                '    AreaManager__c, ' +
                '    PostalCode, ' +
                '    CountryCode, ' +
                '    Longitude, ' +
                '    Latitude, ' +
                '    TargetCountry__c ' + // SOBCRM-1153
                'FROM Lead ' +
                'WHERE ' +
                '    (' +
                '        (AssignSBC__c   = NULL AND WasHandledByPartnerAssignBatch__c     = false) OR ' +
                '        (AreaManager__c = NULL AND WasHandledByAreaManagerAssignBatch__c = false) ' +
                '    ) AND ' +
                '    PostalCode != NULL AND ' + // SOBCRM-795 - Batch Job sollte den Recommended Partner setzen nur wenn mindestens eine PLZ vorhanden ist.
                '    (' +
                '        (CountryCode != NULL) OR ' +
                '        (Longitude != NULL AND Latitude != NULL)' +
                '    ) AND ' +
                '    (WasHandledByAreaManagerAssignBatch__c = false OR WasHandledByPartnerAssignBatch__c = false) AND ' +
                '    IsConverted = false ' +
                'ORDER BY CreatedDate ASC';

        System.debug(DEBUG_HEADER + 'start() - SOQL: ' + sQuery);
        return Database.getQueryLocator(sQuery);
    }

    /**
     * execute() with BatchableContext
     */
    global void execute(Database.BatchableContext BC, List<SObject> scopeObjects) {

        List<Lead> listLeads = (List<Lead>) scopeObjects;
        Map<Id,Lead> mapLeadsToUpdate = new Map<Id,Lead>();

        try {

            Map<Id,Map<String,String>> mapObjectIdLocationsPartner     = new Map<Id,Map<String,String>>();
            Map<Id,Map<String,String>> mapObjectIdLocationsAreaManager = new Map<Id,Map<String,String>>();

            Map<Id,Lead> mapLeads = new Map<Id,Lead>();

            // Collect Leads for which to find Partners and/or Area Managers
            for (Lead oLead : listLeads) {

                Map<String,String> mapLocation = new Map<String,String>{
                    'postalCode'  => oLead.PostalCode,
                    'countryCode' => oLead.CountryCode,
                    'longitude'   => String.valueOf(oLead.Longitude),
                    'latitude'    => String.valueOf(oLead.Latitude)
                };

                // SOBCRM-1153
                // If Partner is not assigned AND Lead was not handled yet AND TargetCountry is not Italy
                if (oLead.AssignSBC__c == NULL && oLead.WasHandledByPartnerAssignBatch__c == FALSE && oLead.TargetCountry__c != ITALY) {
                    mapObjectIdLocationsPartner.put(oLead.Id, mapLocation);
                    mapLeads.put(oLead.Id, oLead);
                    System.debug(DEBUG_HEADER + 'execute() - added Lead ' + oLead.Name + ' (' + oLead.Id + ') for Partner search (AssignSBC__c = ' + oLead.AssignSBC__c + ', WasHandledByPartnerAssignBatch__c = ' + oLead.WasHandledByPartnerAssignBatch__c + ')');
                }
                // If AreaManager is not assigned AND Lead was not handled yet
                if (oLead.AreaManager__c == NULL && oLead.WasHandledByAreaManagerAssignBatch__c == FALSE) {
                    mapObjectIdLocationsAreaManager.put(oLead.Id, mapLocation);
                    mapLeads.put(oLead.Id, oLead);
                    System.debug(DEBUG_HEADER + 'execute() - added Lead ' + oLead.Name + ' (' + oLead.Id + ') for AreaManager search (AssignSBC__c = ' + oLead.AreaManager__c + ', WasHandledByPartnerAssignBatch__c = ' + oLead.WasHandledByAreaManagerAssignBatch__c + ')');
                }

                oLead.WasHandledByPartnerAssignBatch__c = TRUE;
                oLead.WasHandledByAreaManagerAssignBatch__c = TRUE;
            }

            //----------------------
            // Partner Accounts
            //----------------------
            if (!mapObjectIdLocationsPartner.isEmpty()) {

                Map<Id,List<AssignDelegate.FoundAccountWrapper>> foundAccounts = AssignDelegate.proposePartnerAccounts(mapObjectIdLocationsPartner);

                if (!foundAccounts.isEmpty()) {
                    for (Id idLead : foundAccounts.keySet()) {

                        Lead oLeadToUpdate = mapLeads.get(idLead);
                        List<AssignDelegate.FoundAccountWrapper> listFoundAccountWrappers = foundAccounts.get(idLead);

                        // Take only the first one
                        AssignDelegate.FoundAccountWrapper oFoundAccountWrapper = listFoundAccountWrappers.get(0);

                        oLeadToUpdate.AssignSBC__c          = oFoundAccountWrapper.account.Id;
                        oLeadToUpdate.AssignPartnerDebug__c = prepareDebugInfo(oFoundAccountWrapper.processInfo);

                        mapLeadsToUpdate.put(idLead, mapLeads.get(idLead));

                        this.sMessage += 'Set Partner Account for Lead ' + oLeadToUpdate.Name + ' (' + idLead + '): ' + oLeadToUpdate.AssignPartnerDebug__c + '\n';
                    }
                }
            }

            //----------------------
            // Area Managers
            //----------------------
            if (!mapObjectIdLocationsAreaManager.isEmpty()) {

                Map<Id, AssignDelegate.FoundAreaManagerWrapper> foundAreaManagers = AssignDelegate.proposeAreaManager(mapObjectIdLocationsAreaManager);

                if (!foundAreaManagers.isEmpty()) {
                    for (Id idLead : foundAreaManagers.keySet()) {

                        Lead oLeadToUpdate = mapLeads.get(idLead);
                        AssignDelegate.FoundAreaManagerWrapper oFoundAreaManagerWrapper = foundAreaManagers.get(idLead);

                        oLeadToUpdate.AreaManager__c            = oFoundAreaManagerWrapper.id;
                        oLeadToUpdate.AssignAreaManagerDebug__c = prepareDebugInfo(oFoundAreaManagerWrapper.processInfo);

                        mapLeadsToUpdate.put(idLead, mapLeads.get(idLead));

                        this.sMessage += 'Set Area Manager for Lead ' + oLeadToUpdate.Name + ' (' + idLead + '): ' + oLeadToUpdate.AssignAreaManagerDebug__c + '\n';
                    }
                }
            }

            update listLeads;

            if (!mapLeadsToUpdate.isEmpty()) {
                System.debug(DEBUG_HEADER + 'execute() - Found Partner/AreaManager for ' + mapLeadsToUpdate.size() + ' Lead(s): ' + mapLeadsToUpdate);
            }
            else {
                System.debug(DEBUG_HEADER + 'execute() - Nothing found');
            }
        }
        catch (Exception e) {
            String sException = e.getMessage() + '; ' + e.getStackTraceString();
            this.sMessage += e.getMessage();
            throw new LeadAssignPartnerAndManagerBatchException('Exception: ' + sException);
        }
    }

    /**
     * Prepare debug info
     */
    private String prepareDebugInfo(String debugInfo) {
        debugInfo = 'Set at ' + System.now() + ': ' + debugInfo;
        debugInfo = debugInfo.length() > 255 ? debugInfo.substring(0, 255) : debugInfo;
        return debugInfo;
    }


    /**
     * finish()
     */
    global void finish(Database.BatchableContext BC) {

        AsyncApexJob oApexJob = [
                SELECT
                        Id,
                        Status,
                        NumberOfErrors,
                        JobItemsProcessed,
                        TotalJobItems,
                        CreatedBy.Email
                FROM
                        AsyncApexJob
                WHERE Id = :BC.getJobId()
        ];

        if (oApexJob.CreatedBy.Email != NULL) {

            // Send an email to the Apex job's submitter notifying of job completion.
            Messaging.SingleEmailMessage oMail = new Messaging.SingleEmailMessage();

            String sToMail = oApexJob.CreatedBy.Email;
            String[] lToAddresses = new String[] {sToMail};

            System.debug('LeadAssignPartnerAndManagerBatch::finish() - Send email to ' + sToMail);

            this.sMessage += '\nTotal Leads: ' + oApexJob.TotalJobItems;
            this.sMessage += '\nProcessed Leads: ' + oApexJob.JobItemsProcessed;
            this.sMessage += '\nErrors: ' + oApexJob.NumberOfErrors;

            oMail.setToAddresses(lToAddresses);
            oMail.setSubject('Batch "LeadAssignPartnerAndManagerBatch" status: ' + oApexJob.Status);
            oMail.setPlainTextBody(this.sMessage);

            try {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{oMail});
            }
            catch (Exception e) {
                System.debug('LeadAssignPartnerAndManagerBatch::finish() - Sending failed. Error: ' + e.getMessage());
            }
        }
    }

    private class LeadAssignPartnerAndManagerBatchException extends Exception {}
}