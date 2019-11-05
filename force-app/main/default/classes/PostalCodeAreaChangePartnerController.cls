/**
 * SOBCRM-837
 *
 * @author dino.ursic@die-interaktiven.de
 */
public class PostalCodeAreaChangePartnerController {

    ApexPages.StandardSetController stdSetController;
    
    public PostalCodeArea__c selectedPostalCodeArea { get; set; }
    
    public PostalCodeAreaChangePartnerController(ApexPages.StandardSetController stdSetController) {
        this.stdSetController = stdSetController;
        this.selectedPostalCodeArea = new PostalCodeArea__c();
        
        if(stdSetController.getSelected().size() == 0) {
            // page messages - no PCA selected
            ApexPages.Message warnMsg = new ApexPages.Message(ApexPages.Severity.INFO, 'No records selected');
            ApexPages.addMessage(warnMsg);
        }
        
        if(stdSetController.getSelected().size() == 1) {
            Id selectedRecordId = ((PostalCodeArea__c[])stdSetController.getSelected())[0].Id;
            selectedPostalCodeArea = [SELECT Id, Name, AssignedPartner__r.Id FROM PostalCodeArea__c WHERE Id = :selectedRecordId LIMIT 1];
        }
    }
    
    public String getSectionHeaderSubtitle() {
        if(stdSetController.getSelected().size() == 1)
            return selectedPostalCodeArea.Name;
        
        return 'Mass Partner Assignment';
    }
    
    public PageReference doSave() {
        
        for(PostalCodeArea__c pca : (PostalCodeArea__c[])stdSetController.getSelected()) {
            pca.AssignedPartner__c = selectedPostalCodeArea.AssignedPartner__c;
        }
        update (PostalCodeArea__c[])stdSetController.getSelected();
        
        return new ApexPages.Action('{!List}').invoke();
    }
    
    public PageReference doCancel() {
        return new ApexPages.Action('{!List}').invoke();
    }
}