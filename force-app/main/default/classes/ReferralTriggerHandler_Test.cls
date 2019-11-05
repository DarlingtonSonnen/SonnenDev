@isTest
private class ReferralTriggerHandler_Test {

    /**
     * Tests ReferralTriggerHandler.validateRelations()
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-1062
     * @author Igor Savchenko
     * @date 2017-08-26
     */    
    @isTest  
    static void testValidateRelations() {
   		Test.startTest();

		Lead lead = new Lead(
			FirstName          = 'Foo',
			LastName           = 'Bar2',
			Email              = 'my@test.mail',
			Type__c            = 'Other',
			LeadSource         = 'Other',
			ProductInterest__c = 'eco',
			Description2__c    = 'Blabla'
		);  
		insert lead;

		Lead lead2 = new Lead(
			FirstName          = 'Foo',
			LastName           = 'Bar2',
			Email              = 'my@test.mail',
			Type__c            = 'Other',
			LeadSource         = 'Other',
			ProductInterest__c = 'eco',
			Description2__c    = 'Blabla'
		);  
		insert lead2;

		Account acc = new Account(
			Name = 'acc name'
		);
		insert acc;

		Referral__c referral = new Referral__c(
			ReferredLead__c = lead.Id,
			ReferringLead__c = lead.Id
		);
		insert referral;

		referral.ReferredLead__c = lead2.Id;
		update referral;

		try {
			referral.ReferredAccount__c = acc.Id;
			update referral;
			// this update should raise error
			system.assertEquals(1, 0);
		} catch (Exception e) {

		}

   		Test.stopTest();
    } 
   
}