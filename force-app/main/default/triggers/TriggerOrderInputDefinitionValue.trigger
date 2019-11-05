trigger TriggerOrderInputDefinitionValue on OrderInputDefinitionValue__c (before insert) {
    new OrderInputDefinitionValueTriggerHandler().run();
}