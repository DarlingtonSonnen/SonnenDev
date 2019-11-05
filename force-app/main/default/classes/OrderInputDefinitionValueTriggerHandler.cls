/**
 * OrderInputDefinitionValueTriggerHandler
 *
 * v1.0     2018-05-24  Alexey Yamaev       Original Values are populated on create (SOBCRM-1193)
 */

public class OrderInputDefinitionValueTriggerHandler extends TriggerHandler {

    public override void beforeInsert() {
        initializeOriginalValues();
    }

    private void initializeOriginalValues() {
        List<OrderInputDefinitionValue__c> oidValues = (List<OrderInputDefinitionValue__c>) Trigger.new;
        for (OrderInputDefinitionValue__c oidValue : oidValues) {
            oidValue.OriginalValue__c = oidValue.Value__c;
        }
    }
}