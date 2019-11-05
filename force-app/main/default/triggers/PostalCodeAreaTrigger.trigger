trigger PostalCodeAreaTrigger on PostalCodeArea__c (after insert, after update, after delete) {
    new PostalCodeAreaTriggerHandler().run();
}