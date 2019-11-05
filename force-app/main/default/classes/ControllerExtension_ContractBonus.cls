/**
 * Contract Bonus Controller
 *
 * Changelog
 * ---------
 *  @update: Michael Muchow
 *  @date: 01.02.2018
 *  @changes: changed public void showOtherSwitch() to work with Picklist Values 'Product related'
 *
 * 1.2.0-2017-10-23 (MSB, SOBCRM-1090)
 * - Added field Campaign.BonusApplyTo__c which copies to Bonus__c.ApplyTo__c
 * - filterCampaigns(): Filter only campaigns according to the new picklist
 *   Campaign.BonusContractType__c comparing the contract's record type.
 *   If this field is not set then try to filter on campaign name (if "community"
 *   is in it or not).
 *
 * 1.1.0-2016-05-24 (SOBCRM-465)
 * - daniel.stange@die-interaktiven.de
 *
 * @see manageContractBonus.page
 * @version 1.2.0-2017-10-23
 */
public with sharing class ControllerExtension_ContractBonus {

    public List<SelectOption> currentBonusCampaigns {get; private set;}
    public String selectedCampaign {public get; public set;}
    public Campaign theCampaign {public get; public set;}
    public boolean showDetails {public get; private set;}
    public boolean showOther{public get; set;}

    public Contract theContract {public get; private set;}
    public Id customerContactId;

    public boolean showMessageContainer {public get; private set;}

    public Bonus__c theBonus {
        public get {

            if(theBonus == null) {

                return new Bonus__c();
            }

            return theBonus;
        }
        public set;
    }
    
    /**
     * Constructor as being called from the Contract standard controller 
     *
     * @param      stdController  Contract Standard Controller instance
     */
    public ControllerExtension_ContractBonus(ApexPages.StandardController stdController) {
        this.theContract = (stdController.getRecord() != NULL) ? (Contract)stdController.getRecord() : new Contract();
        
        try {
            this.theContract = [SELECT Id, AccountId, CustomerSignedId, RecordType.DeveloperName FROM Contract WHERE Id = : theContract.Id];
            this.customerContactId = this.theContract.CustomerSignedId;
        }
        catch (Exception e) {
            this.customerContactId = NULL;
            ApexPages.addMessages(new BonusControllerException('Contract has no information for a contact. No campaign influence can be recorded for this bonus.'));
        }

        if (this.theContract.CustomerSignedId == NULL) {
            ApexPages.addMessages(new BonusControllerException('Contract has no information for a contact. No campaign influence can be recorded for this bonus.'));
        }

        this.showDetails= false;
        init();
    }

    /**
     * inits the controller extension and fills the campaign select list
     */
    private void init() {

        this.theBonus = theBonus;

        //if (campaignList != NULL) {
            
        //    this.currentBonusCampaigns = new List<SelectOption>();

        //    for (Campaign c : campaignlist) {
        //        this.currentBonusCampaigns.add(
        //            new SelectOption(
        //                c.Id, 
        //                c.Name + ' - ' + c.BonusAmount__c + ' ' + c.BonusUnit__c + ' for ' + c.BonusNoOfMonths__c + ' months')
        //        );
        //    }
        //}
    }

    /**
     * Sets the selected campaign parameter, 
     * refreshes the page and displays bonus details 
     * as preset on the selected campaign
     *
     * @return     Refresh event for the current page
     */
    public void selectCampaign() {

         this.showDetails = true;

         if ( this.selectedCampaign != NULL) {
            try {
                this.theCampaign = [
                    SELECT  Id,
                            Name,
                            BonusAmount__c,
                            BonusType__c,
                            BonusNoOfMonths__c,
                            BonusUnit__c,
                            BonusApplyTo__c,
                            BonusContractType__c
                    FROM    Campaign
                    WHERE   Id = : selectedCampaign
                ];
            }
            catch (Exception e) {
                ApexPages.addMessages(e);
            }
         }
    }

    public void filterCampaigns() {

        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Name : ' + this.theContract.RecordType.DeveloperName));

        // Select only campaigns according to the contract's record type
        // in Campaign.BonusContractType__c. If this field is not set then
        // try to filter on campaign name (if "community" is in it or not)
        String bonusContractType = this.theContract.RecordType.DeveloperName.containsIgnoreCase('community') ? 'community' : 'energy';
        String notLike = bonusContractType != 'community' ? 'NOT' :  '';

        String soql =
            'SELECT  Id, ' +
            '        Name, ' +
            '        BonusAmount__c, ' +
            '        BonusNoOfMonths__c, ' +
            '        BonusUnit__c, ' +
            '        BonusApplyTo__c ' +
            'FROM    Campaign ' +
            'WHERE   RecordType.DeveloperName = \'Bonus\' ' +
            'AND     Division__c = \'' + this.theBonus.BonusInitiator__c + '\' ' +
            'AND     isActive = true ' +
            'AND     (BonusContractType__c = \'' + bonusContractType + '\' OR (BonusContractType__c = NULL AND (' + notLike + ' Name LIKE \'%community%\')))';

        System.debug('soql: ' + soql);

        List<Campaign> campaignList = Database.query(soql);

        if (campaignList != NULL) {
            
            this.currentBonusCampaigns = new List<SelectOption>();

            for (Campaign c : campaignlist) {
                this.currentBonusCampaigns.add(
                    new SelectOption(
                        c.Id, 
                        c.Name + ' - ' + c.BonusAmount__c + ' ' + c.BonusUnit__c + ' for ' + c.BonusNoOfMonths__c + ' months')
                );
            }
        }
    }

    public PageReference updateCampaign() {

         this.showDetails = true;
         return NULL;

    }

    public PageReference saveBonus() {

        System.debug('theCampaign  ' + theCampaign);
        System.debug('this.theBonus  ' + this.theBonus);

        this.theBonus.Unit__c       = theCampaign.BonusUnit__c;
        this.theBonus.ApplyTo__c    = theCampaign.BonusApplyTo__c;
        this.theBonus.RecordTypeId  = theCampaign.BonusContractType__c == 'energy' ? Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Energy') : Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Other'); //SOBCRM-465 + SOBCRM-1090
        this.theBonus.BonusType__c  = theCampaign.BonusType__c;
        this.theBonus.NoOfMonths__c = theCampaign.BonusNoOfMonths__c;
        this.theBonus.Amount__c     = theCampaign.BonusAmount__c;
        this.theBonus.CampaignId__c = theCampaign.Id;
        this.theBonus.Contract__c   = theContract.Id;

        //Savepoint eineSchritteSuruck = Database.setSavepoint();
        Boolean errorwasmade = false;

        if (customerContactId != NULL) {

            CampaignMember theCampaignMember = new CampaignMember();

            theCampaignMember.CampaignId = theCampaign.Id;
            theCampaignMember.ContactId = customerContactId;
            theCampaignMember.Status = 'Bonus created';
            
            try {

                upsert theCampaignMember;
                
                this.showMessageContainer = true;
                // ApexPages.addMessage(new ApexPages.Message(
                //ApexPages.Severity.CONFIRM,
                //'Contact was added to bonus campaign!'
                //));
            }
            catch (DmlException e) {

                // Boolean errorwasmade = true;
                ApexPages.addMessages(e);
            }
   
        }
        

        try {

            insert this.theBonus;

            this.showMessageContainer = true;
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Bonus was successfully created!'
                ));
        }
        catch (DmlException e) {
            errorwasmade = true; 
            ApexPages.addMessages(e);
        }

        if(errorwasmade) {
            // Database.rollback(eineSchritteSuruck);
            return null; 
        } else {

            PageReference pr = new PageReference('/' + theContract.Id);
            return pr;
        }
    }

    public void showOtherSwitch() {
        if(this.theBonus.BonusReason__c == 'Other' || this.theBonus.BonusReason__c == 'Product related') {

            this.showOther = true; 
        } else {
            this.showOther = false;
        }
    }

    public PageReference cancelAndBack() {
    
        PageReference pr = new PageReference('/' + theContract.Id);
        return pr;
    }

    private class BonusControllerException extends Exception {}
}