/**
* Test Class for Batch Process
* 
* @see ResetUSAccountFieldsBatch.cls 
* @see ResetUSAccountFieldsBatchSchedule.cls
* 
* 2018-02-21 version 1.0  Muchow, Michael sonnen GmbH
*
* @version 1.0
*/

@isTest
private class ResetUSAccountFieldsBatchTest {
    
    // Test with filled US Accounts
    @isTest static void testFilledAccounts() {
        Account[] accounts = new List<Account>();
        Id recordID = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'SBC'].Id;
                
        for (Integer i=0; i<100; i++) {
            Account a = new Account(
                RecordTypeId = recordID,
                Name = 'testAccount'+i,
                AuthorizedMDF__c = 123 + Decimal.valueOf(i),
                UsedMDF__c = 456 + Decimal.valueOf(i),
                MDPSubmitted__c = Date.TODAY().AddDays(i),
                BillingCountryCode ='US');
            accounts.add(a);
        }
        insert accounts;
		
        Test.startTest();
        
        ResetUSAccountFieldsBatch raBatch = new ResetUSAccountFieldsBatch();
        Database.executeBatch(raBatch);
        
        Test.stopTest();

        Integer i =[SELECT COUNT() FROM Account WHERE 
                    RecordType.DeveloperName = 'SBC'
                    AND BillingCountryCode ='US'
                    AND (AuthorizedMDF__c != NULL 
                    OR MDPSubmitted__c != NULL 
                    OR UsedMDF__c != NULL)];
        System.assertEquals(0, i);
    }

    // Test with empty US Accounts
    @isTest static void testEmptyAcccounts() {
        Account[] accounts = new List<Account>();
        Id recordID = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'SBC'].Id;
                
        for (Integer i=0; i<100; i++) {
            Account a = new Account(
                RecordTypeId = recordID,
                Name = 'testAccount'+i,
                BillingCountryCode ='US');
            accounts.add(a);
        }
        insert accounts;
		
        Test.startTest();
        
        ResetUSAccountFieldsBatch raBatch = new ResetUSAccountFieldsBatch();
        Database.executeBatch(raBatch);
        
        Test.stopTest();

        Integer i =[SELECT COUNT() FROM Account WHERE 
                    RecordType.DeveloperName = 'SBC'
                    AND BillingCountryCode ='US'
                    AND (AuthorizedMDF__c != NULL 
                    OR MDPSubmitted__c != NULL 
                    OR UsedMDF__c != NULL)];
        System.assertEquals(0, i);
    }

    // Test for schedule apex job
    @isTest static void testScheduleBatch() {
        Test.startTest();
        String sch = '0 0 0 2 2 ? *';
        String jobID = System.schedule('Run Batch Schedule', sch, new ResetUSAccountFieldsBatchSchedule());

        System.assert([SELECT ID, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE ID =: jobID].size()!=0);
    }
}