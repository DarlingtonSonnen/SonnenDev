/**
* Schedule for automatic Reset US Account Fields Batch.
* Only Accounts with at east one filled field (AuthorizedMDF__c, MDPSubmitted__c, UsedMDF__c) should be affected.
*
* @see ResetUSAccountFieldsBatch.cls
* 
* 2018-02-20 version 1.0  Muchow, Michael sonnen GmbH
*
* @version 1.0
*/

global class ResetUSAccountFieldsBatchSchedule implements Schedulable {
    global void execute(SchedulableContext SC) {
        ResetUSAccountFieldsBatch raBatch = new ResetUSAccountFieldsBatch();
        Database.executeBatch(raBatch);
    }
}