/**
 * Created by a.romero on 18/09/2019.
 */

@IsTest
private class showAllContractsTest {
    @TestSetup
    static void testSetup() {

        Map<String,Map<String,Id>> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Contract'});

        // Create contract and corresponding objects
        List<Account> listAccounts = new List<Account>{
                new Account(Name = 'ACME Inc.'),
                new Account(Name = 'Bonus Corp.'),
                new Account(Name = 'Bogus Company'),
                new Account(Name = 'Disney Org')
        };
        insert listAccounts ;


        List<Contact> listContacts = new List<Contact>{
                new Contact(
                        FirstName = 'Voidberg',
                        LastName = 'Bogusman',
                        AccountId = listAccounts.get(0).Id
                ),
                new Contact(
                        FirstName = 'Good Will',
                        LastName = 'Hunting',
                        AccountId = listAccounts.get(1).Id
                ),
                new Contact(
                        FirstName = 'Donald',
                        LastName = 'Duck',
                        AccountId = listAccounts.get(2).Id
                ),
                new Contact(
                        FirstName = 'Mickey',
                        LastName = 'Mouse',
                        AccountId = listAccounts.get(3).Id
                )
        };
        insert listContacts;

        List<Contract> listContracts = new List<Contract>{
                new Contract(
                        AccountId = listAccounts.get(0).Id,
                        RecordTypeId = mapRecordTypes.get('Contract').get('sonnenStrom'),
                        Status = 'Draft',
                        ContractingPartySalutation__c = 'Herr',
                        ContractingPartnerFirstname__c = listContacts.get(0).FirstName,
                        ContractingPartnerLastname__c = listContacts.get(0).LastName,
                        ContractingPartyAcademicTitle__c = 'Dr.',
                        ContractingPartyAccountName__c = '',
                        ContractingPartyEmail__c = 'test@die-interaktiven.de',
                        ContractingPartyPhone__c = '007-123456',
                        AnnualConsumption__c = '5000',
                        BankDataFirstname__c = 'Voidy',
                        BankDataLastname__c = 'Bogusman',
                        BankDataIBAN__c = ' de49 7332_0073 0022.6660 45$',
                        DeliveryStart__c = System.today().addMonths(1),
                        BillingStreet__c = 'Voidstreet',
                        BillingStreetNumber__c = '4a',
                        BillingPostalCode__c = '12345',
                        BillingCity__c = 'Boguscity',
                        MeterId__c = '7147192',
                        PreviousProvider__c = '9904383000003',
                        SEPADate__c = System.today(),
                        ShippingStreet__c = 'Locusweg',
                        ShippingStreetNumber__c = '28',
                        ShippingPostalCode__c = '54321',
                        ShippingCity__c = 'Shipcity',
                        TariffType__c = 'sonnenStrom',
                        Type__c = 'start',
                        MandateReferenceNumber__c = '123456545687',
                        SubscriptionReason__c = 'New Site (E02)',
                        AmountOfFreeEnergy__c = 5000,
                        AnnualConsumptionTotal__c = 10000,
                        CustomerSignedId = listContacts.get(0).Id,
                        LumenazaContractId__c = 'C123456',
                        LumenazaCustomerId__c = 'DE123456',
                        LumenazaSkipApiCall__c = true
                )};

                Integer iConractIndex = 1;

                Contract oContract = listContracts.get(0).clone();
                oContract.AccountId                      = listAccounts.get(iConractIndex).Id;
                oContract.CustomerSignedId               = listContacts.get(iConractIndex).Id;
                oContract.LumenazaContractId__c          = 'C987654321';
                oContract.LumenazaCustomerId__c          = 'DE987654321';
                oContract.ContractingPartnerFirstname__c = listContacts.get(iConractIndex).FirstName;
                oContract.ContractingPartnerLastname__c  = listContacts.get(iConractIndex).LastName;
                listContracts.add(oContract);

                iConractIndex++;
                oContract = listContracts.get(0).clone();
                oContract.AccountId                      = listAccounts.get(iConractIndex).Id;
                oContract.CustomerSignedId               = listContacts.get(iConractIndex).Id;
                oContract.LumenazaContractId__c          = 'C1010101010';
                oContract.LumenazaCustomerId__c          = 'DE101010101';
                oContract.ContractingPartnerFirstname__c = listContacts.get(iConractIndex).FirstName;
                oContract.ContractingPartnerLastname__c  = listContacts.get(iConractIndex).LastName;
                listContracts.add(oContract);

                iConractIndex++;
                oContract = listContracts.get(0).clone();
                oContract.AccountId                      = listAccounts.get(iConractIndex).Id;
                oContract.CustomerSignedId               = listContacts.get(iConractIndex).Id;
                oContract.LumenazaContractId__c          = 'C92347238498';
                oContract.LumenazaCustomerId__c          = 'DE2349809232';
                oContract.ContractingPartnerFirstname__c = listContacts.get(iConractIndex).FirstName;
                oContract.ContractingPartnerLastname__c  = listContacts.get(iConractIndex).LastName;
                listContracts.add(oContract);

                insert listContracts;

    }

    @IsTest
    static void testBehavior() {

        List<Account> lAccounts = [SELECT Id FROM Account];

        Account a = lAccounts.get(0);

        List<Contract> lContracts = showAllContractsCtrl.getContracts(a.id);

        System.assert(lContracts.size()>0);
    }
}