/**
 * Trigger for MeterInstallation__c
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.1.0-2017-10-30
 */
trigger TriggerMeterInstallation on MeterInstallation__c (after insert, after update) {
    new MeterInstallationTriggerHandler().run();
}