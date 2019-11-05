/**
 * Batch for migration of geo information from PostalCodeArea to MapAnythingTerritory Geometry object.
 *
 * @version    2017-01-30 dino.ursic@die-interaktiven.de        SOBCRM-752 - MapAnything Trigger für die Erstellung eines Manager-Territory (Teil 2: Datenmigration)
 * @version    2017-04-26 dino.ursic@die-interaktiven.de        SOBCRM-844 - MapAnything Trigger für die Erstellung eines Partner-Territory (Teil 2: Datenmigration)
 */ 
global without sharing class PostalCodeAreaDataMigrationBatch implements Database.Batchable<sObject> {

    global String query = 'SELECT Id, Name, OwnerId, AssignedPartner__c, Country__c ' +
                        'FROM PostalCodeArea__c';
    
    /** START method */
    global Database.QueryLocator start(Database.BatchableContext BC) {
    
        return Database.getQueryLocator(query);
    }
  
    /** EXECUTE method */
    global void execute(Database.BatchableContext BC, List<sObject> scope) {
    
        // Bypass irrelevant triggers:
        //TriggerHandler.bypass('PostalCodeAreaTriggerHandler');
        
        PostalCodeAreaTriggerHandler pcaTriggerHandler = new PostalCodeAreaTriggerHandler();
            
        // Get PostalCodeArea records    
        List<PostalCodeArea__c> allPCAs = (List<PostalCodeArea__c>)scope;
        if (allPCAs.isEmpty())
            return;

        Map<Id, Set<String>> geometryCodesAssignedToOwner = new Map<Id, Set<String>>();
        Map<Id, Set<String>> geometryCodesRemovedFromOwner = new Map<Id, Set<String>>();
        Map<Id, Set<String>> geometryCodesAssignedToPartner = new Map<Id, Set<String>>();
        Map<Id, Set<String>> geometryCodesRemovedFromPartner = new Map<Id, Set<String>>();
        
        for (PostalCodeArea__c pca : allPCAs) {
            // If the map does not yet have an entry with the key pca.ownerId, create an empty set for that key
            if(!geometryCodesRemovedFromOwner.containsKey(pca.OwnerId))
                geometryCodesRemovedFromOwner.put(pca.OwnerId, new Set<String>()); 
            
            // If the map does not yet have an entry with the key pca.ownerId, create an empty set for that key
            if(!geometryCodesAssignedToOwner.containsKey(pca.OwnerId))
                geometryCodesAssignedToOwner.put(pca.OwnerId, new Set<String>());
                
            // Add Geometry Code (format 'DE-35567') to the Set of removed PostalCodes for the oldPCA.OwnerId
            geometryCodesRemovedFromOwner.get(pca.OwnerId).add(PostalCodeAreaTriggerHandler.getGeometryCodeFromPostalCodeArea(pca));
            // Add Geometry Code (format 'DE-35567') to the Set of newly added PostalCodes for the newPCA.OwnerId
            geometryCodesAssignedToOwner.get(pca.OwnerId).add(PostalCodeAreaTriggerHandler.getGeometryCodeFromPostalCodeArea(pca));
            
            // Skip processing for AssignedPartners if the PCA has no partner assigned
            if (pca.AssignedPartner__c == null)
                continue;
            
            // If the map does not yet have an entry with the key pca.AssignedPartner__c, create an empty set for that key
            if(!geometryCodesRemovedFromPartner.containsKey(pca.AssignedPartner__c))
                geometryCodesRemovedFromPartner.put(pca.AssignedPartner__c, new Set<String>()); 
            
            // If the map does not yet have an entry with the key pca.AssignedPartner__c, create an empty set for that key
            if(!geometryCodesAssignedToPartner.containsKey(pca.AssignedPartner__c))
                geometryCodesAssignedToPartner.put(pca.AssignedPartner__c, new Set<String>());
            
            // Add Geometry Code (format 'DE-35567') to the Set of removed PostalCodes for the oldPCA.AssignedPartner__c
            geometryCodesRemovedFromPartner.get(pca.AssignedPartner__c).add(PostalCodeAreaTriggerHandler.getGeometryCodeFromPostalCodeArea(pca));
            // Add Geometry Code (format 'DE-35567') to the Set of newly added PostalCodes for the newPCA.AssignedPartner__c
            geometryCodesAssignedToPartner.get(pca.AssignedPartner__c).add(PostalCodeAreaTriggerHandler.getGeometryCodeFromPostalCodeArea(pca));
        }
        
        try {
            //pcaTriggerHandler.removePostalCodesFromOwner(geometryCodesRemovedFromOwner);
            pcaTriggerHandler.assignPostalCodesToOwner(geometryCodesAssignedToOwner);
            //pcaTriggerHandler.removePostalCodesFromPartner(geometryCodesRemovedFromPartner);
            pcaTriggerHandler.assignPostalCodesToPartner(geometryCodesAssignedToPartner);
        }
        catch(Exception ex) {
            system.debug(ex.getMessage());
            system.debug(ex.getStackTraceString());
        }
        
        //TriggerHandler.clearBypass('PostalCodeAreaTriggerHandler');      
    }
  
    /** FINISH method */
    global void finish(Database.BatchableContext BC) {
        //LogUtil log = new LogUtil();
        //log.info('ContractBankDatMigrationBatch.finish()', 'Batch completed successfully!');
    }
}