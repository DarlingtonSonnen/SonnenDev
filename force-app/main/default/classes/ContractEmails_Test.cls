/**
 * Created by b.jarmolinski on 26/09/2018.
 * THe unit test provides coverage for the class ContractEmails_schedulable
 */

@isTest
public with sharing class ContractEmails_Test {

    @testSetup
    static void createTestData() {

        Id recTypeAccount = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        List<Account> accounts = new List<Account>();
        for (Integer i=0; i < 5; i++) {
            Account a = new Account();
            a.FirstName = 'Test';
            a.LastName = String.valueOf(i);
            a.PersonEmail = i+'new@sonnen.com';
            a.RecordTypeId = recTypeAccount;
            if(i == 0) {
                a.BillingCountryCode = 'FR';
            } else {
                a.BillingCountryCode = 'DE';
            }
            accounts.add(a);
        }
        insert accounts;


        Map<Id, Id> contactMap = new Map<Id, Id>(); // account Id as key, contact Id as value
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact];
        for (Contact c : contacts) {
            contactMap.put(c.AccountId, c.Id);
        }
        System.debug(contacts);
        System.debug(contactMap);
        // create contracts sonnenStrom solar, plus, start and sonnen flat
        List<Contract> contracts = new List<Contract>();
        Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName();


        //sonnenStrom Start
        Contract c0 = new Contract(
                ConfirmedDeliveryStart__c = Date.today(),
                TariffType__c = 'sonnenStrom',
                AccountId = accounts[0].Id,
                Type__c = 'Start',
                FinancialServiceProvider__c = 'Zuora',
                RecordTypeId = recordTypes.get('sonnenStrom').getRecordTypeId(),
                CustomerSignedId = contactMap.get(accounts[0].Id)
        );
        contracts.add(c0);

        //sonnenStrom Plus
        Contract c1 = new Contract(
                ConfirmedDeliveryStart__c = Date.today(),
                TariffType__c = 'sonnenStrom',
                AccountId = accounts[1].Id,
                Type__c = 'Plus',
                FinancialServiceProvider__c = 'Zuora',
                RecordTypeId = recordTypes.get('sonnenStrom').getRecordTypeId(),
                CustomerSignedId = contactMap.get(accounts[1].Id)
        );
        contracts.add(c1);

        //sonnenStrom Solar
        Contract c2 = new Contract(
                ConfirmedDeliveryStart__c = Date.today(),
                TariffType__c = 'sonnenStrom',
                AccountId = accounts[2].Id,
                Type__c = 'Solar',
                FinancialServiceProvider__c = 'Zuora',
                RecordTypeId = recordTypes.get('sonnenStrom').getRecordTypeId(),
                CustomerSignedId = contactMap.get(accounts[2].Id)
        );
        contracts.add(c2);

        //sonnenFlat
        Contract c3 = new Contract(
                ConfirmedDeliveryStart__c = Date.today(),
                TariffType__c = 'sonnenFlat',
                AccountId = accounts[3].Id,
                Type__c = 'sonnenbatterieHome-DE',
                FinancialServiceProvider__c = 'Zuora',
                Tariff_Version__c = 'sFh 2.0',
                RecordTypeId = recordTypes.get('SonnenFlat').getRecordTypeId(),
                CustomerSignedId = contactMap.get(accounts[3].Id)
        );
        contracts.add(c3);

        // sonnenFlat with confirmed delivery yesterday - not to be sent
        Contract c4 = new Contract(
                ConfirmedDeliveryStart__c = Date.today().addDays(-1),
                TariffType__c = 'sonnenFlat',
                AccountId = accounts[4].Id,
                Type__c = 'sonnenbatterieHome-DE',
                FinancialServiceProvider__c = 'Zuora',
                Tariff_Version__c = 'sFh 2.0',
                RecordTypeId = recordTypes.get('SonnenFlat').getRecordTypeId(),
                CustomerSignedId = contactMap.get(accounts[4].Id)
        );
        contracts.add(c4);

        insert contracts;
    }

    @isTest
    static void test1() {

        ContractEmails_Schedulable newInst = new ContractEmails_Schedulable();

        Test.startTest();
        newInst.execute(null);
        Test.stopTest();

        // 3 emails should be sent - only to DE accounts with confirmed delivery data today
        System.assertEquals(3, [SELECT Id FROM EmailMessage].size());

        // assertion: take template ID from settings which are for sonnenFlat and compare its subject with the subject of
        // email message sent from the sonnenFlat contract
        Id contractId = [SELECT Id FROM Contract WHERE RecordType.DeveloperName = 'sonnenFlat' LIMIT 1].Id;
        String actualSubject = [SELECT Subject FROM EmailMessage WHERE RelatedToId = :contractId LIMIT 1 ].Subject;
        String templateId = [SELECT sonnenFlat_SupplyStart__c FROM ContractEmailSetting__mdt LIMIT 1].sonnenFlat_SupplyStart__c;
        String expectedSubject = [SELECT Subject FROM EmailTemplate WHERE Id =:templateId LIMIT 1].Subject;

        System.assertEquals(actualSubject, expectedSubject);
    }

    @isTest
    static void test2() {

        List<Contract> contracts = [SELECT Id, ConfirmedDeliveryStart__c, TariffType__c, Type__c, RecordTypeId, Tariff_Version__c,
                                    CustomerSignedId, CustomerSigned.Email, RecordType.DeveloperName, Account.BillingCountryCode
                                    FROM Contract];

        System.debug(contracts);

        Test.startTest();
        ContractEmails_Schedulable.sendDeliveryDateEmails(contracts);
        Test.stopTest();

        // 4 emails should be sent - only to DE accounts
        System.assertEquals(4, [SELECT Id FROM EmailMessage].size());

    }
}