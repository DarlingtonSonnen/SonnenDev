/**
 * LumenazaContractTriggerHandler
 *
 * Changelog
 * ---------
 *
 * v1.11.0-2018-04-26 (MSB)
 * - Moved to ContractTriggerHandler (SOBCRM-1177)
 *
 * v1.10.0-2018-04-10 (MSB)
 * - Added afterInsert() to respond to cloning at contract changes (SOBCRM-1164)
 *
 * v1.9.0 (MSB 2017-12-20)
 * - Deactivated calling of saveVoucherCodeAsBonus() (SOBCRM-1123)
 *
 * v1.8.0 (DUR 2017-12-19)
 * - Handle Account's CustomerNoDatev__c by AccountService
 *
 * v1.7.0 (MSB 2017-06-19)
 * - Basic Lumenaza sync requirements are now checked by formula field
 *   Contract.IsValidForLumenazaSync__c
 *
 * v1.6.1 (MSB 2017-03-24)
 * - Fix: Set CustomerNoDatev__c in all related Accounts independent of
 *   the Contract's acitvation status (SOBCRM-912)
 * - Fix: Did NOT validate LumenazaApi.initUpsert(lumenazaContractsToUpsert) to FALSE so
 *   no error was raised from LumenazaContract.validate()
 *
 * v1.6.0 (DUR 2017-02-21)
 * - SOBCRM-803 - Bonus should not be created for Type 'sonnenbatterieCity-DE'
 *
 * v1.5.1 (MSB 2016-12-21)
 * - Fix: If BankData relation was NULL but bank account relevant fields were
 *   set all fields were set to NULL. Now they are only set to NULL if BankData
 *   relation changed from NOT NULL to NULL
 *
 * v1.5.0 (MSB 2016-12-20)
 * - Added setBankDataFromRelatedBankData() on insert (SOBCRM-754)
 *
 * v1.4.0 (MSB 2016-12-16)
 * - Added handling of adding new Contracts to existing Lumenaza Customers
 *   (SOBCRM-763)
 *
 * @version v1.11.0-2018-04-26
 * @see TriggerLumenazaContract
 */
public class LumenazaContractTriggerHandler extends TriggerHandler {


}