/**
 * AccountService
 * 
 * @version 1.0.0 (2017-12-13)
 *
 * Changelog
 * ---------
 *
 * v1.0.0 (DUR 2017-12-13, SOBCRM-1004)
 * - Initial version: Logic for retrieval of latest used DatevNumber, ie. of the first next available DatevNumber exported from
 * 	the LumenazaContractTriggerHandler, as the logic will be required in BankDataTriggerHandler as well.
 *
 */ 
public class AccountService {
    
    public static Integer getNextDatevNumber() {
        
        Integer maxDatevNo = getLastDatevNumber();
        Integer iNextCustomerNo = (maxDatevNo != null) ? ++maxDatevNo : 10000;
        
        return iNextCustomerNo;
    }

	public static Integer getLastDatevNumber() {
        
		List<Account> listAccountMaxDatevNo = new List<Account>([
			SELECT CustomerNoDatev__c
			FROM Account
			WHERE CustomerNoDatev__c != NULL
			ORDER BY CustomerNoDatev__c DESC
			LIMIT 1
		]);
        
        if (listAccountMaxDatevNo.size() == 1)
            return Integer.valueOf(listAccountMaxDatevNo[0].CustomerNoDatev__c);
        
        return null;
	}
    
    public static void updateAccountsCustomerDatevNumber(List<Account> accountsWithoutDatev) {
        
        Integer iNextCustomerNo = AccountService.getNextDatevNumber();
        AccountService.updateAccountsCustomerDatevNumber(accountsWithoutDatev, iNextCustomerNo);
    }
    
    public static void updateAccountsCustomerDatevNumber(List<Account> accountsWithoutDatev, Integer iNextCustomerNo) {
        
		for (Account oAccount : accountsWithoutDatev) {
			oAccount.CustomerNoDatev__c = String.valueOf(iNextCustomerNo);
			iNextCustomerNo++;
        }
        
		update accountsWithoutDatev;
    }
}