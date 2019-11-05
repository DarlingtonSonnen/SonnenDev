/**
 * Batch for automatic Contract Activation after the Cancellation Period has passed.
 * Only Contracts with the RecordType 'Energy' or 'SonnenFlat' should be affected.
 *
 * @version    2016-12-02 dino.ursic@die-interaktiven.de        SOBCRM-694 - Batch Job Energy Contract Aktivierung
 * @version    2016-12-06 dino.ursic@die-interaktiven.de        SOBCRM-694 - Batch Job Energy Contract Aktivierung (only for Draft Contracts)
 *                 
 */ 
global without sharing class ContractActivationBatch implements Database.Batchable<sObject> {

    global String query = 'SELECT Id, RecordType.DeveloperName, Status, ' +
                              'EarliestActivationDate__c, ' + 
                              'IsInstallerSpezified__c, ' +
                              'IsPVSizeSpezified__c, ' +
                              'IsEnergyTariffClassified__c ' +
                        'FROM Contract ' + 
                        'WHERE EarliestActivationDate__c < TODAY ' + 
                        'AND Status = \'Draft\' ' + 
                        //'AND Status != \'Activated\' ' + 
                        'AND RecordType.DeveloperName IN (\'Energy\', \'SonnenFlat\')';
    
    /** START method */
    global Database.QueryLocator start(Database.BatchableContext BC) {
    
        return Database.getQueryLocator(query);
    }
  
    /** EXECUTE method */
    global void execute(Database.BatchableContext BC, List<sObject> scope) {
  
        system.debug(scope);
  
            
        // Get Contracts    
        List<Contract> unactivatedContracts = (List<Contract>)scope;
        if (unactivatedContracts.isEmpty())
            return;
            
        system.debug(unactivatedContracts.size());
        
        List<Contract> contractsToActivate = new List<Contract>();
            
        for (Contract c : unactivatedContracts) {
        
            // For SonnenFlat Contracts, all three checkboxes have to be true
            // to validate the Contract Activation (see VR: sonnenFlat_Activation_Validation)
            if (c.RecordType.DeveloperName == 'SonnenFlat' &&
               (c.IsInstallerSpezified__c == false || c.IsPVSizeSpezified__c == false || c.IsEnergyTariffClassified__c == false)) {
                
                continue;
            }
                
            // If above condition was not met, current Contract c can be activated
            c.Status = 'Activated';
            contractsToActivate.add(c);
        }
         
         
        update contractsToActivate;
    }
  
    /** FINISH method */
    global void finish(Database.BatchableContext BC) {
        //LogUtil log = new LogUtil();
        //log.info('ContractActivationBatch.finish()', 'Batch completed successfully!');
    }
}