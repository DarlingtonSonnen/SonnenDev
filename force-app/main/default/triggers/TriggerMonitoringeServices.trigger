trigger TriggerMonitoringeServices on MonitoringeServices__c (before insert, before update, after update, after insert) {
    new MonitoringeServicesTriggerHandler().run();
}