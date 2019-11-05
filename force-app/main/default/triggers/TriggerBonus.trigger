trigger TriggerBonus on Bonus__c (after insert, before update, after update, before delete) {
   new LumenazaBonusTriggerHandler().run();
}