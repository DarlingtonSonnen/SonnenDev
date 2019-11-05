/**
 * Trigger for PostalCodeArea__c object
 *
 * @created    18.01.2017
 * @author     dino.ursic@die-interaktiven.de
 * @see        SOBCRM-752
 */
trigger TriggerPostalCodeArea on PostalCodeArea__c (after insert, after update, after delete) {
    new PostalCodeAreaTriggerHandler().run();
}