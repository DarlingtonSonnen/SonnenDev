/**
 * LumenazaContractDeliverySched
 *
 * Schedulable for LumenazaContractDeliveryBatch
 *
 * Changelog
 * ---------
 *
 * v1.0.0-2018-01-11 (marko@die-interaktiven.de)
 * - Initial (SOBCRM-1025)
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.0.0-2018-01-11
 * @see https://interaktiv.jira.com/browse/SOBCRM-1025
 * @see LumenazaContractDeliveryBatch
 * @see LumenazaContractBatchTests
 */
global class LumenazaContractDeliverySched implements Schedulable {

    /**
     * execute
     */
    global void execute(SchedulableContext context) {
        LumenazaContractDeliveryBatch oLumenazaContractDeliveryBatch = new LumenazaContractDeliveryBatch();
        Database.executeBatch(oLumenazaContractDeliveryBatch, LumenazaContractDeliveryBatch.MAX_CONTRACTS_IN_BATCH);
    }
}