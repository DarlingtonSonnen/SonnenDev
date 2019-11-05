public class LumenazaBonusTriggerHandler extends TriggerHandler {
    
    public override void afterInsert() {
        this.upsertLumenazaBonus();
    }

    public override void beforeUpdate() {
        this.sendBonusToZuora();
    }
    
    public override void afterUpdate() {
        this.upsertLumenazaBonus();
    }
    
    public void upsertLumenazaBonus() {
        
        Set<LumenazaObject> lumenazaBonusesToInsert = new Set<LumenazaObject>();
                
        for (Bonus__c bonusAfter : (List<Bonus__c>) Trigger.new) {            
            // Instantiate a LumenazaBonus by a Bonus__c and add to list
            lumenazaBonusesToInsert.add(new LumenazaBonus(bonusAfter));
        }
                
        // If any LumenazaContract validates to false everything is rolled
        // back otherwise Contracts will be upserted if API Sync is active       
        if (lumenazaBonusesToInsert.size() > 0 && LumenazaApi.initUpsert(lumenazaBonusesToInsert) == false) {
            
            for (LumenazaObject lumenazaObject : lumenazaBonusesToInsert) {
                
                LumenazaBonus lumenazaBonus = (LumenazaBonus)lumenazaObject;
                
                if (lumenazaBonus.hasError() == true) {
                    lumenazaBonus.getBonus().addError(lumenazaBonus.getError());
                }
            }    
        }           
    }

    public void sendBonusToZuora() {
        // sends bonus to zuora, where it is added to subscription as amendment
        
        // custom metadata settings
        zuoraSetting__mdt settings;
        // 00D24000000opic and 00D24000000opicEAA are org Id of sonnen  Live org / production
        if(UserInfo.getOrganizationId() != '00D24000000opic' && UserInfo.getOrganizationId() != '00D24000000opicEAA') {
            settings = [SELECT BonusTriggerOn__c, Countries__c FROM zuoraSetting__mdt WHERE Label = 'Sandbox'];
        } else {
            settings = [SELECT BonusTriggerOn__c, Countries__c FROM zuoraSetting__mdt WHERE Label = 'Prod'];
        }

        if (settings.BonusTriggerOn__c || Test.isRunningTest()) {
            Map<Id, Bonus__c> oldMap = (Map<Id, Bonus__c>) Trigger.oldMap;
            Map<Id, Bonus__c> newMap = (Map<Id, Bonus__c>) Trigger.newMap;

            List<String> countries = settings.Countries__c.split(';');
            Set<String> countrySet = new Set<String>(countries);

            Map<Id, Bonus__c> newMapExtended = new Map<Id, Bonus__c>([SELECT Id, Contract__r.Account.BillingCountryCode FROM Bonus__c WHERE Id IN:newMap.keySet()]);

            List<Bonus__c> bonusToSync = new List<Bonus__c>();
  
            for (Id i : newMap.keySet()) {
                if (oldMap.get(i).Approval_Status__c != newMap.get(i).Approval_Status__c && newMap.get(i).Approval_Status__c == 'Approved'
                        && countrySet.contains(newMapExtended.get(i).Contract__r.Account.BillingCountryCode)) {

                    bonusToSync.add(newMap.get(i));
                }
            }
            ID jobID = System.enqueueJob(new zuoraIntegrationv2(bonusToSync));
        }
    }
}