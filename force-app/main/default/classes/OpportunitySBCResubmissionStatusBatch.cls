/**
 * Batch for setting Opportunities with Status "Resubmission" and a
 * ResubmissionDate__c to "Open" again if date is reached.
 * 
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @since 2016-06-15
 * @see https://interaktiv.jira.com/browse/SOBCRM-333
 */
global class OpportunitySBCResubmissionStatusBatch implements Database.Batchable<SObject>,Database.Stateful,Schedulable {
  
  	global string sMessage = '';
    
    public static final Integer MAX_JOBS = 5;
         	
    /**
     * execute() with SchedulableContext
     */
  	global void execute(SchedulableContext SC) {
        
    	Integer iJobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Processing'].size();
                
        if (iJobs < MAX_JOBS) {            
	        System.debug('OpportunitySBCResubmissionStatusBatch::execute(SchedulableContext) start');            
            LeadStatusLongTermToOpenBatch scheduledJob = new LeadStatusLongTermToOpenBatch();
            Database.executeBatch(scheduledJob);
        }
  	}
  	
    /**
     * start()
     */
  	global Database.QueryLocator start(Database.BatchableContext BC) {                
        // Query to find all Opportunities with Status "Resubmission" and past ResubmissionDate__c.
    	String sQuery = 'SELECT Id FROM Opportunity WHERE SBCStatus__c  = \'Resubmission\' AND ResubmissionDate__c  != NULL AND ResubmissionDate__c  <= TODAY';
		System.debug('OpportunitySBCResubmissionStatusBatch::start() - SOQL: ' + sQuery);    
       	return Database.getQueryLocator(sQuery);
  	}
  	
    /**
     * execute() with BatchableContext
     */
  	global void execute(Database.BatchableContext BC, List<SObject> scopeObjects) {
  		        
  		List<Opportunity> lOpportunities = (List<Opportunity>) scopeObjects;  		
        
        try {
            for (Opportunity oOpportunity : lOpportunities) {
            	oOpportunity.SBCStatus__c = 'open';    
            	oOpportunity.ResubmissionDate__c = NULL;    
            }
			System.debug('OpportunitySBCResubmissionStatusBatch::execute() - Update ' + lOpportunities.size() + ' Opportunity\'s SBCStatus__c to "Open"');
            update lOpportunities;
        } 
        catch (Exception e) {
			this.sMessage += e.getMessage();
        }        
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
                
            System.debug('OpportunitySBCResubmissionStatusBatch::finish() - Send email to ' + sToMail);
            
            this.sMessage += '\nTotal Leads: ' + oApexJob.TotalJobItems;
            this.sMessage += '\nProcessed Leads: ' + oApexJob.JobItemsProcessed;
            this.sMessage += '\nErrors: ' + oApexJob.NumberOfErrors;
            
            oMail.setToAddresses(lToAddresses);
            oMail.setSubject('Batch "OpportunitySBCResubmissionStatusBatch" status: ' + oApexJob.Status);
            oMail.setPlainTextBody(this.sMessage);
            
            try {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{oMail});
            }
            catch (Exception e) {
                System.debug('OpportunitySBCResubmissionStatusBatch::finish() - Sending failed. Error: ' + e.getMessage());    
            }                 
        }  
  	}
}