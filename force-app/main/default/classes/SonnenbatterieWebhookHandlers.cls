public class SonnenbatterieWebhookHandlers {
    
    public static void processCharge(StripeCharge charge, String status) {
        
        System.debug('DIA ENTRY - SonnenbatterieWebhookHandlers.processCharge');
        
        // SOBCRM-845 - StripeStatus not required on OppStaging anymore
        OppStaging__c [] lStagingObj = [
            SELECT 	Id, 
            		StripeCharge__c, 
            		StripeCustomerID__c	
            FROM 	OppStaging__c 
            WHERE 	StripeCharge__c = : charge.Id];
		OppStaging__c oStagingObj;
        
 		Opportunity [] opps;
        Opportunity o;
        
        Transfer__c[] trs;
        Transfer__c oTransfer;
        
        if (lStagingObj.size() == 1) {
            
            System.debug('DIA - SonnenbatterieWebhookHandlers.processCharge - found OppStaging');
            
            oStagingObj = lStagingObj[0];
            opps = [SELECT Id, StripeCharge__c, StripeCustomerID__c, StripeStatus__C FROM Opportunity WHERE /*Id*/OppStaging__c = : oStagingObj.id];
            
            // SOBCRM-845 - StripeStatus should be updated on Transfer rather than on OppStaging
            trs = [SELECT Id, StripeStatus__c FROM Transfer__c WHERE Order__r.OppStaging__c = :oStagingObj.Id];
        }
        else {
        	
            opps = [SELECT Id, StripeCharge__c, StripeCustomerID__c, StripeStatus__C FROM Opportunity WHERE StripeCharge__c = : charge.Id];
       }
        
        if (opps.size() == 1) {
            o = opps[0];
            
            // SOBCRM-845 - StripeStatus should be updated on Transfer rather than on OppStaging
            trs = [SELECT Id, StripeStatus__c FROM Transfer__c WHERE Order__r.OpportunityId = :o.Id];
        }
        if (trs.size() == 1) {
            system.debug('SonnenbatterieWebhookHandlers.processCharge() - found Transfer record: ' + trs[0]);
            oTransfer = trs[0];
        }
        
        System.debug('DIA ENTRY - SonnenbatterieWebhookHandlers.processCharge status =' + status);
        boolean failure = true;
        if (o != NULL) {
			
            o.StripeStatus__c = status ;
            update o;
            failure = false;
        }
        
        // SOBCRM-845 - StripeStatus should be updated on Transfer rather than on OppStaging
        if (/*oStagingObj*/oTransfer != NULL) {
			
            //oStagingObj.StripeStatus__c = status ;
            //update oStagingObj;
            oTransfer.StripeStatus__c = status;
            update oTransfer;
            failure = false;
        }
        
         System.debug('DIA EXIT - SonnenbatterieWebhookHandlers.processCharge');
        /*
        if (failure) {
            //StripeEvent.UnknownWebhookException ex =  new StripeEvent.UnknownWebhookException ();
        }*/
            
        // STATUS UPDATES FOR
        // - SUCCESS
        // - FAILED
        // - REFUNDED
        
    }
	
    public static void processCustomer(StripeCustomer customer, String status) {
        
        //StripeCard card = StripeCard.getCard(customer.default_card);
        System.debug('DIA ENTRY - SonnenbatterieWebhookHandlers.processCustomer');
        
        Account [] accs = [SELECT ID, StripeCustomerID__c, StripeCustomerStatus__c FROM Account WHERE StripeCustomerId__c = :customer.Id LIMIT 1];
        Account acc;
        
        if (!accs.isEmpty()) {
            acc = accs [0];
        }
        else {
            acc = NULL; 
        }
        
        if (acc != NULL) {
            acc.StripeCustomerStatus__c = status;
            update acc;
        } else {
            acc = new Account();
            acc.Name = customer.id;
            acc.StripeCustomerID__c = customer.id;
            acc.StripeCustomerStatus__c = status;
            insert acc;
        }
         System.debug('DIA EXIT - SonnenbatterieWebhookHandlers.processCustomer');
    }    
    
}