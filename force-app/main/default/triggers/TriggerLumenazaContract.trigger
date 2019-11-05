/**
 * Trigger for Lumenaza Contracts
 *
 * This should be moved to the general TriggerContract!
 *
 * Changelog
 * ---------
 *
 * v1.2.0-2018-04-27 (marko@die-interaktiven.de)
 * - Moved everything to ContractTriggerHandler (SOBCRM-1177)
 *
 * v1.1.0-2018-04-10
 * - Added "after insert" for cloning (SOBCRM-1164)
 *
 * @version v1.1.0-2018-04-10
 */
trigger TriggerLumenazaContract on Contract (
	after insert,
    after update,
    before insert,
    before update) {

	// moved to ContractTriggerHandler
}