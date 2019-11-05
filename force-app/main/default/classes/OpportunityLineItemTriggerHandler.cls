/**
 * OpportunityLineItemTriggerHandler
 *
 * Changelog:
 *
 * v1.0.0   2018-10-10  Marko Schmalenbach          Initial for SOBCRM-1256 and SOBCRM-1271 (Hardware Order for Australia)
 * v1.1.0   2018-10-17  Marko Schmalenbach          Added Australian tax to Subsidy amount so that the net amount can substract it again
 * v1.2.0   2018-10-19  Marko Schmalenbach          - Implemented setOpportunityFieldsForOrder() to set field of Line Items to Opportunity (SOBCRM-1277)
 *                                                  - Set Opportunity.BatteryCapacity from Battery Line Item (Is used for Subsidy calculation)
 *
 * @since 2018-10-10
 */
public class OpportunityLineItemTriggerHandler extends TriggerHandler {

    private static final String DEBUG_HEADER = 'OpportunityLineItemTriggerHandler.';

    private static Decimal AUSTRALIAN_TAX_FACTOR;

    /**
     * beforeInsert
     */
    public override void beforeInsert() {

        this.setOpportunityFieldsForOrder();
        this.setAustralianSubsidyAmount();
    }

    /**
     * beforeUpdate
     */
    public override void beforeUpdate() {

        this.setOpportunityFieldsForOrder();
        this.setAustralianSubsidyAmount();
    }

    /**
     * Set some fields from LineItem to Opportunity
     *
     * @author Marko Schmalenbach
     * @since 2018-10-19
     */
    private void setOpportunityFieldsForOrder() {

        List<OpportunityLineItem> listOpportunityLineItems = (List<OpportunityLineItem>)Trigger.new;

        Map<Id, Opportunity> mapOpportunitiesByIdToUpdate = new Map<Id, Opportunity>();

        for (OpportunityLineItem oOpportunityLineItem : listOpportunityLineItems) {

            // Set ProductName of Bundle Product to Opportunity.ProductName__c (SOBCRM-1277)
            // OpportunityLineItem.ProductName__c is a formula referencing the Product. So if the
            // product name changes this won't automatically trigger this update here!
            if (oOpportunityLineItem.ProductRecordType__c == 'Bundle') {

                if (oOpportunityLineItem.OpportunityProductName__c != oOpportunityLineItem.ProductName__c) {

                    Opportunity oOpportunityToUpdate;

                    if (mapOpportunitiesByIdToUpdate.containsKey(oOpportunityLineItem.OpportunityId)) {
                        oOpportunityToUpdate = mapOpportunitiesByIdToUpdate.get(oOpportunityLineItem.OpportunityId);
                    }
                    else {
                        oOpportunityToUpdate = new Opportunity(Id = oOpportunityLineItem.OpportunityId);
                        mapOpportunitiesByIdToUpdate.put(oOpportunityToUpdate.Id, oOpportunityToUpdate);
                    }

                    oOpportunityToUpdate.ProductName__c = oOpportunityLineItem.ProductName__c;
                }
            }

            // Set BatteryCapacity of Battery product to Opportunity.BatteryCapacity__c
            // Notice: If the product's Battery Capacity changes this won't automatically trigger this update here!
            if (oOpportunityLineItem.ProductRecordType__c == 'Standard'
                    && oOpportunityLineItem.BatteryCapacity__c > 0
                    && oOpportunityLineItem.BatteryCapacity__c != oOpportunityLineItem.OpportunityBatteryCapacity__c) {

                Opportunity oOpportunityToUpdate;

                if (mapOpportunitiesByIdToUpdate.containsKey(oOpportunityLineItem.OpportunityId)) {
                    oOpportunityToUpdate = mapOpportunitiesByIdToUpdate.get(oOpportunityLineItem.OpportunityId);
                }
                else {
                    oOpportunityToUpdate = new Opportunity(Id = oOpportunityLineItem.OpportunityId);
                    mapOpportunitiesByIdToUpdate.put(oOpportunityToUpdate.Id, oOpportunityToUpdate);
                }

                oOpportunityToUpdate.BatteryCapacity__c = oOpportunityLineItem.BatteryCapacity__c;
            }
        }

        if (!mapOpportunitiesByIdToUpdate.isEmpty()) {
            update mapOpportunitiesByIdToUpdate.values();
        }
    }

    /**
     * ReSets the UnitPrice to the calculated Subsidy Amount
     *
     * AustraliaCalculatedSubsidyAmount__c is a formula referring to the
     * parent Opportunity's AustraliaCalculatedSubsidyAmount__c which calculates
     * the Australian Subsidy Amount according to the Customer's concession and
     * the ordered Battery Capacity
     *
     * @since 2018-10-10
     * @author Marko Schmalenbach
     * @see RESTServiceOrder_Test
     */
    private void setAustralianSubsidyAmount() {

        final String DEBUG_HERE = DEBUG_HEADER + 'setAustralianSubsidyAmount() - ';

        List<OpportunityLineItem> listOpportunityLineItems = (List<OpportunityLineItem>)Trigger.new;

        for (OpportunityLineItem oOpportunityLineItem : listOpportunityLineItems) {

            if (oOpportunityLineItem.ProductRecordType__c == 'Subsidy'
                && (Trigger.isInsert || (Trigger.isUpdate && oOpportunityLineItem.AustraliaCalculatedSubsidyAmountDoReset__c))) {

                Decimal fSubsidyAmount = oOpportunityLineItem.AustraliaCalculatedSubsidyAmount__c;

                if (fSubsidyAmount > 0) {
                    fSubsidyAmount *= -1;
                }

                System.debug(
                    DEBUG_HERE +
                    'Current Unit Price (Subsidy): ' + oOpportunityLineItem.UnitPrice + ', ' +
                    'New: ' + fSubsidyAmount
                );

                oOpportunityLineItem.UnitPrice = fSubsidyAmount;
            }

            oOpportunityLineItem.AustraliaCalculatedSubsidyAmountDoReset__c = false;
        }
    }
}