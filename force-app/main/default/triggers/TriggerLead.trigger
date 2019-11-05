trigger TriggerLead on Lead (after insert, after update, before insert, before update) {
    new LeadTriggerHandler().run();
}