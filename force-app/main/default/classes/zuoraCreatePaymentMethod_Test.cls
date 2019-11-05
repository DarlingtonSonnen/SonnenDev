/**
 * Created by b.jarmolinski on 01/08/2018.
 */

@IsTest
private class zuoraCreatePaymentMethod_Test {

    @testSetup
    static void createData() {
        // create Account
        // create contact
        // create Billing account
        // create webOrder Opportunity
        // create quote

        // fill populate subscription Id

        RecordType accRT = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Private' LIMIT 1];
        Account a = new Account(FirstName='Test', LastName='Account', PersonEmail ='test@nothingelsematters.com', RecordTypeId = accRT.Id, BillingCountryCode = 'DE', PersonMailingCountryCode='DE');
        insert a;

        Zuora__CustomerAccount__c zAccount = new Zuora__CustomerAccount__c(Name = 'Test Account', Zuora__Zuora_Id__c = '8adc8f99648e57e401648ebf977f63b4',
                Zuora__Account__c = a.Id, Zuora__AccountNumber__c = 'A00000057',
                Zuora__Status__c = 'Active', Zuora__BillToId__c = '8adc8f99648e57e401648ebf978663b5',
                Zuora__SoldToId__c = '8adc8f99648e57e401648ebf978663b5');
        insert zAccount;

        Id contactId = [SELECT PersonContactID FROM Account WHERE Id = :a.Id].PersonContactID;

        RecordType oppRT = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND DeveloperName = 'WebOrder' LIMIT 1];
        Opportunity opp = new Opportunity();
        opp.RecordTypeId = oppRT.Id;
        opp.Name = 'Web Order 19.02.2018 18:33:46 GMT';
        opp.StageName = 'Requested';
        opp.CloseDate = Date.today();
        opp.OrderSource__c = '{ "type":"Order", "id":"6a701448-12ca-45d1-b28a-6a7f0e7c980d", "version":1, "createdAt":"2018-05-03T14:09:25.364Z", "lastModifiedAt":"2018-05-03T14:09:25.364Z", "totalPrice":{ "type":"centPrecision", "currencyCode":"EUR", "centAmount":2478, "fractionDigits":2 }, "taxedPrice":{ }, "orderState":"Open", "syncInfo":[ ], "returnInfo":[ ], "taxMode":"Disabled", "inventoryMode":"None", "taxRoundingMode":"HalfEven", "taxCalculationMode":"LineItemLevel", "origin":"Customer", "lineItems":[ ], "customLineItems":[ ], "transactionFee":true, "discountCodes":[ ], "lastMessageSequenceNumber":1, "cart":{ }, "custom":{ "type":{ "typeId":"type", "id":"b5673dbe-055b-44bf-ab79-48629089e724" }, "fields":{ "cWithdrawal":true, "cTermsAndConditionSolandeo":true, "cTermsAndConditionDiscovergy":false, "cTermsAndConditionSonnen":true, "cPaymentIban":"DE24545500100000843086", "cPaymentBic":"LUHSDE6AXXX", "cPaymentName":"Manfred Schw\u00e4ger" } }, "shippingAddress":{ }, "billingAddress":{ }, "itemShippingAddresses":[ ] }';
        opp.FirstName__c = 'Max';
        opp.LastName__c = 'Mustermann';
        opp.BillingStreet__c = 'Waldsteinstraße';
        opp.BillingStreetNo__c = '13';
        opp.BillingPostalCode__c = '95237';
        opp.BillingCity__c = 'Weissdorf';
        opp.BillingCountry__c = 'DE';
        opp.ShippingStreet__c = 'Einzelstraße';
        opp.ShippingStreetNo__c = '44';
        opp.ShippingPostalCode__c = '95234';
        opp.ShippingCity__c = 'Sparneck';
        opp.ShippingCountry__c = 'DE';
        insert opp;

        // create bank data
        BankData__c bd = new BankData__c();
        bd.SepaDate__c = Date.today();
        bd.IBAN__c = 'DE1234500004567';
        bd.FirstName__c = 'Random';
        bd.LastName__c = 'Guy';
        bd.IBANCheckResult__c = 'passed';
        bd.Account__c = a.Id;
        bd.SepaDate__c = Date.today();
        bd.SepaReference__c = '267910000001';
        insert bd;

        // create contract
        Contract ctr = new Contract();
        Id contrRecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Contract' AND DeveloperName = 'sonnenStrom' LIMIT 1].Id;
        ctr.StartDate = Date.today();
        ctr.RecordTypeId = contrRecordTypeId;
        ctr.OpportunitySource__c = opp.Id;
        ctr.BankData__c = bd.Id;
        ctr.TariffType__c = 'sonnenStrom';
        ctr.Type__c = 'Start';
        ctr.AccountId = a.Id;
        insert ctr;
        // create bank data

        zqu__Quote__c qt = new zqu__Quote__c();
        qt.zqu__Opportunity__c = opp.Id;
        qt.zqu__Status__c = 'Sent to Z-Billing';
        qt.zqu__Primary__c = true;
        qt.zqu__BillToContact__c = contactId;
        qt.zqu__SoldToContact__c = contactId;
        qt.zqu__StartDate__c = Date.today();
        qt.zqu__Customer_Acceptance_Date__c = Date.today();
        qt.zqu__Subscription_Term_Type__c = 'Evergreen';
        qt.zqu__Service_Activation_Date__c = Date.today();
        qt.zqu__ZuoraAccountId__c = zAccount.Zuora__Zuora_Id__c;
        qt.zqu__Zuora_Account_Number__c = 'A00000057';
        qt.Contract__c = ctr.Id;
        qt.zqu__ZuorasubscriptionId__c = '';

        insert qt;

        Zuora__Subscription__c sb = new Zuora__Subscription__c();
        sb.Zuora__Account__c = a.Id;
        sb.Zuora__CustomerAccount__c = zAccount.Id;
        sb.Zuora__CustomerAccount__c = zAccount.Id;
        sb.Zuora__SubscriptionStartDate__c = Date.today();
        sb.Zuora__TermSettingType__c = 'EVERGREEN';
        sb.Zuora__MRR__c = 53.2;
        sb.Zuora__Zuora_Id__c = '8adc8f9965f18a3701660ae3400b34f6';
        sb.Zuora__Status__c = 'Active';
        sb.Zuora__TermStartDate__c = Date.today();
        sb.Zuora__Version__c = 1;
        sb.Zuora__ServiceActivationDate__c = qt.zqu__StartDate__c;
        sb.Zuora__ContractEffectiveDate__c = Date.today();
        sb.Zuora__ContractAcceptanceDate__c = qt.zqu__Customer_Acceptance_Date__c;
        sb.Zuora__QuoteNumber__c = [SELECT zqu__Number__c FROM zqu__Quote__c WHERE Id = :qt.Id].zqu__Number__c;

        insert sb;

    }

    @IsTest
    static void testMethod1() {
        // tests trigger on zqu__Quote__c and createPaymentMethod logic launched by it

        zqu__Quote__c qt = [SELECT zqu__ZuorasubscriptionId__c FROM zqu__Quote__c LIMIT 1 ];

        qt.zqu__ZuorasubscriptionId__c = '8adc8f9964ea660b0164f49f84c013e1';

        Test.startTest();
        update qt;
        Test.stopTest();

        System.assert(!String.isBlank(qt.zqu__ZuorasubscriptionId__c));
    }

    @isTest
    static void testMethod2() {
        // test changing bank data on contract

        // create new bank data
        // create bank data
        BankData__c bd = new BankData__c();
        bd.SepaDate__c = Date.today();
        bd.IBAN__c = 'DE1234500004568';
        bd.FirstName__c = 'Random';
        bd.LastName__c = 'Guy';
        bd.IBANCheckResult__c = 'passed';
        bd.Account__c = [SELECT Id FROM Account WHERE Name = 'Test Account'].Id;
        bd.SepaDate__c = Date.today();
        bd.SepaReference__c = '267910000002';
        insert bd;

        // link to the existing contract
        Contract ct = [SELECT Id, BankData__c FROM Contract LIMIT 1];
        ct.BankData__c = bd.Id;

        //update ct; // commented out not to launch process builder which calls the invocable method updateZuoraPayment

        List<Contract> contracts = new List<Contract>{ct};
        Test.startTest();
        zuoraCreatePaymentMethod.updateZuoraPayment(contracts);
        Test.stopTest();

        System.assertEquals(2, [SELECT Id FROM ZuoraSync__c WHERE Process__c = 'creation payment method'].size() );
    }
}