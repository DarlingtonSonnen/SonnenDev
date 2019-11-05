/**
 * Created by b.jarmolinski on 01/08/2018.
 */

trigger zQuoteTrigger on zqu__Quote__c (after insert, before update, after update) {
    new zQuoteTriggerHandler().run();
}