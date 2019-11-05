/**
 * OpportunityTriggerHandler
 *
 * Changelog
 * ---------
 *
 * v1.0.0   2016-10-17  Marko Schmalenbach          Initial(?)
 * v1.1.0   2018-10-15  Marko Schmalenbach          Added OpportunityInvoice call for Invoice creation by "Xero" (Australian orders, SOBCRM-1271)
 */
public class OpportunityTriggerHandler extends TriggerHandler {

    public static final String DEBUG_HEADER = 'OpportunityTriggerHandler.';

    public static final String CAMPAIGN_MEMBER_STATUS_ACTIVATED = 'Bonus activated';

    /**
     * beforeInsert
     */
    public override void beforeInsert() {
        this.addPrimaryContact();
        this.processVoucherCode();
    }

    /**
     * beforeUpdate
     */
    public override void beforeUpdate() {
        this.processVoucherCode();
    }

    /**
     * afterUpdate
     */
    public override void afterUpdate() {
        // Invoice creation for "Xero" (2018-10-15, SOBCRM-1271)
        OpportunityInvoice.createInvoice(Trigger.new);
    }

    /**
     * Process voucher code on Opportunities
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-546
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @since 2016-10-17
     */
    public void processVoucherCode() {

        String sDebugMethod = DEBUG_HEADER + 'processVoucherCode() - ';
        String sError;

        System.debug(sDebugMethod + 'Entering');

        List<Opportunity> listOpportunities = (List<Opportunity>) Trigger.new;
        List<Opportunity> listOpportunitiesWithVoucherCode = new List<Opportunity>();

        Set<String> lsetVoucherCodes = new Set<String>();
        Map<Id,String> mapVoucherCodes = new Map<Id,String>();

        // Collect voucher codes
        for (Opportunity oOpportunity : listOpportunities) {
            if (oOpportunity.VoucherCode__c != NULL && oOpportunity.Bonus__c == NULL) {

                listOpportunitiesWithVoucherCode.add(oOpportunity);

                if (lsetVoucherCodes.contains(oOpportunity.VoucherCode__c)) {
                    oOpportunity.addError('Duplicate voucher code "' + oOpportunity.VoucherCode__c + '"');
                    return;
                }
                lsetVoucherCodes.add(oOpportunity.VoucherCode__c);
                mapVoucherCodes.put(oOpportunity.Id, oOpportunity.VoucherCode__c);
            }
        }

        if (mapVoucherCodes.isEmpty()) {
            System.debug(sDebugMethod + 'No voucher codes found in Opportunities');
            return;
        }

        //--------------------------------------------------
        // Campaign Member(ship)s
        //--------------------------------------------------
        System.debug(sDebugMethod + 'Try to find Campaign Members by voucher code on (usually) Community Contracts and their CustomerSignedIds');

        List<Contract> listContracts = new List<Contract>([
                SELECT Id, CustomerSignedId, VoucherCode__c
                FROM Contract
                WHERE VoucherCode__c IN :lsetVoucherCodes
        ]);
        Map<String,Id> mapVoucherCodeToCustomerSignedId = new Map<String,Id>();
        for (Contract oContract : listContracts) {
            mapVoucherCodeToCustomerSignedId.put(oContract.VoucherCode__c, oContract.CustomerSignedId);
        }

        System.debug(sDebugMethod + 'mapVoucherCodeToCustomerSignedId: ' + mapVoucherCodeToCustomerSignedId);

        Map<Id,CampaignMember> mapContactIdToCampaignMember = new Map<Id,CampaignMember>();

        if (!mapVoucherCodeToCustomerSignedId.isEmpty()) {

            System.debug(sDebugMethod + 'Now search Campaign Members by CustomerSignedIds');

            // Get the Bonus Campaign ID
            GeneralSettings__c oSettings = GeneralSettings__c.getValues('communityContractBonusCampaignId');
            System.debug(sDebugMethod + 'Bonus Campaign ID is ' + oSettings.Value__c);
            System.assertNotEquals(NULL, oSettings.Value__c);

            List<CampaignMember> listCampaignMembers = new List<CampaignMember>([
                    SELECT Id, ContactId
                    FROM CampaignMember
                    WHERE
                        CampaignId = :oSettings.Value__c AND
                        ContactId IN :mapVoucherCodeToCustomerSignedId.values() AND
                        Status != :CAMPAIGN_MEMBER_STATUS_ACTIVATED
            ]);

            // Map ContactId -> CampaignId -> CampaignMember
            for (CampaignMember oCampaignMember : listCampaignMembers) {
                mapContactIdToCampaignMember.put(oCampaignMember.ContactId, oCampaignMember);
            }

            System.debug(sDebugMethod + 'mapContactIdToCampaignMember: ' + mapContactIdToCampaignMember);
        }

        //--------------------------------------------------
        // Search Bonuses by voucher code
        //--------------------------------------------------
        System.debug(sDebugMethod + 'Search Bonuses by voucher code');

        List<Bonus__c> listBonuses = new List<Bonus__c>([
                SELECT Id, BonusCode__c, RedeemDate__c, Valid__c, CampaignId__c
                FROM Bonus__c
                WHERE BonusCode__c IN :lsetVoucherCodes
        ]);

        Map<String,Bonus__c> mapVoucherCodeToBonus = new Map<String,Bonus__c>();
        for (Bonus__c oBonus : listBonuses) {
            mapVoucherCodeToBonus.put(oBonus.BonusCode__c, oBonus);
        }

        System.debug(sDebugMethod + 'Handle ' + listOpportunitiesWithVoucherCode.size() + ' Opportunities');

        List<CampaignMember> listCampaignMembersToUpdate = new List<CampaignMember>();

        for (Opportunity oOpportunity : listOpportunitiesWithVoucherCode) {

            String sVoucherCode = oOpportunity.VoucherCode__c;
            Bonus__c oBonus = mapVoucherCodeToBonus.get(sVoucherCode);

            // Check if Bonus was found for voucher code
            if (oBonus == NULL) {
                oOpportunity.addError(this.getTranslation('Could not find bonus for code "' + sVoucherCode + '"', 'Der Gutscheincode "' + sVoucherCode + '" konnte nicht gefunden werden', 'de'));
                return;
            }
            if (!oBonus.Valid__c) {
                oOpportunity.addError(this.getTranslation('The voucher code "' + sVoucherCode + '" is invalid', 'Der Gutscheincode "' + sVoucherCode + '" ist ungültig', 'de'));
                return;
            }

            // Set redeem date on Bonus
            oBonus.RedeemDate__c = System.now();
            update oBonus;

            // Set Bonus Id on Opportunity
            oOpportunity.Bonus__c = oBonus.Id;

            System.debug(sDebugMethod + (oOpportunity.Id == NULL ? '' : 'Opportunity (' + oOpportunity.Id + ') ') + 'set Bonus ' + oBonus.Id);

            //--------------------------------------------------
            // Set Campaign Member status
            //--------------------------------------------------

            // Get Contact ID by Voucher Code (from Contracts above)
            Id idContact = mapVoucherCodeToCustomerSignedId.get(sVoucherCode);

            if (idContact != NULL) {

                CampaignMember oCampaignMember = mapContactIdToCampaignMember.get(idContact);

                if (oCampaignMember != NULL) {
                    System.debug(sDebugMethod + 'Set CampaignMember\'s Status  ' + oCampaignMember.Id + ' to "' + CAMPAIGN_MEMBER_STATUS_ACTIVATED + '"');
                    // ATTENTION!
                    // For this to work you have to add the Status by the "Advanced Setup"
                    // in the Campaign object
                    oCampaignMember.Status = CAMPAIGN_MEMBER_STATUS_ACTIVATED;
                    listCampaignMembersToUpdate.add(oCampaignMember);
                }
            }
        }

        if (!listCampaignMembersToUpdate.isEmpty()) {
            System.debug(sDebugMethod + 'CampaignMembers: ' + listCampaignMembersToUpdate);
            update listCampaignMembersToUpdate;
        }
    }

    /**
     * Set Opportunity's PrimaryContact__c on insert to the first Contact
     * of a related Account. If the Account is a PersonAccount the PersonContactId
     * of this Account will be set.
     */
    public void addPrimaryContact() {

        Map<Id,List<Integer>> accountIdToOpportunityIndex = new Map<Id,List<Integer>>();
        Integer index = 0;

        List<Opportunity> opportunities = (List<Opportunity>) Trigger.new;

        // Collect account IDs from Opportunities
        for (Opportunity opportunity : opportunities) {

            Id accountId = opportunity.AccountId;

            if (opportunity.PrimaryContact__c == NULL && accountId != NULL) {
                if (!accountIdToOpportunityIndex.containsKey(accountId)) {
                    accountIdToOpportunityIndex.put(accountId, new List<Integer>());
                }
                accountIdToOpportunityIndex.get(accountId).add(index);
            }
            index++;
        }
        // Find account's first contacts
        if (!accountIdToOpportunityIndex.isEmpty()) {

            List<Id> accountIds = new List<Id>(accountIdToOpportunityIndex.keySet());
            // If the Account is a PersonAccount the subselect will hold the
            // PersonContactId - sweeeet!
            Map<Id,Account> accounts = new Map<Id,Account>([SELECT Id, (SELECT Id FROM Contacts ORDER BY CreatedDate LIMIT 1) FROM Account WHERE Id IN :accountIds]);

            // Iterate over accountIdToOpportunityIndex and add Contact ID
            for (Id accountId : accountIdToOpportunityIndex.keySet()) {

                Account matchingAccount = accounts.get(accountId);

                if (!matchingAccount.Contacts.isEmpty()) {

                    // Set Opportunity's PrimaryContact
                    for (Integer opportunityIndex : accountIdToOpportunityIndex.get(accountId)) {
                        Opportunity opportunityToUpdate = opportunities.get(opportunityIndex);
                        Contact contact = matchingAccount.Contacts.get(0);
                        opportunityToUpdate.PrimaryContact__c = matchingAccount.Contacts.get(0).Id;
                    }
                }
            }
        }
    }

    /**
     * Returns a translation if language of user
     * matches the given one
     */
    private String getTranslation(String defaultText, String translatedText, String translatedLanguage) {
        return (UserInfo.getLanguage() == translatedLanguage) ? translatedText : defaultText;
    }
}