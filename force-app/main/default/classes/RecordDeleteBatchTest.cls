/**
 * Test class RecordDeleteBatch class.
 *
 * @see         RecordDeleteBatch.cls
 *
 * @version     2016-06-14 kevin.kolditz@die-interaktiven.de      first version
 * 			    
 */	


@isTest
private class RecordDeleteBatchTest {

    static {

        createTestAccounts();
    }
	
	@isTest static void testBatch() {

		RecordDeleteBatch recDel = new RecordDeleteBatch('Account');
		Database.executeBatch(recDel);
    }	

	@isTest static void testBatchWithWhereClause() {

		RecordDeleteBatch recDel = new RecordDeleteBatch('Account', 'Id != null');
		Database.executeBatch(recDel);
    }	

	@isTest static void createTestAccounts() {


        List<Account> accounts = new List<Account>();
        Account acct;
        
        for (integer count=0;count<10;count++) {
        
            acct = new Account();
            acct.Name='TestAccount '+count;
            accounts.add(acct);
        }
        
        insert accounts;
    }	
	
}