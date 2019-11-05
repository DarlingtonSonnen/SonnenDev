/**
 * Trigger for Contract Standard object
 *
 * @see         ContractTriggerHandler.cls
 *
 * @version     2018-04-24 marko@die-interaktiven.de      		Added before insert and before update (SOBCRM-1177)
 * @version     2017-06-13 kevin.kolditz@die-interaktiven.de    first version
 *
 */
trigger TriggerContract on Contract (
	before insert,
	before update,
	before delete,
	after insert,
	after update) {

	new ContractTriggerHandler().run();
}