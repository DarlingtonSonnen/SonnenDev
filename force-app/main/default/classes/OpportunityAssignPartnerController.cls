/**
 * Controller for partner to Opportunity assignment
 *
 * @since 2016-11-22
 * @version 1.0.0
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @see https://interaktiv.jira.com/browse/SOBCRM-681
 */
public class OpportunityAssignPartnerController {

    public static final String DEBUG_HEADER = 'OpportunityAssignPartnerController.';

    public static final String AREA_MANAGER_PROFILE_NAME = '* Area Manager';
    public static Id idRecordTypeDirectSales;

    public Boolean hasStopError {get; private set;}

    public List<OpportunityWrapper> listOpportunityWrappers {get; set;}

    /**
     * Constructor
     */
    public OpportunityAssignPartnerController(ApexPages.StandardSetController controller) {

        Map<String,Id> mapOpportunityRecordTypes = SonnenbatterieConstants.getRecordTypeIdsByObjectName('Opportunity');

        this.listOpportunityWrappers = new List<OpportunityWrapper>();

        idRecordTypeDirectSales  = mapOpportunityRecordTypes.get('DirectSales');
        Id idRecordTypePartnerSales = mapOpportunityRecordTypes.get('Order'); // Label: Partner Sales

        if (idRecordTypePartnerSales == NULL) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Record Type for "Partner Sales" not found'));
            this.hasStopError = true;
            return;
        }
        if (idRecordTypeDirectSales == NULL) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'Record Type for "Direct Sales" not found'));
            this.hasStopError = true;
            return;
        }

        List<Opportunity> listSelectedOpportunities = (List<Opportunity>)controller.getSelected();

        if (listSelectedOpportunities.isEmpty()) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'No records selected!'));
            this.hasStopError = true;
            return;
        }

        // Filter on correct RecordType
        Set<Id> lsetOpportunityIds = new Set<Id>();

        for (Opportunity oOpportunity : listSelectedOpportunities) {
            if (oOpportunity.RecordTypeId == idRecordTypePartnerSales) {
                lsetOpportunityIds.add(oOpportunity.Id);
            }
        }

        if (lsetOpportunityIds.isEmpty()) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, 'No records of type "Partner Sales" selected!'));
            this.hasStopError = true;
            return;
        }

        // Get more fields and wrap in OpportunityWrapper class
        listSelectedOpportunities = [
            SELECT
                Id,
                Name,
                RecordTypeId,
                OwnerId,
                RecommendedPartner__c,
                RecommendedPartner__r.Name,
                ProposedSBC__c,
                ProposedSBC__r.Name,
                AccountId,
                Account.Name,
                Account.BillingStreet,
                Account.BillingCity,
                Account.BillingPostalCode,
                Account.BillingCountryCode,
                Account.BillingCountry,
                Account.BillingLongitude,
                Account.BillingLatitude
            FROM Opportunity
            WHERE Id IN :lsetOpportunityIds
        ];

        Map<Id,Map<String,String>> mapObjectIdLocationsPartner = new Map<Id,Map<String,String>>();
        Map<Id,OpportunityWrapper> mapOpporunityIdToWrapper = new Map<Id,OpportunityWrapper>();

        for (Opportunity oOpportunity : listSelectedOpportunities) {

            // Collect location information
            mapObjectIdLocationsPartner.put(
                oOpportunity.Id,
                new Map<String,String>{
                    'postalCode'  => oOpportunity.Account.BillingPostalCode,
                    'countryCode' => oOpportunity.Account.BillingCountryCode,
                    'longitude'   => String.valueOf(oOpportunity.Account.BillingLongitude),
                    'latitude'    => String.valueOf(oOpportunity.Account.BillingLatitude)
                }
            );

            OpportunityWrapper oOpportunityWrapper = new OpportunityWrapper(oOpportunity);
            this.listOpportunityWrappers.add(oOpportunityWrapper);
            mapOpporunityIdToWrapper.put(oOpportunity.Id, oOpportunityWrapper);
        }

        // Now search for Partner proposals
        Map<Id,List<AssignDelegate.FoundAccountWrapper>> foundAcounts = AssignDelegate.proposePartnerAccounts(mapObjectIdLocationsPartner);

        if (!foundAcounts.isEmpty()) {
            for (Id idOpportunity : foundAcounts.keySet()) {
                OpportunityWrapper oOpportunityWrapper = mapOpporunityIdToWrapper.get(idOpportunity);
                oOpportunityWrapper.proposedPartners = foundAcounts.get(idOpportunity);
            }
        }
    }

    /**
     * Action save
     */
    public PageReference save() {

        String debugHere = DEBUG_HEADER + 'save() - ';
        Boolean debug = FALSE;
        String debugMessage;

        PageReference page = ApexPages.currentPage();

        List<Opportunity> listOpportunitiesToUpdate = new List<Opportunity>();

        for (OpportunityWrapper oOpportunityWrapper : this.listOpportunityWrappers) {

            if (oOpportunityWrapper.hasChanges) {

                Opportunity oOpportunity = oOpportunityWrapper.opportunity.clone(TRUE);

                // Change Record Type to "Direct Sales"
                // and eventually set Owner (= Ambassador)
                if (oOpportunityWrapper.assignToDirectSales) {

                    debugMessage = oOpportunityWrapper.opportunity.Name + ': assign to direct sales (' + oOpportunityWrapper.directDirectSalesTeam + ' -> ' + oOpportunityWrapper.directDirectSalesAmbassador + ')';
                    System.debug(debugHere + debugMessage);
                    if (debug) ApexPages.addmessage(new ApexPages.message(ApexPages.severity.INFO, debugMessage));

                    Boolean hasChange = false;

                    if (oOpportunity.RecordTypeId != idRecordTypeDirectSales) {
                        oOpportunity.RecordTypeId = idRecordTypeDirectSales;
                        hasChange = true;
                    }
                    if (oOpportunityWrapper.directDirectSalesTeam == 'Ambassador'
                            && oOpportunityWrapper.directDirectSalesAmbassador != NULL
                            && oOpportunity.OwnerId != oOpportunityWrapper.directDirectSalesAmbassador) {
                        oOpportunity.OwnerId = oOpportunityWrapper.directDirectSalesAmbassador;
                        hasChange = true;
                    }
                    if (hasChange) {
                        listOpportunitiesToUpdate.add(oOpportunity);
                    }
                }
                // Set proposed partner (ProposedSBC__c)
                else {
                    debugMessage = oOpportunityWrapper.opportunity.Name + ': ' + oOpportunityWrapper.opportunity.ProposedSBC__c;
                    System.debug(debugHere + debugMessage);
                    if (debug) ApexPages.addmessage(new ApexPages.message(ApexPages.severity.INFO, debugMessage));

                    listOpportunitiesToUpdate.add(oOpportunity);
                }
            }
        }

        // Save updates
        if (!listOpportunitiesToUpdate.isEmpty()) {

            debugMessage = 'Updates: ' + listOpportunitiesToUpdate;
            System.debug(debugHere + debugMessage);

            if (debug) {
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.INFO, debugMessage));
            }
            else {
                try {
                    update listOpportunitiesToUpdate;
                }
                catch (Exception e) {
                    ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR, e.getMessage()));
                }

                // Jump to return URL
                page = new PageReference(page.getParameters().get('retUrl'));
            }
        }

        return page;
    }

    /**
     * Returns the select list for team
     */
    public List<selectOption> getTeamSelections(){

        List<selectOption> ambassadors = this.getAmbassadorSelections();

        return new List<selectOption>{
            new selectOption('SalesManagement','Sales Management'),
            new selectOption('Ambassador','Ambassador', ambassadors.isEmpty())
        };
    }

    /**
     * Returns the select list of ambassadors
     */
    public List<selectOption> getAmbassadorSelections(){

        List<selectOption> listUserSelection = new List<selectOption>();
        List<User> listUsers = [SELECT Id, FirstName, LastName FROM User WHERE Profile.Name = :AREA_MANAGER_PROFILE_NAME ORDER BY LastName ASC];

        for (User oUser : listUsers) {
            String sName = oUser.LastName + (oUser.FirstName != NULL ? ', ' + oUser.FirstName : '');
            listUserSelection.add(new selectOption(oUser.Id, sName));
        }

        return listUserSelection;
    }

    /**
     * Inner class OpportunityWrapper
     */
    public class OpportunityWrapper {

        public Opportunity opportunity {get;set;}
        public List<AssignDelegate.FoundAccountWrapper> proposedPartners {get; private set;}
        public Boolean assignToDirectSales {get; set;}
        public Boolean initialAssignedToDirectSales {get; set;}
        public Id initiallyAssignedPartnerId {get; set;}
        public String initiallyAssignedPartnerName {get; set;}
        public Boolean hasChanges {get; set;}
        public String directDirectSalesTeam {get; set;}
        public Id directDirectSalesAmbassador {get; set;}

        public OpportunityWrapper(Opportunity opportunity) {
            this.proposedPartners = new List<AssignDelegate.FoundAccountWrapper>();
            this.opportunity = opportunity;
            this.assignToDirectSales = FALSE;
            this.initiallyAssignedPartnerId = opportunity.ProposedSBC__c;
            this.initiallyAssignedPartnerName = opportunity.ProposedSBC__r.Name;
            this.hasChanges = FALSE;
            this.initialAssignedToDirectSales = (opportunity.RecordTypeId == OpportunityAssignPartnerController.idRecordTypeDirectSales);
        }
    }
}