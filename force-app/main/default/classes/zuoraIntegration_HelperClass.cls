/**
 * Created by b.jarmolinski on 19/09/2018.
 * the class contains @invocable method and can be called from process builder
 * the invocable method instantiates queueable zuoraIntegrationV2 and this way it makes the queueable invocable from the process builder
 *
 * Version 2.0 on 16/01/2019
 * - Added query to zuoraSetting__mdt to get toggle switch value
 * - added logic which halts execution of prepayment amendment if the switch is set to false
 */


public with sharing class zuoraIntegration_HelperClass {

    @InvocableMethod(description='temporary solution until zuoraIntegrationV2 can be incorporated into contract trigger and trigger handler')
    public static void queNewPrepayment (List<Contract> cList) {

        zuoraSetting__mdt settings = ZuoraSettings.getZuoraSetting();
        // invoke queueable, pass list of contracts if the feature is on

        if (settings.TriggerSwitchAmendPrepayment__c || Test.isRunningTest()) {
            zuoraIntegrationV2 zuoraInt = new zuoraIntegrationV2(cList, 'prepayment');
            System.enqueueJob(zuoraInt);
        }
    }
}