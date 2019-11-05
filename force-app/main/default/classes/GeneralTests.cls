/**
 * General Tests
 *
 * Changelog
 * ---------
 * v1.1.0   2018-07-26  Marko Schmalenbach          Improved CustomerNo__c test to check if it changes after an update
 */
@isTest
private class GeneralTests {

    @testSetup static void setup() {

    }

    /**
     * Tests AccountTriggerHandler.setCustomerNo()
     *
     * Changelog:
     *
     * 2016-11-15 (MSB)
     * -  Set record types
     */
    @isTest
    static void testAccountNumber() {

        final String DEBUG_HERE = 'GeneralTests.testAccountNumber() - ';

        Map<String,Id> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Account'}).get('Account');

        System.debug(DEBUG_HERE + 'First Account to simulate already existing Account');
        insert new Account(Name = 'SchonDa', BillingCountryCode = 'US', CustomerNo__c = 'US150123456');

        Test.startTest();

        List<Account> lAccs = new List<Account>{
            new Account(BillingCountryCode = 'DE', RecordTypeId = mapRecordTypes.get('Private')        , FirstName = 'Hans', LastName = 'Wurst'),
            new Account(BillingCountryCode = 'AT', RecordTypeId = mapRecordTypes.get('BusinessAccount'), Name = 'TestAccountAT'),
            new Account(BillingCountryCode = ''  , RecordTypeId = mapRecordTypes.get('Ambassador')     , Name = 'TestAccountVoid'),
            new Account(BillingCountryCode = 'US', RecordTypeId = mapRecordTypes.get('BusinessAccount'), Name = 'TestAccountUS', CustomerNo__c = 'US140123456'),
            new Account(BillingCountryCode = 'CH', RecordTypeId = mapRecordTypes.get('Supplier')       , Name = 'TestAccountCH') // won't have a customer no
        };

        System.debug(DEBUG_HERE + 'Insert ' + lAccs.size() + ' new Accounts');
        List<Database.SaveResult> sr = Database.insert(lAccs, false);

        Test.stopTest();

        Map<Id, Account> mapAccountsByIds = new Map<Id, Account>([SELECT Id, CustomerNo__c FROM Account]);
        System.assertEquals(6, mapAccountsByIds.size(), 'Test failure. 6 Accounts should have been created but more or less were actually created');

        List<Account> listAccountsWithoutCustomerNo = [SELECT Id FROM Account WHERE CustomerNo__c = NULL];
        System.assertEquals(0, listAccountsWithoutCustomerNo.size(), 'All Accounts should now have a customer no');

        System.debug(DEBUG_HERE + 'Update ' + lAccs.size() + ' existing Accounts');
        update mapAccountsByIds.values();

        Map<Id, Account> mapAccountsByIdsToCheck = new Map<Id, Account>([SELECT Id, CustomerNo__c FROM Account WHERE Id IN :mapAccountsByIds.keySet()]);

        for (Id idAccount : mapAccountsByIds.keySet()) {
            System.assertEquals(
                mapAccountsByIds.get(idAccount).CustomerNo__c,
                mapAccountsByIdsToCheck.get(idAccount).CustomerNo__c,
                'CustomerNo__c MUST not be changed after update'
            );
        }
    }
}