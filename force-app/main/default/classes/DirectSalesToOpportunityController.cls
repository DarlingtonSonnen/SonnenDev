/**
 * Controller extension to handle requests from a list 
 * view button to assign records to an ambassador
 * 
 * Changelog:
 * 
 * v1.1.0 2016-08-09
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
public class DirectSalesToOpportunityController {
    
    Public static final String areaManagerProfileName = '* Area Manager';
        
    Public Boolean hasStopError {get; private set;}
    Public String teamSelect {get; set;}    
    Public String ambassdorSelect {get; set;}    
    
    Public List<Opportunity> selectedOpportunities;    
    
    Private Id recordTypeIdDirectSales;    
    Private List<selectOption> userSelection;
    
	/**
     * Constructor
     */
    public DirectSalesToOpportunityController(ApexPages.StandardSetController controller) {
        
        this.hasStopError = false;
    
        selectedOpportunities = (List<Opportunity>)controller.getSelected();
                
        if (selectedOpportunities.isEmpty()) {
	    	ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'No records selected!'));   
            this.hasStopError = true;
            return;
        }
        
        recordTypeIdDirectSales = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Opportunity', 'DirectSales');
        Id recordTypeIdPartnerSales = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Opportunity', 'Order');
        
        if (recordTypeIdDirectSales == NULL) {
	    	ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'RecordTypeId for "Direct Sales" (Dev.-Name "DirectSales") not found'));   
            this.hasStopError = true;
            return;            
        }
        if (recordTypeIdPartnerSales == NULL) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'RecordTypeId for "Partner Sales" (Dev.-Name "Order") not found'));   
            this.hasStopError = true;
            return;            
        }
        
        // Recollect Opportunities and get those with Partner or Direct Sales RecordType
        selectedOpportunities = [
            SELECT 
            	Id, Name, RecordTypeId, OwnerId 
            FROM 
            	Opportunity 
            WHERE 
            	Id IN :selectedOpportunities AND
            	(RecordTypeId = :recordTypeIdDirectSales OR RecordTypeId = :recordTypeIdPartnerSales)
        ];
        
        if (selectedOpportunities.isEmpty()) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Please select at least one Opportunity of Type "Direct Sales" or "Partner Sales"!'));   
            this.hasStopError = true;
        }
        
        List<selectOption> ambassadors = this.getAmbassadorSelections();
        
        if (ambassadors.isEmpty()) {
			ApexPages.addmessage(new ApexPages.message(ApexPages.severity.INFO, 'No Area Managers found, so team "Ambassador" is not selectable'));   			                            
        }
    }
    
    /**
     * Returns the select list for team
     */
    public List<selectOption> getTeamSelections(){   
        
        List<selectOption> ambassadors = this.getAmbassadorSelections();
        
        return new List<selectOption>{
        	new selectOption('Sales Management','Sales Management'),
            new selectOption('Ambassador','Ambassador', ambassadors.isEmpty())
        };
    }
    
    /**
     * Returns the select list of ambassadors
     */
    public List<selectOption> getAmbassadorSelections(){

        if (this.userSelection == NULL) {
            
            this.userSelection = new List<selectOption>();
            List<User> users = [SELECT Id, FirstName, LastName FROM User WHERE Profile.Name = :areaManagerProfileName ORDER BY LastName ASC];
            
            for (User user : users) {            
                String name = user.LastName + (user.FirstName != NULL ? ', ' + user.FirstName : '');
                this.userSelection.add(new selectOption(user.Id, name));       
            }            
        }
        
        return this.userSelection;   
	}
       
    /**
     * Action save
     */
    public PageReference save() {
        
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        
        // Update only changed Opportunities to keep previous timestamp
        // and save update operations
        for (Opportunity opportunity : selectedOpportunities) {
        	
            Boolean hasChange = false;
            
            if (opportunity.RecordTypeId != this.recordTypeIdDirectSales) {
            	opportunity.RecordTypeId = this.recordTypeIdDirectSales;     
                hasChange = true;
            }
            if (this.teamSelect == 'Ambassador' && this.ambassdorSelect != NULL && opportunity.OwnerId != this.ambassdorSelect) {
            	opportunity.OwnerId = this.ambassdorSelect;
                hasChange = true;
            }
            
            if (hasChange) {
            	opportunitiesToUpdate.add(opportunity);    
            }
        }
        
        if (!opportunitiesToUpdate.isEmpty()) {
            try {
                update opportunitiesToUpdate;
            }        
            catch(Exception e) {
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Couldn\'t update Opportunities: ' + e.getMessage()));   			
            }            
        }
            
        return new PageReference('/006');
    }    
}