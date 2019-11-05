/**
 * LeadTriggerHandler
 *
 * Changelog
 * ---------
 * v1.2.0 (MSB, 2017-01-04)
 * - Added resetHandledByAssignBatch() (SOBCRM-755)
 *
 * v1.3.0 (KKO, 2017-06-06)
 * - Added checkForDuplicates() (SOBCRM-967)
 * 
 * v1.4.0 (DUR, 2017-08-02)
 * - Recommended Parter aktualisieren bei Adressänderung auf Lead (SOBCRM-1020)
 * - Reset AssignSBC__c, AreaManager__c, WasHandledByPartnerAssignBatch__c, WasHandledByAreaManagerAssignBatch__c on PostalCode change
 *   to force Leads to be re-processed by LeadAssignPartnerAndManagerBatch
 *
 * @version 1.4.0 (2017-08-02)
 * 
 * @version 1.5.0 (2017-09-11) SOBCRM-1062
 * @desc Referral and Lead Conversion / validation.
 *
 * @version 1.6.0 (2017-09-12) SOBCRM-1061
 * @desc Setting postal Code Exclusivity
 */
public class LeadTriggerHandler extends TriggerHandler {

    private static final String DEBUG_HEADER = 'LeadTriggerHandler.';

    private static final Map<String, Id> supplierToAccounts;
    
    /**
     * afterInsert
     */
    public override void afterInsert() {
    	this.insertCampaignMember();
        this.setTerritorialExclusivity();
    }

    public override void afterUpdate() {
    	this.setAccountOnReferral();
        this.setTerritorialExclusivity();
    }    
    
    public override void beforeInsert() {
        this.checkForDuplicates();
        this.setSupplier();
        this.setTargetCountry();
        this.setLanguage(); // Call AFTER setTargetCountry!
    }

    public override void beforeUpdate() {
        this.setSupplier();
        this.setTargetCountry();
        this.resetHandledByAssignBatch();
    }

	static {
        supplierToAccounts = new Map<String, Id>(populateSuppliers());
    }

    /**
     * Resets the handled flags and assignments on unconverted Lead's
     * address change
     *
     * Tested by GeneralTriggerTests
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-755
     */
    public void resetHandledByAssignBatch() {

        String sDebugHere = DEBUG_HEADER + 'resetHandledByAssignBatch() - ';

        for (Lead oLead : (List<Lead>) Trigger.new) {

            if (oLead.IsConverted == FALSE && (oLead.WasHandledByAreaManagerAssignBatch__c == TRUE || oLead.WasHandledByPartnerAssignBatch__c == TRUE)) {

                Lead oLeadBefore = (Lead)Trigger.oldMap.get(oLead.Id);

                System.debug(sDebugHere + 'Change in geo location? ' + oLead.Longitude + ' != ' + oLeadBefore.Longitude + ', ' + oLead.Latitude + ' != ' + oLeadBefore.Latitude);

                // If address fields changed (Longitude and Latitude are changed afterwards by Salesforce!)
                if (
                    oLead.Street != oLeadBefore.Street ||
                    oLead.City != oLeadBefore.City ||
                    oLead.PostalCode != oLeadBefore.PostalCode ||
                    oLead.CountryCode != oLeadBefore.CountryCode) {

                    System.debug(sDebugHere + 'YES');

                    oLead.WasHandledByPartnerAssignBatch__c     = FALSE;
                    oLead.WasHandledByAreaManagerAssignBatch__c = FALSE;

                    if (oLead.AssignSBC__c != NULL) {
                        oLead.AssignPartnerDebug__c = 'Reset from ' + oLead.AssignSBC__c + ' due to address change';
                    }
                    if (oLead.AreaManager__c != NULL) {
                        oLead.AssignAreaManagerDebug__c = 'Reset from ' + oLead.AreaManager__c + ' due to address change';
                    }

                    oLead.AssignSBC__c   = NULL;
                    oLead.AreaManager__c = NULL;
                }
                else {
                    System.debug('NO');
                }
            }
        }
    }
       
    /**
     * Set language from country
     * 
     * Country to language mapping is done via Custom Setting 
     * CountryToLanguageMapping__c. The one with name "default"
     * marks the default language which is set if target country
     * has no mapping.
     * 
     * @see https://interaktiv.jira.com/browse/SOBCRM-491
     */ 
    public void setLanguage() {

		CountryToLanguageMapping__c oMappingDefaultLanguage = CountryToLanguageMapping__c.getValues('default');
        
        for (Lead oLead : (List<Lead>) Trigger.new) {
            
            if (oLead.Language__c == NULL) {                

                // Set default language
                if (oMappingDefaultLanguage != NULL && oMappingDefaultLanguage.LanguageISOCode__c != NULL) {
                	oLead.Language__c = oMappingDefaultLanguage.LanguageISOCode__c;                      
                }
                
                // Try to set language via country to language mapping
                // if TargetCountry__c is set
                if (oLead.TargetCountry__c != NULL) {
                    
                    CountryToLanguageMapping__c oMapping = CountryToLanguageMapping__c.getValues(oLead.TargetCountry__c.toUpperCase());
                    
                    if (oMapping != NULL && oMapping.LanguageISOCode__c	!= NULL) {
                        oLead.Language__c = oMapping.LanguageISOCode__c;  
                    }                    
                }
            }
        }    	    
    }
    
    /**
     * Inserts a "Campaign Member" for every Lead's 
     *  - ApiCampaign__c or
     *  - ApiSecondCampaign__c
     * value. Those fields are string(255) have to hold valid
     * Campaign-IDs.
     */
    public void insertCampaignMember() {
        
        Map<Id, Set<Lead>> campaignToLeads = new Map<Id, Set<Lead>>();
        
        for (Lead leadAfter : (List<Lead>) Trigger.new) {
            
            // These are normal text fields so we have to check
            // if their values are valid campaign IDs
            if (this.isCampaignId(leadAfter.ApiCampaign__c)) {
                this.addToMap(campaignToLeads, (Id)leadAfter.ApiCampaign__c, leadAfter);
            }
            if (this.isCampaignId(leadAfter.ApiSecondCampaign__c)) {
                this.addToMap(campaignToLeads, (Id)leadAfter.ApiSecondCampaign__c, leadAfter);
            }            
        }
        
        if (!campaignToLeads.isEmpty()) {
            
        	List<CampaignMember> campaignMembersToInsert = new List<CampaignMember>();
            List<Id> campaignIds = new List<Id>(campaignToLeads.keySet());
            
            try {
                // Find campaigns
                List<Campaign> campaigns = [SELECT Id FROM Campaign WHERE Id IN :campaignIds];
                
                // Create memberships
                for (Campaign campaign : campaigns) {
                    
                	Set<Lead> leadsToLink = campaignToLeads.get(campaign.Id);
                    
                    for (Lead lead : leadsToLink) {
                        campaignMembersToInsert.add(new CampaignMember(
                            LeadId     = lead.Id,
                            CampaignId = campaign.Id
                        ));
                    }
                }
                // Insert CampaignMembers
                if (!campaignMembersToInsert.isEmpty()) {
                    insert campaignMembersToInsert;
                }                    
            }
            catch (Exception e) {                
            	System.debug('LeadTriggerHandler::insertCampaignMember(): Exception on inserting CampaignMembers: ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
            }
        }
    } 

    /**
     * if leadsource is a supplier in the supplier list, fill the appropriate lookup field
     * 
     * @see https://interaktiv.jira.com/browse/SOBCRM-469
     * 
     * @author Daniel Stange <daniel.stange@die-interaktiven.de>
     * 
     */

     private void setSupplier() {

        System.debug('LeadTriggerHandler::setSupplier');

        Map<String, Id> supplierMap = new Map<String, Id>();

        List<Account> suppliers = [SELECT Id, SupplierNo__C FROM Account WHERE SupplierNo__c != NULL];

        for (Account a : suppliers) {

            supplierMap.put(a.SupplierNo__c, a.Id);
        }

        system.debug('suppliers:' + supplierMap);

        for (Lead l : (List<Lead>) Trigger.new) {

            if (l.Supplier__c == NULL 
                && l.RecordSource__c != NULL 
                && supplierMap.containsKey(l.RecordSource__c)) {
                system.debug('searching:' + l.RecordSource__c);
                
                l.Supplier__c = supplierToAccounts.get(l.RecordSource__c);
            }
        }
     }

     private void checkForDuplicates() {

        // map with all new lead amails related to all new lead records 
        Map<String,List<Lead>> emailToLeadMap = new Map<String,List<Lead>>();


        for (Lead newLead : (List<Lead>) Trigger.new) {

            if(!String.isBlank(newLead.Email)) {

                if(!emailToLeadMap.containsKey(newLead.Email)) {

                    List<sObject> valueList = new List<sObject>();
                    valueList.add(newLead);
                    emailToLeadMap.put(newLead.Email, valueList);
                } else {
                
                    emailToLeadMap.get(newLead.Email).add(newLead);
                }
            }
        }

        List<Lead> oldLeadList = [  SELECT  Id,
                                            Email
                                    FROM    Lead 
                                    WHERE   Email IN :emailToLeadMap.keySet()];

        List<Contact> oldConList = [SELECT  Id,
                                            Email
                                    FROM    Contact 
                                    WHERE   Email IN :emailToLeadMap.keySet()];

        if(!oldLeadList.isEmpty() || !oldConList.isEmpty()) {

            List<Group> duplicateGroup = [  SELECT  Id 
                                            FROM    Group 
                                            WHERE   Name = 'Duplicates'
                                            LIMIT   1];

            for(Lead oldLead : oldLeadList) {

                List<Lead> duplicateLeadList = emailToLeadMap.get(oldLead.Email);

                for(Lead duplicateLead : duplicateLeadList) {

                    duplicateLead.Status = 'Duplicate';
                    if(!duplicateGroup.isEmpty()) {
                        
                        duplicateLead.OwnerId = duplicateGroup[0].Id;
                    }
                }
            }

            for(Contact oldContact : oldConList) {

                List<Lead> duplicateLeadList = emailToLeadMap.get(oldContact.Email);

                for(Lead duplicateLead : duplicateLeadList) {

                    duplicateLead.Status = 'Duplicate';
                    if(!duplicateGroup.isEmpty()) {
                        
                        duplicateLead.OwnerId = duplicateGroup[0].Id;
                    }
                }
            }
        }
     }

     /**
     * If target country is not set, but other indicators for the target country exist,
     * - use country code value as target country
     * - use the target country of the related campaign (ApiCampaign__c) 
     * to set the target country  
     * 
     * @see https://interaktiv.jira.com/browse/SOBCRM-454
     * @author Daniel Stange <daniel.stange@die-interaktiven.de>
     */
     private void setTargetCountry() {

        Set<ID> campaignIds = new Set<ID>();
        Map<Id, Campaign> campaigns;

        for (Lead l : (List<Lead>) Trigger.new) {

            if (l.ApiCampaign__c != NULL && l.ApiCampaign__c != '') {

                if (isCampaignId(l.ApiCampaign__c)) {
                    campaignIds.add(l.ApiCampaign__c);
                }  
                else {
                    l.ApiCampaign__c = NULL;
                }              
            }
        }

        system.debug('campaignIds:' + campaignIds);

        campaigns = new Map<Id, Campaign>([
            SELECT  Id,
                    TargetCountry__c
            FROM    Campaign
            WHERE   Id IN: campaignIds
            AND     TargetCountry__c != NULL
            ]);

        system.debug('campaigns:' + campaigns);
         
        for (Lead l : (List<Lead>) Trigger.new) {

            system.debug('searching:' + l.ApiCampaign__c);

            if (l.TargetCountry__c == '' || l.TargetCountry__c == NULL) {

                if (l.CountryCode != NULL && l.CountryCode != '') {
                    l.TargetCountry__c = l.CountryCode;
                }

                else if (l.ApiCampaign__c != NULL && l.ApiCampaign__c != '' && campaigns.containsKey(l.ApiCampaign__c)) {

                    if (isCampaignId(l.ApiCampaign__c)) {
                        l.TargetCountry__c = campaigns.get(l.ApiCampaign__c).TargetCountry__c;
                    }
                }
            }    
        }
     }

    private void addToMap(Map<Id, Set<Lead>> campaignToLeads, Id campaignId, Lead lead) {
        
        if (!campaignToLeads.containsKey(campaignId)) {
        	campaignToLeads.put(campaignId, new Set<Lead>());
        }
        campaignToLeads.get(campaignId).add(lead);		
    }    
        
    /**
     * Check if a string is a valid campaign ID
     */
    private Boolean isCampaignId(String idToCheck) {
        
        if (idToCheck == NULL) {
            return false;
        }
        
        ID testId;                
        try {
            testId = (Id)idToCheck;
        }
        catch (Exception e) {
            return false;
        }
        
        if (!Pattern.matches('^701.+', idToCheck)) {
            return false;
        }        
        
        return true;
    }

    private static Map<String, Id>   populateSuppliers() {

        Map<String, Id> supplierMap = new Map<String, Id>();

        List<Account> suppliers = [SELECT Id, SupplierNo__C FROM Account WHERE SupplierNo__c != NULL];

        for (Account a : suppliers) {

            supplierMap.put(a.SupplierNo__c, a.Id);
        }

        return supplierMap;
    }
    
     /**
     * Fills Referral object fields on Lead conversion
     * 
     * @see https://interaktiv.jira.com/browse/SOBCRM-1062
     * @author Igor Savchenko <igor@die-interaktiven.de>
     */
    private void setAccountOnReferral() {
        Id[] leadIds = new Id[]{};
        for (Lead lead: (Lead[])Trigger.new) {
            leadIds.add(lead.Id);
        }
        Referral__c[] referrals = [
            SELECT ReferredAccount__c, ReferredLead__c, ReferringAccount__c, ReferringLead__c 
            FROM Referral__c
            WHERE ReferredLead__c IN :leadIds OR ReferringLead__c IN :leadIds
        ];
        Referral__c[] referralsToUpdate = new Referral__c[]{};
        for (Lead lead: (Lead[])Trigger.new) {
            if (lead.IsConverted == true) {
                for (Referral__c referral: referrals) {
                    Boolean updateNeeded = false;
                    if (referral.ReferredLead__c == lead.Id) {
                        referral.ReferredLead__c = null;
                        referral.ReferredAccount__c = lead.ConvertedAccountId;
                        updateNeeded = true;
                    }
                    if (referral.ReferringLead__c == lead.Id) {
                        referral.ReferringLead__c = null;
                        referral.ReferringAccount__c = lead.ConvertedAccountId;
                        updateNeeded = true;
                    }
                    if (updateNeeded) {
                        referralsToUpdate.add(referral);
                    }
                }
            }
		}
        update referralsToUpdate;
    }
    
     /**
     * Sets Territorial Exclusivity on Leads from related Postal Code Area
     * 
     * @see https://interaktiv.jira.com/browse/SOBCRM-1061
     * @author Igor Savchenko <igor@die-interaktiven.de>
     */    
    private void setTerritorialExclusivity() {
        Id[] leadIds = new Id[]{};
        Lead[] leadsToUpdate = new Lead[]{};
        String[] leadPostalCodes = new String[]{};
        String[] leadCountryCodes = new String[]{};

        for (Lead lead: (Lead[])Trigger.new) {
            leadIds.add(lead.Id);
            leadPostalCodes.add(lead.PostalCode);
            leadCountryCodes.add(lead.CountryCode);
        }
        Lead[] leads = [SELECT CountryCode, PostalCode, TerritorialExclusivity__c FROM Lead WHERE Id IN :leadIds];
        PostalCodeArea__c[] postalCodeAreas = [SELECT Name, Country__c, TerritorialExclusivity__c FROM PostalCodeArea__c WHERE Name IN :leadPostalCodes AND Country__c IN :leadCountryCodes];
        for (Lead lead: leads) {
            Boolean postalOrCountryChanged = Trigger.isUpdate && Trigger.isAfter && (Trigger.oldMap.get(lead.id).get('PostalCode') != lead.PostalCode || Trigger.oldMap.get(lead.id).get('CountryCode') != lead.CountryCode);
            if (Trigger.isInsert && Trigger.isAfter || postalOrCountryChanged) {
                lead.TerritorialExclusivity__c = false;
                if (lead.PostalCode != '' && lead.PostalCode != null) {
                    for (PostalCodeArea__c postalCodeArea: postalCodeAreas) {
                        if (postalCodeArea.Name == lead.PostalCode && postalCodeArea.Country__c == lead.CountryCode) {
                            lead.TerritorialExclusivity__c = postalCodeAreas.get(0).TerritorialExclusivity__c;
                        }
                    }
                }
                leadsToUpdate.add(lead);
            }
        }
        update leadsToUpdate;
    }
    
}