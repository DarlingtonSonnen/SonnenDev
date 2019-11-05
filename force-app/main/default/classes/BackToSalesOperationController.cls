/**
 * Controller extension to handle requests from a list view 
 * button to assign records to an ambassador
 * 
 * Changelog:
 * 
 * v1.1.0 2016-08-08
 * - Revision (MSB)
 * 
 * v1.0.0 2016-08-04
 * - Initial by Damola
 * 
 * @author damola <damola@die-interaktiven.de>
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.1.0 2016-08-09
 * @see https://interaktiv.jira.com/browse/SOBCRM-504
 **/   
public class BackToSalesOperationController {

    public String selection{get;set;}
    public String descField{get;set;}
    
    public boolean hasStopError {public get; private set;}
   
    public Opportunity opportunity;
    
    private Id opportunityRecordTypePartnerSales;
    
    /**
     * Constructor
     */
    public BackToSalesOperationController(ApexPages.StandardController controller) {
         
        this.opportunity = (Opportunity)controller.getRecord();
        
        // Get RecordType
        this.opportunityRecordTypePartnerSales = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Opportunity', 'Order');
        
        if (this.opportunityRecordTypePartnerSales == NULL) {
	    	ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Opportunity Record Type "Partner Sales" (aka. "Order") is not available'));   
            this.hasStopError = true;            
        }
    }
    
    /**
     * Returns the select list for reason
     */
    public List<selectOption> getReasonSelection() {
    
        List<selectOption> picklist= new List<selectOption>();
        
        picklist.add(new selectOption('Closed Won - Customer made deposit','Closed Won - Customer made deposit'));        
        picklist.add(new selectOption('Closed Lost - Pricelevel','Closed Lost - Pricelevel'));
        picklist.add(new selectOption('Closed Lost - Product does not fulfill the customers technical requirements','Closed Lost - Product does not fulfill the customers technical requirements'));
        picklist.add(new selectOption('Closed Lost - Bought competitor\'s product','Closed Lost - Bought competitor\'s product'));
        picklist.add(new selectOption('Closed Lost - Decision postponed','Closed Lost - Decision postponed'));
        picklist.add(new selectOption('Closed Lost - No answer','Closed Lost - No answer'));
        picklist.add(new selectOption('Closed Lost - Other','Closed Lost - Other'));
        
        return picklist;
    }
    
	/**
	 * Action save
	 */    
    public PageReference save() {
    
		Task completedTask = new Task(
            Subject = this.selection,
            Status = 'Completed',
            WhatId = this.opportunity.Id
        );
        
       	if (this.selection == 'Closed Lost - Other') {       
                        
            String description = this.descField == NULL ? '' : this.descField.trim();            
            
            if (description.length() == 0) {
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Please insert a description!'));
                this.descField = '';
                return ApexPages.currentPage();    		                        
            }
			
            completedTask.Description = description;
		}
        
        // Change RecordType of Opportunity to "Partner Sales"
        this.opportunity.RecordTypeId = this.opportunityRecordTypePartnerSales;
        this.opportunity.StageName = 'Open';
       
        Savepoint eineSchritteSuruck = Database.setSavepoint();
        
        try {
            update this.opportunity;
       		insert completedTask;            
        }
        catch (Exception e) {
            Database.rollback(eineSchritteSuruck);
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Could not create Task or update Opportunity: ' + e.getMessage()));
            return ApexPages.currentPage();    		        
        }        
        
        return new PageReference('/' + this.opportunity.Id);
    }    
}