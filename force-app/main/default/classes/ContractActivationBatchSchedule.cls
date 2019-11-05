/**
 * Schedule for automatic Contract Activation Batch.
 * Only Contracts with the RecordType 'Energy' or 'SonnenFlat' should be affected.
 *
 * @see        ContractActivationBatch.cls
 *
 * @version    2016-12-05 dino.ursic@die-interaktiven.de        SOBCRM-694 - Batch Job Energy Contract Aktivierung
 *                 
 */ 
global class ContractActivationBatchSchedule implements Schedulable {
   global void execute(SchedulableContext sc) {
      ContractActivationBatch caBatch = new ContractActivationBatch();
      database.executebatch(caBatch);
   }
}