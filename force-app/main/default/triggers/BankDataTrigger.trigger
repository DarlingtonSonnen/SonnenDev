trigger BankDataTrigger on BankData__c (before insert, after insert, before update, before delete) {
    new BankDataTriggerHandler().run();
}