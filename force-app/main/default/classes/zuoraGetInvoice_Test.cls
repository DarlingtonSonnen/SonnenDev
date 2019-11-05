/*
 * Created by b.jarmolinski on 14/08/2018.
 *
 * The test provides coverage for the following classes:
 * - zuoraGetInvoiceScheduled
 * - zuoraGetInvoice
 * - zuoraGetInvoiceFiles_QueueableV2
 */

@isTest
public with sharing class zuoraGetInvoice_Test {

    @testSetup
    static void createData() {
        // map values contain zuora acccount id as written in the isTest snippet in the class zuoraGetInvoicesInBillRun
        Map<Integer, String> integersMap = new Map<Integer, String>{
                0 => '8adce4216446023d016460b7e49d22ef',
                1=>'8adc8f9964db2ff30164dbda26703d77',
                2=>'8adc8f99642160fb016436f524942e1d',
                3=>'8adce42161c1652f0161d1c06b746c3e'};

        // map of invoice names for invoice creation
        Map<Integer, String> integersMapInv = new Map<Integer, String>{
                0=>'INV00002420', 1=>'INV00002458', 2=>'INV00002487', 3=> 'INV00002488'
        };

        Map<Integer, String> integersMapInvId = new Map<Integer, String>{
                0=>'8adc857864c5c4ae0164c6653a9c0470', 1=>'8adc857864ea5f3d0164ea9e9aae021e',
                2=>'8adc9d2464ea5f8d0164f48037151dd5', 3=>'8adc9d2464ea5f8d0164f4803b441f55'
        };

        Map<String, String> namesMap = new Map<String, String>(); // map of account name and billing account IDs
        Map<String, String> nameMapInv = new Map<String, String>(); // map of account name and invoice number
        Map<String, String> nameMapInvId = new Map<String, String>(); // map of account name and invoice ID

        List<Account> accounts = new List<Account>();
        //RecordType rt = [SELECT Id FROM RecordType WHERE DeveloperName = 'Private' AND SobjectType = 'Account'];
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        for (Integer i=0; i<4; i++) {
            Account a = new Account();
            a.FirstName = 'prv'+i;
            a.LastName = 'account'+i;
            a.RecordTypeId = recordTypeId;
            a.PersonEmail = i+'account@test.de';
            accounts.add(a);

            namesMap.put(a.FirstName + ' ' + a.LastName, integersMap.get(i));
            nameMapInv.put(a.FirstName + ' ' + a.LastName, integersMapInv.get(i));
            nameMapInvId.put(a.FirstName + ' ' + a.LastName, integersMapInvId.get(i));
        }
        insert accounts;

        // create zuora billing accounts in salesforce
        Map<String, String> invNamesMap = new Map<String, String>();
        List<Zuora__CustomerAccount__c> customerAccounts = new List<Zuora__CustomerAccount__c>();
        for (Account a : accounts) {
            zuora__CustomerAccount__c ba = new zuora__CustomerAccount__c();
            ba.Name = a.FirstName + ' ' + a.LastName;
            ba.Zuora__Zuora_Id__c = namesMap.get(ba.Name);
            ba.Zuora__Account__c = a.Id;
            ba.Zuora__AccountNumber__c = 'A0000000x';
            ba.Zuora__BillToWorkEmail__c = a.PersonEmail;
            customerAccounts.add(ba);
        }
        insert customerAccounts;

        // create file in salesforce, to prove content document link will be created with the respective invoice
        // create content file and attach it to the Zuora__CustomerAccount__c in zuora
        ContentVersion cv = new ContentVersion();
        cv.VersionData = Blob.valueOf('file existing in salesforce');
        cv.Title = 'INVXX.pdf';
        cv.PathOnClient = 'INVXX';
        cv.ContentDocumentId = null;
        insert cv;

        // insert invoice objects
        List<Zuora__ZInvoice__c> invoices = new List<Zuora__ZInvoice__c>();
        for (zuora__CustomerAccount__c ba : customerAccounts) {
            Zuora__ZInvoice__c inv = new Zuora__ZInvoice__c();
            inv.Name = nameMapInv.get(ba.Name);
            inv.Zuora__Zuora_Id__c = nameMapInvId.get(ba.Name);
            inv.Zuora__BillingAccount__c = ba.Id;
            inv.Zuora__Account__c = ba.Zuora__Account__c;
            invoices.add(inv);
        }

        // create another invoice whose corresponding file would be already in salesforce
        Zuora__ZInvoice__c inv = new Zuora__ZInvoice__c();
        inv.Name = 'INVXX';
        inv.Zuora__BillingAccount__c = customerAccounts[0].Id;
        inv.Zuora__Account__c = customerAccounts[0].Zuora__Account__c;
        invoices.add(inv);

        insert invoices;

    }

    @isTest
    static void testMethod1() {

        // invoke the scheduled class
        zuoraGetInvoiceScheduled newJob = new zuoraGetInvoiceScheduled();
        Test.startTest();
        newJob.execute(null);
        Test.stopTest();

        Map<Id, Zuora__zInvoice__c> invoiceMap = new Map<Id, Zuora__zInvoice__c>([SELECT Id FROM Zuora__zInvoice__c]);
        Set<Id> IDs = invoiceMap.keySet();
        System.assertEquals(invoiceMap.size(), [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :IDs].size());

        Id invId = [SELECT Id FROM Zuora__zInvoice__c WHERE Name = 'INVXX'].Id;
        System.assertEquals(1, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :invId].size());
    }
}