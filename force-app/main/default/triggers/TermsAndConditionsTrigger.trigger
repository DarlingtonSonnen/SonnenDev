trigger TermsAndConditionsTrigger on TermsAndConditions__c (after insert, after update, before  update, before insert) {
	new TermsAndCondTriggerHandler().run();
}