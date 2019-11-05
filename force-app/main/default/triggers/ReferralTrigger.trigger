trigger ReferralTrigger on Referral__c (before insert, after insert, before update, after update, before delete, after undelete) {
	new ReferralTriggerHandler().run();
}