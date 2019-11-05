/**
* Batch for automatic reset of custom fields (AuthorizedMDF__c, MDPSubmitted__c, UsedMDF__c) on US Accounts on every January 2nd. 
* Only Accounts with at east one filled field should be affected.
*
* 2018-02-21 version 1.0  Muchow, Michael sonnen GmbH
*
* @version 1.0
*/

global class ResetUSAccountFieldsBatch implements Database.Batchable<sObject> {
    
global String query = 'Select ID, AuthorizedMDF__c, MDPSubmitted__c, UsedMDF__c ' + 
                      'FROM Account ' +
                      'WHERE RecordType.DeveloperName = \'SBC\' '+
                            'AND BillingCountryCode = \'US\' '+
                            'AND (AuthorizedMDF__c != NULL ' +
                            'OR MDPSubmitted__c != NULL ' +
                            'OR UsedMDF__c != NULL)';
                                
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope){

        System.debug(scope);

        List<Account> plansToReset = (List<Account>)scope;
        
        if (plansToReset.isEmpty())
            return;
        system.debug(plansToReset.size());

        List<Account> accountsToReset =  new List<Account>();

        for (Account rA : plansToReset){
            rA.AuthorizedMDF__c = NULL;
            rA.MDPSubmitted__c = NULL;
            rA.UsedMDF__c = NULL;
            accountsToReset.add(rA);
        }

        try {
            update accountsToReset;
        } catch (Exception e) {

            System.debug(System.LoggingLevel.ERROR, 'Batch not sucessfull '+ e.getMessage());
        }
    }    
        global void finish(Database.BatchableContext BC) {

        System.debug('Batch completed successfully!');
    }
}