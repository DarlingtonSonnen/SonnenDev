/**
 * TriggerOpportunityLineItem
 *
 * @since 2018-10-10
 */
trigger TriggerOpportunityLineItem on OpportunityLineItem (before insert, before update) {
    new OpportunityLineItemTriggerHandler().run();
}