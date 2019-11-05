/**
 * ReferralTriggerHandler
 *
 * Changelog
 *
 * @version 1.0 (2017-08-15)
 * @author Igor Savchenko <igor@die-interactiven.de>
 * @desc SOBCRM-1062: Referral and Lead Conversion
 * 
 */
public class ReferralTriggerHandler extends TriggerHandler {

    public override void afterUpdate() {
    	validateRelations();
    }

    public override void afterInsert() {
    	validateRelations();
    }

    /**
     * Validates created / updated Referrals for duplicates. 
     * Validates created / updated Referrals for referred / referring fields.
     *
	 * @author Igor Savchenko <igor@die-interactiven.de>
	 * @desc SOBCRM-1062: Referral and Lead Conversion
     */    
    private void validateRelations() {
		for (Referral__c referral: (Referral__c[])Trigger.new) {
			Boolean bothReferringFieldsSet = referral.ReferringLead__c != null && referral.ReferringAccount__c != null;
			Boolean bothReferredFieldsSet = referral.ReferredLead__c != null && referral.ReferredAccount__c != null;
			if (bothReferringFieldsSet || bothReferredFieldsSet) {
				referral.addError(System.Label.SOB_ReferralRelationsError);
			}

			// There are 2 approaches (in this case I prefer the second one): 
			// 1. Get all Referrals (limit 50000 + limit CPU to go through all these Referrals)
			// 2. Make 1 soql per updated / inserted referral
			/*
			Temporary commented
			if (isDuplicate(referral, 'ReferringLead__c', 'ReferredLead__c') || isDuplicate(referral, 'ReferringLead__c', 'ReferredAccount__c') || 
				isDuplicate(referral, 'ReferringAccount__c', 'ReferredLead__c') || isDuplicate(referral, 'ReferringAccount__c', 'ReferredAccount__c')
			) {
				referral.addError(System.Label.SOB_ReferralDuplicateRelationsError);
			}
			*/
		}
    }

    /*
    private Boolean isDuplicate(Referral__c referral, String referringField, String referredField) {
    	Referral__c[] duplicateReferrals = new Referral__c[]{};
    	if (referral.get(referringField) != null && referral.get(referredField) != null) {
	    	duplicateReferrals = Database.query(
	    		'SELECT Id ' +
	    		'FROM Referral__c ' +
	    		'WHERE ' + referringField + ' = \'' + referral.get(referringField) + '\' AND ' + referredField + ' = \'' + referral.get(referredField) + '\''
			);
    	}    	
		return duplicateReferrals.size() > 1;
    }
    */

}