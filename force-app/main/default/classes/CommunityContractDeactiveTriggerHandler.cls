/**
 * Before Update Trigger Handler for Community Contracts - prevents termination of a Community Contract
 * as long as there are related Energy/SonnenFlat Contracts active.
 *
 * @version    2016-12-06 dino.ursic@die-interaktiven.de        SOBCRM-261 - Kündigung Community Stromvertrag berücksichtigen
 * @version    2016-12-14 dino.ursic@die-interaktiven.de        SOBCRM-261 - Erweiterung auf Status 'Revoked'
 *                 
 */ 
public class CommunityContractDeactiveTriggerHandler extends TriggerHandler {
    
    private final String sDebugHeader = 'CommunityContractDeactivationTriggerHandler::';

    public override void beforeUpdate() {
        this.beforeUpsert();
    }    

    public void beforeUpsert() {
    
        Map<Id, Contract> triggerNewMap = (Map<Id, Contract>)trigger.newMap;
        Map<Id, Contract> triggerOldMap = (Map<Id, Contract>)trigger.oldMap;
        
        Map<Id, Contract> communityContractsWithECsMap = new Map<Id, Contract>([SELECT Id, Status, (SELECT Id, Status FROM EnergyContracts__r) FROM Contract WHERE Id IN :Trigger.newMap.keySet() AND RecordType.DeveloperName = 'Community']);
        
        for(Contract newCC : triggerNewMap.values()) {
        
            // Skip entire block if current Contract is not a Community Contract with related Energy Contracts
            if (!communityContractsWithECsMap.containsKey(newCC.Id))
              continue;
            
            // ignore if cancellation or termination or revoke is not attempted
            if (newCC.Status != 'Cancelled' && newCC.Status != 'Terminated' && newCC.Status != 'Revoked')
              continue;
              
            // also ignore if there is no status change (14.12.2016)
            if (newCC.Status == triggerOldMap.get(newCC.Id).Status)
                continue;
            
            Contract ccWithECs = communityContractsWithECsMap.get(newCC.Id);
            
            for(Contract ec : ccWithECs.EnergyContracts__r) {
              
                // If any of the related EnergyContracts is still active, prevent update of original Community Contract
                if(ec.Status == 'Activated') {
                  newCC.adderror('You cannot cancel or terminate a Community Contract as long as related active Energy or SonnenFlat Contracts exist!');
                  break;
                }
            }
        }               
    }
}