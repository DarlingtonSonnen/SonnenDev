/**
 * Test class for Batch for migration of bank data from Contract to BankData__c object.
 *
 * @see        ContractBankDataMigrationBatch.cls
 *
 * @version    2018-04-12 marko@die-interaktiven.de         SOBCRM-1164 - Set LumenazaSkipApiCall__c to true to skip check on multiple Contracts for one Account
 * @version    2016-12-14 dino.ursic@die-interaktiven.de    SOBCRM-733 - Bank Data in Contract REST API einbinden (Teil 2: Datenmigration)
 *
 */
@isTest
private class ContractBankDataMigrationBatchTest {

    static testmethod void test() {

        // The query used by the batch job.
        /*
        String query = 'SELECT Id, AccountId, Account.MandateReferenceNumber__c, Account.CustomerNoDatev__c, ' +
                              'BankDataFirstname__c, ' +
                              'BankDataLastname__c, ' +
                              'BankDataSWIFT__c, ' +
                              'BankDataIBAN__c, ' +
                              'SEPADate__c ' +
                        'FROM Contract ' +
                        'WHERE BankData__c = NULL AND AccountId != NULL AND BankDataIBAN__c != NULL';
        */

       Account testAcc = new Account(Name='Test Account', CustomerNoDatev__c = '10000');
       insert testAcc;

       // Create some test Contracts with BankData information to be migrated to separate BankData records by the batch job.
       Contract[] contracts = new List<Contract>();
       for (Integer i=0;i<50;i++) {
           Contract c = new Contract(
               RecordTypeId = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Contract' AND DeveloperName = 'Energy'].Id,
               Type__c = 'sonnenbatterieHome-DE',
               TariffType__c = 'household',
               AccountId = testAcc.Id,
               BankDataFirstname__c = 'Name ' + i,
               BankDataLastname__c = 'Lastname ' + i,
               BankDataSWIFT__c ='SOLADESKU' + String.valueOf(i).leftPad(2, '0'),
               BankDataIBAN__c = 'DE65234000932013139' + String.valueOf(i).leftPad(2, '0'),
               LumenazaSkipApiCall__c = true, // to skip check on multiple Contracts for one Account
               SEPADate__c = Date.today());
           contracts.add(c);
       }
       insert contracts;

       Test.startTest();
       ContractBankDataMigrationBatch c = new ContractBankDataMigrationBatch();
       Database.executeBatch(c);
       Test.stopTest();

       // Verify BankData records got created
       Integer i = [SELECT COUNT() FROM BankData__c];
       System.assertEquals(i, 50);
    }
}