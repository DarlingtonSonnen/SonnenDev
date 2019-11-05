/**
 * AccountTriggerHandler
 *
 * Unit tests are done via class PortalAccountControllerTest
 *
 * Changelog
 * ---------
 *
 * v1.4.1 (MSB, 2017-11-24)
 * - Fixed getCustomerNumberString() wrong padding with i-1 to i
 *
 * v1.4.0 (MSB, 2017-10-18)
 * - Removed callout for partner portal (SOBCRM-974)
 *
 * v1.3.0 (MSB, 2017-04-10)
 * - setCustomerNo(): All accounts should get a customer no now (SOBCRM-888)
 *
 * v1.2.0 (MSB, 2016-12-16)
 * - portalCallout(): Limited to Partner Accounts
 *
 * @version 1.4.1 (2017-11-24)
 */
public class AccountTriggerHandler extends TriggerHandler {

    /**
     * Generate and set token to SBC accounts before upsert
     */
    public override void beforeUpdate() {
        this.setCustomerNo();
    }
    public override void beforeInsert() {
        this.setCustomerNo();
    }

    public override void afterInsert() {
    }

    public override void afterUpdate() {
    }

    /**
     * Set customer number for previously unnumbered contacts
     * Rule: Any account without CustomerNo__c must get a unique CustomerNo
     *
     * Changelog
     *
     * 2017-04-10 (MSB, SOBCRM-888)
     * - All accounts should get a customer no now
     *
     * 2016-11-15 (MSB)
     * - Query of accounts raised a soql limit exception so we try now to query
     *   all customer numbers with the same prefix and only of certain record
     *   types
     *
     * @see SOBCRM-160
     * @see SOBCRM-205
     * @see GeneralTests.testAccountNumber()
     */
    private void setCustomerNo() {

        String debugHere = 'AccountTriggerHandler.setCustomerNo() on ' + (Trigger.isInsert ? 'INSERT' : 'UPDATE') + ' - ';

        // Account that don't have a customer number should get a customer number
        List<Account> scopeAccounts = new List<Account>();

        String year = String.valueOf(Date.today().year()).right(2);
        Map<String,Set<String>> prefixesToCheck = new Map<String,Set<String>>();

        // Set customer number only if NOT Supplier and SBC (Partner)
        Map<String,Id> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Account'}).get('Account');
        // mapRecordTypes.remove('Supplier');
        // mapRecordTypes.remove('SBC');
        Set<Id> lsetValidRecordTypeIds = new Set<Id>(mapRecordTypes.values());

        for (Account oAccount : (List<Account>) Trigger.new) {
            if (lsetValidRecordTypeIds.contains(oAccount.RecordTypeId) && (oAccount.CustomerNo__c == '' || oAccount.CustomerNo__c == NULL)) {

                System.debug(debugHere + 'Account without CustomerNo__c (' + oAccount.CustomerNo__c + '): ' + oAccount.Name + ' (' + oAccount.Id + ')');

                scopeAccounts.add(oAccount);
                prefixesToCheck.put(
                        ((oAccount.BillingCountryCode != NULL) ? oAccount.BillingCountryCode : 'DE') + year,
                        new Set<String>()
                );
            }
        }

        if (scopeAccounts.isEmpty()) {
            return;
        }

        System.debug(debugHere + 'Prefixes to search existing customer numbers for: ' + prefixesToCheck.keySet());

        // Get customer numbers for each prefix (hopefully not too much :P)
        for (String prefixToCheck : prefixesToCheck.keySet()) {

            // prefix + 6 digits
            List<Account> listAccounts = Database.query('SELECT CustomerNo__c FROM Account WHERE CustomerNo__c LIKE \'' + prefixToCheck + '______\' ORDER BY CustomerNo__c ASC LIMIT 50000');

            if (!listAccounts.isEmpty()) {

                Set<String> lsetCustomerNo = new Set<String>();

                for (Account oAccount : listAccounts) {
                    lsetCustomerNo.add(oAccount.CustomerNo__c);
                }

                System.debug(debugHere + 'Count for prefix "' + prefixToCheck + '": ' + lsetCustomerNo.size());
                prefixesToCheck.put(prefixToCheck, lsetCustomerNo);
            }
        }

        for (Account oAccount : scopeAccounts) {

            String accountNumber;
            String prefix = ((oAccount.BillingCountryCode != NULL) ? oAccount.BillingCountryCode : 'DE') + year;
            Integer iterations = 0;
            Integer maxIterations = 1000000;

            // Try to get a new customer number randomly
            do {
                oAccount.CustomerNo__c = prefix + getCustomerNumberString();
                iterations++;
            }
            while (prefixesToCheck.get(prefix).contains(oAccount.CustomerNo__c) && iterations < maxIterations);

            // Max iterations reached, customer no is not unique so far
            // (just in case ;)
            if (iterations == maxIterations) {
                oAccount.CustomerNo__c = NULL;
            }
            else {
                // Add current which is no more available now
                prefixesToCheck.get(prefix).add(oAccount.CustomerNo__c);
            }

            System.debug(debugHere + 'Created new customer number "' + oAccount.CustomerNo__c + '" for Account ' + oAccount.Name + ' (' + oAccount.Id + ') after ' + iterations + ' iteration(s)');
            //System.debug(debugHere + 'prefixesToCheck: ' + prefixesToCheck);
        }
    }

    /**
     * Wraps two utility methods that have to be called to
     */
    private String getCustomerNumberString() {

        Integer i = 6; // set how long the number component of the customer number should be

        return DiaUtilities.padWithZero(String.valueOf(DiaUtilities.generateRandomNumber(i)), i);
    }

    public class AccountTriggerHandlerException extends Exception {}

}