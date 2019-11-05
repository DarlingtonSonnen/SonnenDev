/**
 * AccountServiceTest
 * 
 * @author	dino.ursic@die-interaktiven.de
 * @desc	Test class for AccountService
 * @version 1.0.0 (2017-12-14)
 */ 
@isTest
public class AccountServiceTest {

    public static testMethod void testLastDatevNo() {
        
        Account acc = new Account(Name='ACME GmbH', CustomerNoDatev__c='55555');
        insert acc;
        
        Integer lastDatevNo = AccountService.getLastDatevNumber();
        system.assertEquals(Integer.valueOf(acc.CustomerNoDatev__c), lastDatevNo, 'Expected to get the same lastDatevNumber from AccountService as in the data set up for test.');
    }
    
    public static testMethod void testNextDatevNoWithExistingAccounts() {
        
        Account acc = new Account(Name='ACME GmbH', CustomerNoDatev__c='55555');
        insert acc;
        
        Integer nextDatevNo = AccountService.getNextDatevNumber();
        system.assertEquals(Integer.valueOf(acc.CustomerNoDatev__c)+1, nextDatevNo, 'Expected to get nextDatevNumber from AccountService same as in the data set up for test incremented by one.');
    }
    
    public static testMethod void testNextDatevNoWithoutExistingAccounts() {
        
        Integer nextDatevNo = AccountService.getNextDatevNumber();
        system.assertEquals(10000, nextDatevNo, 'Expected to get 10000 as nextDatevNumber from AccountService, since there were no Accounts with Datev No set up for the test.');
    }
    
    public static testMethod void testUpdateAccountsCustomerDatevNumber() {
        
        // Reference account with the latest CustomerNoDatev
        Account refAcc = new Account(Name='ACME GmbH', CustomerNoDatev__c='55555');
        insert refAcc;
        
        // Test accounts without CustomerNoDatev
        List<Account> accs = new List<Account>();
        accs.add(new Account(Name='ACME New 1 GmbH'));
        accs.add(new Account(Name='ACME New 2 GmbH'));
        insert accs;
        
        // Verfiy accounts were inserted without errors
        system.assert(accs.get(0).Id != null);
        system.assert(accs.get(1).Id != null);
        
        // Verify accounts have no CustomerNoDatev
        system.assert(String.isBlank(accs.get(0).CustomerNoDatev__c));
        system.assert(String.isBlank(accs.get(1).CustomerNoDatev__c));
        
        // Invoke AccountService logic for assigning CustomerNoDatev to the accounts
        AccountService.updateAccountsCustomerDatevNumber(accs);
        
        // Verify CustomerNoDatev was added to the accounts
        system.assert(String.isNotBlank(accs.get(0).CustomerNoDatev__c));
        system.assert(String.isNotBlank(accs.get(1).CustomerNoDatev__c));
        
        // Verify CustomerNoDatev was propperly incremented
        system.assertEquals(Integer.valueOf(refAcc.CustomerNoDatev__c)+1, Integer.valueOf(accs.get(0).CustomerNoDatev__c));
        system.assertEquals(Integer.valueOf(refAcc.CustomerNoDatev__c)+2, Integer.valueOf(accs.get(1).CustomerNoDatev__c));
    }
}