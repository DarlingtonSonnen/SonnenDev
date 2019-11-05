/**
 * LumenazaContractInvoiceSched
 *
 * Schedlable to query Lumenaza Invoices for Contracts.
 * Can be run daily as synchronizer updates Payment__c objects only on
 * changes.
 *
 * Tested by LumenazaTest.testLumenazaContractInvoiceSynchronizerScheduler()
 *
 * Changelog
 * ---------
 *
 * v1.1.0 (2017-09-11)
 * - Get current month and last month
 *
 * v1.0.0 (2017-04-26)
 * - Initial version
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.1.0 (2017-09-11)
 * @see https://interaktiv.jira.com/browse/SOBCRM-705
 * @see LumenazaContractInvoiceSynchronizer
 * @see LumenazaTest.testLumenazaContractInvoiceSynchronizerScheduler()
 */
global class LumenazaContractInvoiceSched implements Schedulable, Database.AllowsCallouts {

    /**
     * execute
     */
    global void execute(SchedulableContext context) {
        // Get current month asynchronously
        LumenazaContractInvoiceSynchronizer.executeSynchronizer('summarized', System.today().year(), System.today().month());
        // Get last month asynchronously
        LumenazaContractInvoiceSynchronizer.executeSynchronizer('summarized', System.today().year(), System.today().addMonths(-1).month());
    }
}