/**
 *  LumenazaTest
 *
 *  ...         Marko Schmalenbach
 *  2018-05-23  Polina Drobot       added coverage for defining contract by Contract Number (SOBCRM-1194)
 *  2018-05-29  Polina Drobot       choosing Template according to Contract Type (SOBCRM-1208)
 *  2018-07-12  Marko Schmalenbach  Adjusted Contracts with CustomerSignedId to meet new criteria rule (SOBCRM-1233)
 */
@isTest
private class LumenazaTest {

    private static Map<String, Map<String, Id>> recordTypeDeveloperNameToId;

    private static final Decimal INBOUND_MAIL_HANDLER_DELAY = 4225;

    @isTest static void setupStatic() {

        // Get record types
        recordTypeDeveloperNameToId = new Map<String, Map<String, String>>();
        List<RecordType> recordTypes = new List<RecordType>([SELECT Id, Name, DeveloperName, SObjectType FROM RecordType WHERE IsActive = true AND (SObjectType = 'Contract' OR SObjectType = 'Account')]);

        for (RecordType recordType : recordTypes) {
            if (recordTypeDeveloperNameToId.get(recordType.SObjectType) == NULL) {
                recordTypeDeveloperNameToId.put(recordType.SObjectType, new Map<String, String>());
            }
            recordTypeDeveloperNameToId.get(recordType.SObjectType).put(recordType.DeveloperName.toLowerCase(), recordType.Id);
        }
    }

    @testSetup static void setup() {

        setupStatic();

        Id recordTypeBusinessAccount = recordTypeDeveloperNameToId.get('Account').get('businessaccount');
        Id recordTypePrivateAccount = recordTypeDeveloperNameToId.get('Account').get('private');
        Id recordTypeContractEnergy = recordTypeDeveloperNameToId.get('Contract').get('energy');
        Id recordTypeContractSonnenFlat = recordTypeDeveloperNameToId.get('Contract').get('sonnenflat');
        Id recordTypeContractCommunity = recordTypeDeveloperNameToId.get('Contract').get('community');

        System.assertNotEquals(NULL, recordTypeBusinessAccount);
        System.assertNotEquals(NULL, recordTypePrivateAccount);
        System.assertNotEquals(NULL, recordTypeContractEnergy);
        System.assertNotEquals(NULL, recordTypeContractCommunity);

        // Create accounts
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(
            Name = 'ACME Co.',
            RecordTypeId = recordTypeBusinessAccount
        ));
        accounts.add(new Account(
            Salutation = 'Herr',
            AcademicTitle__pc = 'Dr.',
            FirstName = 'Hans',
            LastName = 'Pampel',
            PersonEmail = 'pampel@test.org',
            Phone = '02354-5488924',
            RecordTypeId = recordTypePrivateAccount
        ));
        insert accounts;

        Contact oContact = new Contact(
            FirstName = 'Kurt',
            LastName = 'Krautsalat',
            AccountId = accounts.get(0).Id
        );
        insert oContact;

        // Energy Contract
        Contract contract = new Contract(
            RecordTypeId = recordTypeContractEnergy,
            AccountId = accounts.get(0).Id,
            Status = 'Draft',
            ContractingPartySalutation__c = 'Herr',
            ContractingPartnerFirstname__c = 'Voidy',
            ContractingPartnerLastname__c = 'Bogusman',
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
            TariffType__c = 'household',
            Type__c = 'sonnenbatterieHome-DE', // since 2017-03-27
            MandateReferenceNumber__c = '123456545687',
            SubscriptionReason__c = 'New Site (E02)',
            AmountOfFreeEnergy__c = 5000,
            AnnualConsumptionTotal__c = 10000,
            CustomerSignedId = oContact.Id
        );
        insert contract;

        // Lumenaza Settings
        LumenazaSettings__c settings = new LumenazaSettings__c(
            Name = LumenazaApi.settingsName,
            ApiDoSync__c = true,
            ApiUseTest__c = true,
            ApiTestUrl__c = 'http://bogus.whitehouse.org',
            ApiTestUsername__c = 'bogus',
            ApiTestPassword__c = 'bogus',
            ApiTestAuthClient__c = 'bogus',
            ApiTestAuthSecret__c = 'bogus',
            ApiLiveUrl__c = 'http://bogus.whitehouse.org',
            ApiLiveUsername__c = 'bogus',
            ApiLivePassword__c = 'bogus',
            ApiLiveAuthClient__c = 'bogus',
            ApiLiveAuthSecret__c = 'bogus',
            InvoiceSynchronizerDontCreateCases__c = false,
            InboundMailHandlerDelayMilliseconds__c = INBOUND_MAIL_HANDLER_DELAY // since 2018-04-27
        );
        insert settings;
    }

    @isTest static void testLumenazaContractNoCreation() {

        // Called to make sure that callouts would be made
        Test.startTest();
        Test.stopTest();

        Contract contract = [
            SELECT
                Lumenaza_is_business__c,
                Lumenaza_ApiRequestTime__c,
                LumenazaCustomerId__c,
                BankDataIBAN__c
            FROM
                Contract
            LIMIT 1
        ];

        // No API call expected
        System.assertEquals(NULL, contract.LumenazaCustomerId__c, 'Expecting no CustomerId');
        System.assertEquals(NULL, contract.Lumenaza_ApiRequestTime__c, 'Expecting no request');

        // Check on is_business
        System.assertEquals(true, contract.Lumenaza_is_business__c, 'Initial account is of type "BusinessAccount" so we expect this is true');

        // Check if IBAN is sanitized
        System.assertEquals('DE49733200730022666045', contract.BankDataIBAN__c, 'Expecting IBAN without spaces an uppercase');
    }

    @isTest static void testLumenazaContractCreation() {

        Contract contract = (Contract) Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');

        // Second Contract
        Contract contract2 = contract.clone();
        insert contract2;

        List<Contract> listContracts = new List<Contract>{
            contract, contract2
        };

        Test.startTest();

        // Activate contract
        contract.Status = contract.LumenazaActivationStatus__c;

        // Validation errors expected
        try {
            update contract;
        } catch (Exception e) {
            System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
            System.Assert(e.getMessage().contains('"company_name" is mandatory'));
        }

        // Now add a second Contract for the same Account which should raise an error
        // as inserting multiple Contracts for same Account at the same time is not possible.
        // This would raise an error at Lumenaza as this process is done asynchronously and new
        // Contracts for existing Customers are to be handled specially via another endpoint.
        contract.ContractingPartyAccountName__c = 'Mock Company';

        // Activated also second Contract
        contract2.ContractingPartyAccountName__c = contract.ContractingPartyAccountName__c;
        contract2.Status = contract2.LumenazaActivationStatus__c;

        try {
            update listContracts;
        } catch (Exception e) {
            System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
            System.Assert(e.getMessage().contains('Cannot insert multiple Contracts for same Account at the same time'));
        }

        // Remove callout lock for upsert in the same transaction here
        // @since 2017-12-05
        LumenazaContract oLumenazaContract = new LumenazaContract(contract.Id);
        oLumenazaContract.removeLock('upsert');

        update contract;

        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        contract = [
            SELECT
                Lumenaza_ApiResponse__c,
                Lumenaza_ApiRequestTime__c,
                LumenazaCustomerId__c,
                LumenazaContractId__c,
                Lumenaza_ApiStatusCode__c
            FROM
                Contract
            WHERE
                Id = :contract.Id
        ];

        /*
         * Lumenaza_ApiResponse__c={"contract_id":"TestContractIdFromMock1234","consumer_id":"TestCustomerIdFromMock4321"}, Lumenaza_ApiRequestTime__c=2016-02-04 08:36:39, LumenazaCustomerId__c=TestCustomerIdFromMock4321, LumenazaContractId__c=TestContractIdFromMock1234, Id=8002500000022ufAAA}
         */
        System.assertEquals(LumenazaRestApiMockDispatcher.CONTRACT_ID, contract.LumenazaContractId__c);
        System.assertEquals(LumenazaRestApiMockDispatcher.CUSTOMER_ID, contract.LumenazaCustomerId__c);
        System.assertEquals(200, Integer.valueOf(contract.Lumenaza_ApiStatusCode__c));
        System.assertEquals(true, (contract.Lumenaza_ApiRequestTime__c != NULL));
        System.assertEquals(true, (contract.Lumenaza_ApiResponse__c != NULL));

        System.debug('LumenazaTest - testLumenazaContractCreation(): Contract: ' + contract);
    }

    /**
     * Tests Case creation on Lumenaza error
     *
     * @since 2016-11-29
     * @see LumenazaContract
     */
    @isTest static void testLumenazaContractCreationWithErrorAndCase() {

        // Force a Mock result
        LumenazaRestApiMockDispatcher.setResultBodyNextRoute('Zipcode not found in database', 500);

        // Activate contract
        Test.startTest();
        Contract contract = [SELECT Id, LumenazaActivationStatus__c FROM Contract LIMIT 1];
        contract.ContractingPartyAccountName__c = 'Mock Company';
        contract.Status = contract.LumenazaActivationStatus__c;
        update contract;

        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        List<Case> listCases = [
            SELECT
                Id,
                Subject,
                Description,
                Category__c,
                Subcategory__c,
                Status,
                Priority,
                Type
            FROM Case
        ];

        System.debug('LumenazaTest - testLumenazaContractCreationWithErrorAndCase(): Cases: ' + listCases);

        System.assertEquals(1, listCases.size());
        Case oCase = listCases.get(0);

        System.assertEquals('E02, Falsche Liefer-/Rechnungsadresse', oCase.Subcategory__c);
    }

    /**
     * Test Contract Revocation
     *
     * @since 2016-10-06 (SOBCRM-668)
     */
    @IsTest
    static void testLumenazaContractRevoke() {

        Contract oContract = [SELECT Id FROM Contract LIMIT 1];

        oContract.Status = LumenazaContract.CONTRACT_STATUS_AFTER_SYNC;
        oContract.LumenazaSkipApiCall__c = true;
        update oContract;

        Test.startTest();

        // Now revoke
        oContract.Status = LumenazaContract.CONTRACT_STATUS_REVOKE;
        oContract.LumenazaContractId__c = 'TEST-1';
        oContract.LumenazaCustomerId__c = 'DETEST';
        oContract.LumenazaSkipApiCall__c = false;
        update oContract;

        Test.stopTest();

        oContract = [
                SELECT
                        Lumenaza_ApiResponse__c,
                        Lumenaza_ApiRequestTime__c,
                        LumenazaCustomerId__c,
                        LumenazaContractId__c,
                        Lumenaza_ApiStatusCode__c
                FROM
                        Contract
                WHERE
                        Id = :oContract.Id
        ];

        System.assertEquals(200, Integer.valueOf(oContract.Lumenaza_ApiStatusCode__c));
        System.assert(oContract.Lumenaza_ApiRequestTime__c != null, 'Expect Lumenaza_ApiRequestTime__c to be set');
        System.assert(oContract.Lumenaza_ApiResponse__c != null, 'Expect Lumenaza_ApiResponse__c to be set');

        System.debug('LumenazaTest - testLumenazaContractRevoke(): oContract: ' + oContract);
    }

    @isTest static void testLumenazaContractUpdateWithError() {

        Test.startTest();

        Contract contract = [SELECT Id, LumenazaActivationStatus__c FROM Contract LIMIT 1];

        contract.Status = contract.LumenazaActivationStatus__c;
        contract.Lumenaza_ApiStatusCode__c = 'TEST'; // This must trigger a case due to a fake error
        contract.ContractingPartyAccountName__c = 'Bogus Org.';
        update contract;

        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        // Get case
        Case errorCase = [SELECT Id, subject FROM Case LIMIT 1];

        System.assertNotEquals(NULL, errorCase, 'Expecting a written case due to a fake error');
        System.debug('LumenazaTest - testLumenazaContractUpdateWithError(): Error Case: ' + errorCase);
    }

    /**
     * Tests the change of an existing synchronised Lumenaza contract to
     * new contract type (here Energy -> sonnenFlat)
     *
     * @since 2018-04-05
     * @see https://interaktiv.jira.com/browse/SOBCRM-1164
     */
    @isTest static void testLumenazaContractChange() {

        String DEBUG_HERE = 'LumenazaTest.testLumenazaContractChange() - ';

        setupStatic();

        Contract oContractToChange = (Contract) Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');

        System.assertEquals(recordTypeDeveloperNameToId.get('Contract').get('energy'), oContractToChange.RecordTypeId, 'Expected Energy Contract');

        Test.startTest();

        // Change of an Energy Contract
        oContractToChange.Status                    = oContractToChange.LumenazaActivationStatus__c;
        oContractToChange.LumenazaCustomerId__c     = LumenazaRestApiMockDispatcher.CUSTOMER_ID;
        oContractToChange.LumenazaContractId__c     = LumenazaRestApiMockDispatcher.CONTRACT_ID;
        oContractToChange.LumenazaSkipApiCall__c    = true;

        update oContractToChange;

        // Clone Contract
        Contract oContractNew = oContractToChange.clone();

        // Standard for sonnenFlat
        oContractNew.RecordTypeId                    = recordTypeDeveloperNameToId.get('Contract').get('sonnenflat');
        // Set 'Draft' and not oContractToChange.LumenazaActivationStatus__c
        // as we do not know if its a Status of Category "Activated" which cannot be set
        // on insert!
        oContractNew.Status                          = 'Draft';
        oContractNew.Type__c                         = 'sonnenbatterieHome-DE';
        oContractNew.TariffType__c                   = 'sonnenFlat';
        oContractNew.IsInstallerSpezified__c         = true;
        oContractNew.IsEnergyTariffClassified__c     = true;
        oContractNew.IsPVSizeSpezified__c            = true;
        oContractNew.ContractDataApproved__c         = true;
        oContractNew.AmountOfFreeEnergy__c           = 2000;
        oContractNew.AnnualConsumptionTotal__c       = 10000;
        oContractNew.ContractingPartyAccountName__c  = 'Bogus Org.';

        // Values for change
        oContractNew.LumenazaCustomerId__c           = null;
        oContractNew.LumenazaContractId__c           = oContractNew.LumenazaContractId__c + '-change';
        oContractNew.SubscriptionReason__c           = LumenazaContract.SUBSCRIPTION_REASON_CHANGE;
        oContractNew.ContractPrevious__c             = oContractToChange.Id;
        oContractNew.MeterReadingValueStart__c       = 54254;
        oContractNew.StartDate                       = System.today().addDays(-2);
        oContractNew.Tariff_Version__c				 = 'sFH 2.0'; // Currently only to pass the (old) flow "Sonnen Flat Process" which would activate the contract on insert automatically
        oContractNew.CustomerSignedTitle             = 'Apex UnitTest'; // To pass by flow processes which would raise "uncommitted work pending"

        oContractNew.LumenazaSkipApiCall__c          = false;

        insert oContractNew;

        // Activate contract
        oContractNew.Status = oContractToChange.LumenazaActivationStatus__c;
        Date dateStart = oContractNew.StartDate;

        Boolean bHadException = false;

        try {
            System.debug(DEBUG_HERE + 'Status: ' + oContractNew.Status);
            update oContractNew;
        }
        catch (Exception e) {
            bHadException = true;
            System.debug(DEBUG_HERE + 'Expected an exception: ' + e.getMessage());
            System.assert(e.getMessage().contains('already has a Lumenaza Contract ID'));
        }

        System.assert(bHadException);

        oContractNew.LumenazaContractId__c = null;
        System.debug(DEBUG_HERE + 'Update new contract for change');

        // Force different Lumenaza Contract ID
        // Otherwise a DUPLICATE_VALUE error would be raised
        LumenazaRestApiMockDispatcher.setResultBodyNextRoute('{"contract_id":"' + oContractToChange.LumenazaContractId__c + '-2","consumer_id":"' + LumenazaRestApiMockDispatcher.CUSTOMER_ID + '"}', 200);

        update oContractNew;

        Contract oTestContract = [SELECT StartDate FROM Contract WHERE Id = :oContractNew.Id];
        System.debug(DEBUG_HERE + 'StartDate of new contract BEFORE Test.stopTest(): ' + oTestContract.StartDate);

        Test.stopTest();

        //System.debug(DEBUG_HERE + 'Contract for change after: ' + JSON.serializePretty(oContractChange.getPopulatedFieldsAsMap()));

        Map<Id,Contract> mapContractsById = new Map<Id,Contract>(
            (List<Contract>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract')
        );

        //-------------------------------
        // Assertions
        //-------------------------------
        oContractToChange = mapContractsById.get(oContractToChange.Id);
        oContractNew      = mapContractsById.get(oContractNew.Id);

        System.debug(DEBUG_HERE + 'StartDate of new contract AFTER Test.stopTest(): ' + oContractNew.StartDate);

        System.assert(oContractToChange.LumenazaContractId__c != oContractNew.LumenazaContractId__c, 'Expected different Lumenaza Contract ID to be set from API response for new contract');
        System.assertEquals(oContractNew.LumenazaCustomerId__c, oContractToChange.LumenazaCustomerId__c, 'Expected equal Lumenaza Customer IDs for old and new contract');
        System.assert(oContractNew.StartDate == oContractNew.DeliveryStart__c, oContractNew.StartDate + ' == ' + oContractNew.DeliveryStart__c);
        //System.debug('Changed contract: ' + JSON.serializePretty(oContractToChange.getPopulatedFieldsAsMap()));

        System.assert(oContractToChange.ContractFollowing__c == oContractNew.Id, 'Expected ContractFollowing__c of old contract to be set to new contract');
        System.assert(oContractToChange.MeterReadingValueEnd__c == oContractNew.MeterReadingValueStart__c, 'Expected MeterReadingValueEnd__c of old contract to match MeterReadingValueStart__c of new contract');
        System.assertEquals(LumenazaContract.CONTRACT_STATUS_CHANGE_PREVIOUS, oContractToChange.Status);
        System.assert(oContractToChange.EndDate == oContractNew.Lumenaza_meter_reading_date__c, 'Expected EndDate of old contract (' + oContractToChange.EndDate + ') and Lumenaza_meter_reading_date__c (' + oContractNew.Lumenaza_meter_reading_date__c + ') to match');
        System.assert(oContractNew.StartDate == dateStart, 'Expected no change of StartDate for new contract');
    }

    /**
     * Tests adding a new Contract to an existing Lumenaza Customer
     * which already has signed a Contract
     *
     * @since 2016-12-15
     * @see https://interaktiv.jira.com/browse/SOBCRM-763
     */
    @isTest static void testLumenazaContractAddToExistingLumenazaCustomer() {

        String sDebugHere = 'LumenazaTest.testLumenazaContractAddToExistingLumenazaCustomer() - ';

        // Create an existing Contract with a Lumenaza Customer ID (can be in Draft)
        Contract oContract = (Contract) Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');

        oContract.ContractingPartyAccountName__c = 'Mock Company';
        oContract.LumenazaCustomerId__c = LumenazaRestApiMockDispatcher.CUSTOMER_ID;
        oContract.LumenazaContractId__c = LumenazaRestApiMockDispatcher.CONTRACT_ID;
        update oContract; // no Callout because in "Draft"

        // Add another Contract for same Account with another LumenazaCustomerId__c which
        // later must raise an error!
        Contract oContract2 = oContract.clone();
        oContract2.LumenazaCustomerId__c = LumenazaRestApiMockDispatcher.CUSTOMER_ID + '-2';
        oContract2.LumenazaContractId__c = LumenazaRestApiMockDispatcher.CONTRACT_ID + '-2';
        oContract2.LumenazaSkipApiCall__c = true;
        insert oContract2;
        oContract2.LumenazaSkipApiCall__c = false;

        // Clone existing Contract
        Contract oNewContract = oContract.clone();
        oNewContract.LumenazaCustomerId__c = NULL;
        oNewContract.LumenazaContractId__c = NULL;
        oNewContract.LumenazaSkipApiCall__c = true;
        insert oNewContract;
        oNewContract.LumenazaSkipApiCall__c = false;

        Test.startTest();

        // Set next API Result
        String sLumenazaContractId = LumenazaRestApiMockDispatcher.CONTRACT_ID + '-3';
        LumenazaRestApiMockDispatcher.setResultBodyNextRoute('{"contract_id":"' + sLumenazaContractId + '","consumer_id":"' + LumenazaRestApiMockDispatcher.CUSTOMER_ID + '"}', 200);

        oNewContract.Status = oNewContract.LumenazaActivationStatus__c;

        Boolean hadException = FALSE;

        try {
            update oNewContract;
        }
        catch (Exception e) {
            hadException = TRUE;
            System.debug(sDebugHere + 'Expected Exception: ' + e.getMessage());
            // e.g. Contract's Account has Contracts with multiple Lumenaza Customer IDs (123456789, 123456789-2)!
            System.assert(e.getMessage().contains('multiple Lumenaza Customer IDs'));
        }

        System.assert(hadException);

        // Correct LumenazaCustomerId__c of the second Contract
        oContract2.LumenazaCustomerId__c = oContract.LumenazaCustomerId__c;
        update oContract2;

        // Now try again
        update oNewContract;

        Test.stopTest();

        Map<Id, Contract> mapContracts = new Map<Id, Contract>([
            SELECT Id, LumenazaContractId__c, LumenazaCustomerId__c
            FROM Contract
            WHERE LumenazaCustomerId__c = :LumenazaRestApiMockDispatcher.CUSTOMER_ID
        ]);

        System.assertEquals(3, mapContracts.size());
        System.assertEquals(mapContracts.get(oNewContract.Id).LumenazaCustomerId__c, LumenazaRestApiMockDispatcher.CUSTOMER_ID);
        System.assertEquals(mapContracts.get(oNewContract.Id).LumenazaContractId__c, sLumenazaContractId);
    }

    /**
     * Updates on Contracts are done by creating LumenazaContractChangesets
     * with LumenazaContractChanges without any API callout
     *
     * @since 2016-12-14
     * @see https://interaktiv.jira.com/browse/SOBCRM-669
     */
    @isTest static void testLumenazaContractUpdate() {

        String sDebugHere = 'LumenazaTest.testLumenazaContractUpdate() - ';
        Contract oContract = [SELECT Id, LumenazaActivationStatus__c, BillingCity__c, BankDataLastname__c FROM Contract LIMIT 1];

        oContract.Status = oContract.LumenazaActivationStatus__c;
        oContract.LumenazaSkipApiCall__c = TRUE;
        oContract.ContractingPartyAccountName__c = 'Mock Company';
        oContract.LumenazaCustomerId__c = LumenazaRestApiMockDispatcher.CUSTOMER_ID;
        oContract.LumenazaContractId__c = LumenazaRestApiMockDispatcher.CONTRACT_ID;
        update oContract;

        String sBankDataLastnameBefore = oContract.BankDataLastname__c;

        Test.startTest();

        // Now change some relevant fields
        oContract.LumenazaSkipApiCall__c = FALSE;
        oContract.BankDataLastname__c = 'Hansepampel';
        oContract.BillingCity__c = oContract.BillingCity__c; // no change should be created in this case
        update oContract;

        List<LumenazaContractChange__c> listChanges = new List<LumenazaContractChange__c>([
            SELECT
                Id,
                Status__c,
                OldValue__c,
                Lumenaza_new_value__c,
                Lumenaza_changed_attribute__c,
                Lumenaza_consumer_id__c,
                Lumenaza_contract_id__c
            FROM
                LumenazaContractChange__c
            WHERE
                Contract__c = :oContract.Id
        ]);

        Test.stopTest();

        System.assertEquals(1, listChanges.size());
        System.debug(sDebugHere + 'Change created: ' + listChanges);

        LumenazaContractChange__c oChange = listChanges.get(0);

        System.assertEquals('new', oChange.Status__c);
        System.assertEquals('bank_data_last_name', oChange.Lumenaza_changed_attribute__c);
        System.assertEquals(oContract.BankDataLastname__c, oChange.Lumenaza_new_value__c);
        System.assertEquals(sBankDataLastnameBefore, oChange.OldValue__c);
    }

    @isTest static void testLumenazaResponse() {

        String error = 'Error as string';

        LumenazaApi.LumenazaApiResponse response = new LumenazaApi.LumenazaApiResponse();
        response.setResponse(error);
        System.assertEquals(false, response.success);
        System.assertEquals(error, response.error);

        response = new LumenazaApi.LumenazaApiResponse();
        response.setResponse(new LumenazaApi.LumenazaApiException(error));
        System.assertEquals(false, response.success);
        System.assertEquals(error, response.error);
    }

    @isTest static void testMailHandler() {

        // Create an email template
        Id organizationId = [SELECT Id FROM Organization LIMIT 1].Id;
        System.assert(organizationId != NULL, 'LumenazaTest - testMailHandler() expects an organization');

        // See https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_dml_non_mix_sobjects_test_methods.htm
        // Workaround for "MIXED_DML_OPERATION, DML operation on setup object is not permitted" error
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        EmailTemplate emailTemplate;

        System.runAs (thisUser) {
            emailTemplate = new EmailTemplate(
                Name = 'Lumenaza Contract Dummy Test Mail Template',
                DeveloperName = 'LumenazaContractDummyMailTemplateTest',
                Subject = 'New customer',
                IsActive = true,
                TemplateType = 'custom',
                Body = 'Lumenaza contract ID: {!Contract.LumenazaContractId__c}',
                FolderId = organizationId
            );
            emailTemplate.HtmlValue = emailTemplate.Body;
            insert emailTemplate;
        }

        // Update contract with Lumenaza Contract ID
        Contract contract = [SELECT Id, ContractNumber FROM Contract LIMIT 1];
        contract.LumenazaContractId__c = 'Id12345';
        contract.ContractingPartyAccountName__c = 'Bogus Corp.';
        update contract;

        // Add a LumenazaEmailTemplates__c entry as rule for handling incoming mail
        LumenazaEmailTemplates__c lumenazaMailTemplate = new LumenazaEmailTemplates__c(
            Name = 'Test Rule',
            EmailSenderDisplayName__c = 'Test Sender',
            EmailSubjectRegex__c = 'Contract:\\s+.+',
            EmailTemplateId__c = emailTemplate.Id,
            InternalName__c = 'TestRule'
        );
        LumenazaEmailTemplates__c lumenazaMailTemplate2 = new LumenazaEmailTemplates__c(
            Name = lumenazaMailTemplate.Name + ' 2',
            EmailSenderDisplayName__c = lumenazaMailTemplate.EmailSenderDisplayName__c + ' 2',
            EmailSubjectRegex__c = lumenazaMailTemplate.EmailSubjectRegex__c,
            EmailTemplateId__c = lumenazaMailTemplate.EmailTemplateId__c,
            InternalName__c = lumenazaMailTemplate.InternalName__c + ' 2',
            ContractType__c = contract.Type__c
        );
        insert new List<LumenazaEmailTemplates__c>{lumenazaMailTemplate, lumenazaMailTemplate2};


        // Create mail
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        Messaging.InboundEmail email = new Messaging.InboundEmail() ;

        // Add attachment
        Messaging.InboundEmail.BinaryAttachment binaryAttachment = new Messaging.InboundEmail.BinaryAttachment();
        binaryAttachment.Filename = 'Test.txt';
        binaryAttachment.Body = Crypto.generateMac('HMacSHA1', Blob.valueOf('test'), Blob.valueOf('test_key'));

        email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{
            binaryAttachment
        };
        email.Subject = 'Contract: '; // first, we set bad subject for not finding any Contract
        email.FromName = 'Lumenaza';
        email.PlainTextBody = 'She sells sea shells at the sea shore.';
        email.fromAddress = 'void@acme.com';

        envelope.fromAddress = 'Void Bogusman';

        //=========================================================
        // #1 run must raise error because no contract is found
        //=========================================================
        // Handle mail
        Long fStartingTime = System.now().getTime();

        LumenazaInboundMailHandler mailHandler = new LumenazaInboundMailHandler();
        Messaging.InboundEmailResult result = mailHandler.handleInboundEmail(email, envelope);

        System.assert((System.now().getTime() - fStartingTime) >= INBOUND_MAIL_HANDLER_DELAY, 'Expect delay of at least ' + INBOUND_MAIL_HANDLER_DELAY + ' msec');
        System.assertEquals(result.success, true, 'LumenazaTest - testMailHandler() expect #1 handleInboundEmail() success to be true');

        // Check for cases
        List<Case> cases = [SELECT Id, Subject, Description FROM Case LIMIT 1];
        System.assertEquals(1, cases.size(), 'LumenazaTest - testMailHandler() expect a case');

        //=========================================================
        // #2 run must be successful
        //=========================================================
        // Set a possible Lumenaza Contract ID
        contract.LumenazaContractId__c = LumenazaInboundMailHandler.testContractId;
        update contract;

        email.Subject = 'Contract: ' + contract.ContractNumber; // good subject, to cover searchLumenazaContractNumbers method;

        // Handle email again
        result = mailHandler.handleInboundEmail(email, envelope);
        System.assertEquals(result.success, true, 'LumenazaTest - testMailHandler() expect #2 handleInboundEmail() success to be true');

        // Check for cases again
        cases = [SELECT Id, Subject, Description FROM Case LIMIT 1];
        System.assertEquals(1, cases.size(), 'LumenazaTest - testMailHandler() expect only one case from previous error');

        // Check if contract has attachment
        Attachment attachement = [SELECT Id, Name FROM Attachment WHERE ParentId = :contract.Id LIMIT 1];
        System.assert(attachement != NULL, 'LumenazaTest - testMailHandler() expect an attachment');
        System.assertEquals(binaryAttachment.Filename, attachement.name, 'LumenazaTest - testMailHandler() expect attachment name "' + binaryAttachment.Filename + '"');

        // Check if contract has activity
        Task task = [SELECT Id FROM Task WHERE WhatId = :contract.Id LIMIT 1];
        System.assert(task != NULL, 'LumenazaTest - testMailHandler() expect a task');
    }

    @isTest static void testLumenazaBonusCreationNoLumenazaInsert1() {

        Id energyRecordType = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Bonus__c' AND DeveloperName = 'Energy'].Id;

        Test.startTest();

        // Create a bonus
        Bonus__c bonus = new Bonus__c(
            RecordTypeId = energyRecordType,
            Active__c = false,
            Amount__c = 100,
            BonusType__c = 'oneshot', // or periodical
            Contract__c = [SELECT Id FROM Contract LIMIT 1].Id,
            NoOfMonths__c = 12,
            StartDate__c = System.today().addDays(60),
            Unit__c = 'kWh' // or Euro
        );
        insert bonus;
        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        bonus = [SELECT Lumenaza_IsApiSynced__c FROM Bonus__c WHERE Id = :bonus.Id];
        System.assertEquals(false, bonus.Lumenaza_IsApiSynced__c, 'Expect no insert sync due to Active__c = false');
    }

    @isTest static void testLumenazaBonusCreationNoLumenazaInsert2() {

        Id energyRecordType = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Bonus__c' AND DeveloperName = 'Energy'].Id;

        Test.startTest();

        // Create a bonus
        Bonus__c bonus = new Bonus__c(
            RecordTypeId = energyRecordType,
            Active__c = true,
            LumenazaSkipApiCall__c = true,
            Amount__c = 100,
            BonusType__c = 'oneshot', // or periodical
            Contract__c = [SELECT Id FROM Contract LIMIT 1].Id,
            NoOfMonths__c = 12,
            StartDate__c = System.today(),
            Unit__c = 'kWh' // or Euro
        );
        insert bonus;
        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        bonus = [SELECT Lumenaza_IsApiSynced__c FROM Bonus__c WHERE Id = :bonus.Id];
        System.assertEquals(false, bonus.Lumenaza_IsApiSynced__c, 'Expect no insert sync due to LumenazaSkipApiCall__c = false');
    }

    @isTest static void testLumenazaBonusCreationLumenazaUpdate() {

        Id energyRecordType = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Bonus__c' AND DeveloperName = 'Energy'].Id;

        Contract contract = [SELECT Id FROM Contract LIMIT 1];
        contract.LumenazaContractId__c = 'C3242342342';
        contract.LumenazaCustomerId__c = 'DE823489234';
        contract.LumenazaSkipApiCall__c = true;
        update contract;

        Test.startTest();

        // Create a bonus
        Bonus__c bonus = new Bonus__c(
            RecordTypeId = energyRecordType,
            Active__c = true,
            LumenazaSkipApiCall__c = false,
            Amount__c = 100,
            BonusType__c = 'oneshot', // or periodical
            Contract__c = contract.Id,
            NoOfMonths__c = 12,
            StartDate__c = System.today().addDays(60),
            Unit__c = 'Euro' // kWh or Euro
        );

        Boolean hasException = false;

        insert bonus;

        bonus.NoOfMonths__c = 24;

        update bonus;

        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        bonus = [SELECT Lumenaza_IsApiSynced__c FROM Bonus__c WHERE Id = :bonus.Id];
        System.assertEquals(true, bonus.Lumenaza_IsApiSynced__c, 'Expect bonus to be successfully inserted');
    }

    @isTest static void testLumenazaBonusCreationLumenazaInsert() {

        Id energyRecordType = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Bonus__c' AND DeveloperName = 'Energy'].Id;

        Contract contract = [SELECT Id FROM Contract LIMIT 1];
        contract.LumenazaContractId__c = 'C3242342342';
        contract.LumenazaCustomerId__c = 'DE823489234';
        contract.LumenazaSkipApiCall__c = true;
        update contract;

        Test.startTest();

        // Create a bonus
        Bonus__c bonus = new Bonus__c(
            RecordTypeId = energyRecordType,
            Active__c = true,
            LumenazaSkipApiCall__c = false,
            Amount__c = 100,
            BonusType__c = 'oneshot', // or periodical
            Contract__c = contract.Id,
            NoOfMonths__c = 12,
            StartDate__c = System.today().addDays(60),
            Unit__c = NULL // kWh or Euro
        );

        Boolean hasException = false;

        try {
            insert bonus;
        } catch (Exception e) {
            hasException = true;
            System.debug(e.getMessage());
            System.AssertEquals(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'), true);
            System.AssertEquals(e.getMessage().contains('amount_kwh or amount_euro is mandatory'), true);
        }
        System.assert(hasException, 'Expected exception due to missing Unit__c');

        bonus.Unit__c = 'Euro';
        insert bonus;

        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        bonus = [SELECT Lumenaza_IsApiSynced__c FROM Bonus__c WHERE Id = :bonus.Id];
        System.assertEquals(true, bonus.Lumenaza_IsApiSynced__c, 'Expect bonus to be successfully inserted');
    }

    @isTest static void testLumenazaBonusDeletion() {

        Id energyRecordType = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Bonus__c' AND DeveloperName = 'Energy'].Id;

        Contract contract = [SELECT Id FROM Contract LIMIT 1];

        Campaign campaign = new Campaign(
            Name = 'Energy Bonus',
            isActive = true,
            RecordTypeId = SonnenbatterieConstants.CAMP_RT_BONUS,
            Status = 'In Progress',
            Startdate = Date.today(),
            EndDate = Date.today().addDays(30)
        );

        insert campaign;

        Account account = new Account(Name = 'Testkunde');
        insert account ;

        Contact contact = new Contact(FirstName = 'Voidberg', LastName = 'Bogusman', AccountId = account.Id);
        insert contact;

        contract.AccountId = account.Id;
        contract.CustomerSignedId = contact.Id;
        contract.LumenazaContractId__c = '123456';
        contract.LumenazaSkipApiCall__c = true;
        update contract;


        Test.startTest();

        // Create a bonus
        Bonus__c bonus = new Bonus__c(
            RecordTypeId = energyRecordType,
            Active__c = true,
            BonusCampaign__c = campaign.Id,
            LumenazaSkipApiCall__c = false,
            Amount__c = 100,
            BonusType__c = 'oneshot', // or periodical
            Contract__c = contract.Id,
            NoOfMonths__c = 12,
            StartDate__c = System.today().addDays(60),
            Unit__c = 'Euro'
        );

        Boolean hasException = false;

        insert bonus;
        System.assertEquals(1, [SELECT Count() FROM Bonus__c]);

        Bonus__c reloadedBonus = [SELECT Id, Amount__c, BonusCampaign__c, Contract__r.CustomerSignedId FROM Bonus__c LIMIT 1];

        reloadedBonus.Amount__c = 200;
        update reloadedBonus;

        Test.stopTest();

        delete bonus;
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

    }

    @isTest static void testLumenazaBonusCreationForCampaign() {

        Id energyRecordType = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Bonus__c' AND DeveloperName = 'Energy'].Id;

        Contract contract = [SELECT Id FROM Contract LIMIT 1];

        Date startDate = Date.today().addMonths(1).toStartOfMonth();

        Campaign campaign = new Campaign(
            Name = 'Energy Bonus',
            isActive = true,
            RecordTypeId = SonnenbatterieConstants.CAMP_RT_BONUS,
            Status = 'In Progress',
            Startdate = startDate,
            EndDate = startDate.addYears(1)
        );

        insert campaign;

        Account account = new Account(Name = 'Testkunde');
        insert account ;

        Contact contact = new Contact(FirstName = 'Voidberg', LastName = 'Bogusman', AccountId = account.Id);
        insert contact;

        contract.AccountId = account.Id;
        contract.CustomerSignedId = contact.Id;
        contract.LumenazaContractId__c = 'C3242342342';
        contract.LumenazaCustomerId__c = 'DE823489234';
        contract.LumenazaSkipApiCall__c = true;
        update contract;


        Test.startTest();

        ApexPages.StandardController sc = new ApexPages.StandardController(contract);
        ControllerExtension_ContractBonus extBonus = new ControllerExtension_ContractBonus(sc);

        PageReference pageRef = Page.manageContractBonus;
        pageRef.getParameters().put('id', String.valueOf(contract.Id));

        Test.setCurrentPage(pageRef);

        extBonus.theCampaign = campaign;

        extBonus.selectCampaign();
        extBonus.saveBonus();

        // Create a bonus
        Bonus__c bonus = new Bonus__c(
            RecordTypeId = energyRecordType,
            Active__c = false,
            BonusCampaign__c = campaign.Id,
            LumenazaSkipApiCall__c = false,
            Amount__c = 100,
            BonusType__c = 'oneshot', // or periodical
            Contract__c = contract.Id,
            NoOfMonths__c = 12,
            StartDate__c = System.today().addDays(60),
            Unit__c = 'Euro'
        );

        Boolean hasException = false;

        insert bonus;

        bonus.Active__c = true;

        update bonus;


        Test.stopTest();
        // All asynchronous calls made after the startTest method are collected by the system.
        // When stopTest is executed, all asynchronous processes are run synchronously.
        // https://developer.salesforce.com/docs/atlas.en-us.198.0.apexcode.meta/apexcode/apex_testing_tools_start_stop_test.htm

        bonus = [SELECT Lumenaza_IsApiSynced__c FROM Bonus__c WHERE Id = :bonus.Id];
        System.assertEquals(true, bonus.Lumenaza_IsApiSynced__c, 'Expect bonus to be successfully inserted');
    }

    /**
     * Test LumenazaContractInvoiceSynchronizer
     *
     * @since 2016-06-22
     * @see https://interaktiv.jira.com/browse/SOBCRM-705
     */
    @isTest static void testLumenazaContractInvoiceSynchronizer() {

        String DEBUG_HERE = 'testLumenazaContractInvoiceSynchronizer() - ';

        Contract oContract = (Contract) Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');
        oContract.LumenazaSkipApiCall__c = TRUE;
        oContract.LumenazaContractId__c = 'C16923049-1';

        update oContract;

        // Insert existing Payment__c which will be updated
        // from CSV import
        Payment__c oPayment = new Payment__c(
            RecordTypeId = LumenazaContractInvoiceSynchronizer.RECORD_TYPE_ID_PAYMENT,
            Contract__c = oContract.Id,
            Lumenaza_CustomerId__c = 'DE16923053',
            Lumenaza_ContractNo__c = 'C16923049-2',
            Lumenaza_customerLabel__c = 'existing',
            AdressType__c = '1',
            Lumenaza_CompanyName__c = 'ACME Corp.',
            Lumenaza_CompanyContact__c = '',
            Lumenaza_LastName__c = 'Bogusman',
            Lumenaza_FirstName__c = 'Voidy',
            Lumenaza_Sex__c = 'Herr',
            Lumenaza_DelivStreet__c = 'Am Bischofsholz',
            Lumenaza_DelivHouseNr__c = '11',
            Lumenaza_DelivZipCode__c = '04288',
            Lumenaza_DelivCity__c = 'Leipzig',
            Lumenaza_MeterpointNo__c = 'DE0009990428800000000000000515196',
            Lumenaza_InvoiceNo__c = '2017002760',
            Lumenaza_InvoiceDate__c = Date.newInstance(2017, 3, 2),
            DebitDate__c = Date.newInstance(2017, 3, 2),
            Lumenaza_InstallmentDate__c = Date.newInstance(2016, 3, 2),
            Amount__c = 14.25
        );
        insert oPayment;

        List<Bonus__c> listBonuses = new List<Bonus__c>{
            new Bonus__c(
                Contract__c = oContract.Id,
                BonusInitiator__c = 'eService',
                Amount__c = 50,
                Unit__c = 'Euro'
            ),
            new Bonus__c(
                Contract__c = oContract.Id,
                BonusInitiator__c = 'eService',
                Amount__c = 100,
                Unit__c = 'Euro'
            ),
            new Bonus__c(
                Contract__c = oContract.Id,
                BonusInitiator__c = 'eService',
                Amount__c = 150,
                Unit__c = 'Euro'
            ),
            new Bonus__c(
                Contract__c = oContract.Id,
                BonusInitiator__c = 'eService',
                Amount__c = 200,
                Unit__c = 'Euro'
            )
        };
        insert listBonuses;

        Id idDeletedBonus = listBonuses.get(1).Id;
        delete listBonuses.get(1);

        // BonusToPaymentLink__c
        // (junction between a Bonus and a Payment)
        List<BonusToPaymentLink__c> listBonusToPaymentLinks = new List<BonusToPaymentLink__c>{
            // must be deleted because not present in import
            new BonusToPaymentLink__c(
                Payment__c = oPayment.Id,
                Bonus__c   = listBonuses.get(3).Id
            ),
            // has to be left untouched
            new BonusToPaymentLink__c(
                Payment__c = oPayment.Id,
                Bonus__c   = listBonuses.get(2).Id
            )
        };
        insert listBonusToPaymentLinks;

        Payment__c oPaymentToCheck = [SELECT Id, Lumenaza_InvoiceNo__c, (SELECT Id, LastModifiedDate, Payment__c, Bonus__c FROM BonusToPayments__r) FROM Payment__c WHERE Id = :oPayment.Id];
        System.assertEquals(2, oPaymentToCheck.BonusToPayments__r.size());
        System.debug('Payment with InvoiceNo "' + oPaymentToCheck.Lumenaza_InvoiceNo__c + '" has ' + oPaymentToCheck.BonusToPayments__r.size() + ' links to bonuses');

        Datetime oBonusToPaymentLinkLastModifiedDatetime;

        for (BonusToPaymentLink__c oBonusToPaymentLink : oPaymentToCheck.BonusToPayments__r) {
            if (oBonusToPaymentLink.Id == listBonusToPaymentLinks.get(1).Id) {
                oBonusToPaymentLinkLastModifiedDatetime = oBonusToPaymentLink.LastModifiedDate;
            }
        }

        System.assert(oBonusToPaymentLinkLastModifiedDatetime != NULL);

        // Force a Mock result
        // Errors will open a case but not stop whole processing
        String sUpdatedFirstName = 'Vody';
        String sUpdatedLastName = 'Boguman';

        Map<String, String> mapInsertValues = new Map<String, String>{
            'Lumenaza_CustomerId__c'        => 'DE16923053',
            'Lumenaza_ContractNo__c'        => oContract.LumenazaContractId__c,
            'Lumenaza_customerLabel__c'     => 'existing',
            'AdressType__c'                 => '1',
            'Lumenaza_CompanyName__c'       => 'ACME Corp.',
            'Lumenaza_LastName__c'          => 'Bogusman',
            'Lumenaza_FirstName__c'         => 'Voidy',
            'Lumenaza_Sex__c'               => 'Herr',
            'Lumenaza_DelivStreet__c'       => 'Am Bischofsholz',
            'Lumenaza_DelivHouseNr__c'      => '11',
            'Lumenaza_DelivZipCode__c'      => '04288',
            'Lumenaza_DelivCity__c'         => 'Leipzig',
            'Lumenaza_MeterpointNo__c'      => 'DE0009990428800000000000000515196',
            'Lumenaza_InvoiceNo__c'         => '2017002761',
            'Lumenaza_InvoiceDate__c'       => '10.02.2017',
            'DebitDate__c'                  => '10.06.2017',
            'Lumenaza_InstallmentDate__c'   => '25.09.2016',
            'Amount__c'                     => '29.99',
            'BonusIds__c'                   => listBonuses.get(0).Id + ',' + listBonuses.get(2).Id
        };

        LumenazaRestApiMockDispatcher.setResultBodyNextRoute(
            'customerID;SEPA-Mandatsreferenznummer;SEPA-Mandatsdatum;Vertragsnummer;delivery_start;delivery_end;customer_label;Installment date;Adressatentyp;company name;company_contact;last_name;first_name;sex;deliv_street;deliv_house_nr;Adresszusatz;deliv_zip_code;deliv_city;Zählpunkt-Nr.;Rechnungsnummer;Rechnungsdatum;Datum Abbuchung;Abschlags-Summe;Bonus-ID'
                // correct
                // - (2017002761) will be created
                + '\n' + '"' + mapInsertValues.get('Lumenaza_CustomerId__c') + '";"100270000001";24.02.2016;' + mapInsertValues.get('Lumenaza_ContractNo__c') + ';01.01.2017;;' + mapInsertValues.get('Lumenaza_customerLabel__c') + ';' + mapInsertValues.get('Lumenaza_InstallmentDate__c') + ';' + mapInsertValues.get('AdressType__c') + ';"' + mapInsertValues.get('Lumenaza_CompanyName__c') + '";;"' + mapInsertValues.get('Lumenaza_LastName__c') + '";"' + mapInsertValues.get('Lumenaza_FirstName__c') + '";' + mapInsertValues.get('Lumenaza_Sex__c') + ';' + mapInsertValues.get('Lumenaza_DelivStreet__c') + ';"' + mapInsertValues.get('Lumenaza_DelivHouseNr__c') + '";;"' + mapInsertValues.get('Lumenaza_DelivZipCode__c') + '";' + mapInsertValues.get('Lumenaza_DelivCity__c') + ';' + mapInsertValues.get('Lumenaza_MeterpointNo__c') + ';' + mapInsertValues.get('Lumenaza_InvoiceNo__c') + ';' + mapInsertValues.get('Lumenaza_InvoiceDate__c') + ';' + mapInsertValues.get('DebitDate__c') + ';' + mapInsertValues.get('Amount__c') + ';' + mapInsertValues.get('BonusIds__c')
                // - (2017002760) exists and will be updated, has
                //      - one invalid Bonus ID which opens a case
                //      - one valid Bonus ID which should be left untouched
                + '\n' + '"DE16923049";"100270000001";29.02.2016;' + oContract.LumenazaContractId__c + ';01.01.2017;;existing;01.03.2017;1;;;' + sUpdatedLastName + ';' + sUpdatedFirstName + ';Herr;Am Bischofsholz      ;"11";;"04288";Leipzig;DE0009990428800000000000000515196;' + oPayment.Lumenaza_InvoiceNo__c + ';01.03.2017;01.03.2017;19.17;' + idDeletedBonus + ',' + listBonusToPaymentLinks.get(1).Bonus__c
                // error
                // - non-existing contract no. (opens case)
                + '\n' + '"DE16923050";"100270000002";25.02.2016;' + 'Blabla' + ';01.01.2017;;existing;01.03.2017;1;;;Duck;Daisy;Frau;Am Bischofsholz;"11";;"04288";Leipzig;DE0009990428800000000000000515196;2017002754;01.03.2017;01.03.2017;19.17;""'
                // - missing contract no. (opens case)
                + '\n' + '"DE16923051";"100270000002";26.02.2016;' + '' + ';01.01.2017;;existing;01.03.2017;1;;;Duck;Donald;Herr;Am Bischofsholz;"11";;"04288";Leipzig;DE0009990428800000000000000515196;2017002755;01.03.2017;01.03.2017;19.17;""'
                // - missing invoice no. (will be skipped - NO case)
                + '\n' + '"DE16923052";"100270000001";27.02.2016;' + oContract.LumenazaContractId__c + ';01.01.2017;;existing;01.03.2017;1;;;Bogusman;Voidy;Herr;Am Bischofsholz;"11";;"04288";Leipzig;DE0009990428800000000000000515196;' + '' + ';01.03.2017;01.03.2017;19.17;""'
            ,
            200
        );

        Test.startTest();

        LumenazaContractInvoiceSynchronizer oSynchronizer = new LumenazaContractInvoiceSynchronizer();
        oSynchronizer.synchronize('summarized', 2017, 3);

        Test.stopTest();

        // Assertions
        Map<Id, Payment__c> mapPayments = new Map<Id, Payment__c>([
            SELECT
                Id,
                RecordTypeId,
                Contract__c,
                Lumenaza_CustomerId__c,
                Lumenaza_ContractNo__c,
                Lumenaza_customerLabel__c,
                AdressType__c,
                Lumenaza_CompanyName__c,
                Lumenaza_CompanyContact__c,
                Lumenaza_LastName__c,
                Lumenaza_FirstName__c,
                Lumenaza_Sex__c,
                Lumenaza_DelivStreet__c,
                Lumenaza_DelivHouseNr__c,
                Lumenaza_DelivZipCode__c,
                Lumenaza_DelivCity__c,
                Lumenaza_MeterpointNo__c,
                Lumenaza_InvoiceNo__c,
                Lumenaza_InvoiceDate__c,
                DebitDate__c,
                Lumenaza_InstallmentDate__c,
                Amount__c,
                BonusIds__c
            FROM
                Payment__c
            WHERE
                RecordTypeId = :LumenazaContractInvoiceSynchronizer.RECORD_TYPE_ID_PAYMENT
        ]);

        System.assertEquals(2, mapPayments.size(), 'Expected 2 Payment__c objects');

        // UPDATE
        // Expect to have updated name on existing Payment
        System.assertEquals(sUpdatedFirstName, mapPayments.get(oPayment.Id).Lumenaza_FirstName__c);
        System.assertEquals(sUpdatedLastName, mapPayments.get(oPayment.Id).Lumenaza_LastName__c);
        mapPayments.remove(oPayment.Id);

        // INSERT
        // Compare all values
        Payment__c oNewPayment = mapPayments.values().get(0);

        for (String sFieldName : mapInsertValues.keySet()) {

            String sShouldValue = mapInsertValues.get(sFieldName);
            String sIsValue = String.valueOf(oNewPayment.get(sFieldName));

            if (sFieldName == 'Lumenaza_InvoiceDate__c' ||
                sFieldName == 'DebitDate__c' ||
                sFieldName == 'Lumenaza_InstallmentDate__c') {
                // String value of dates have appended hours
                sShouldValue = String.valueOf(LumenazaContractInvoiceSynchronizer.convertToDate(sShouldValue)) + ' 00:00:00';
            }

            System.assertEquals(sShouldValue, sIsValue, 'Field "' + sFieldName + '"');
        }

        // Check on BonusToPaymentLink__c handling
        Map<Id,BonusToPaymentLink__c> mapBonusToPaymentLinksStored = new Map<Id,BonusToPaymentLink__c>([
            SELECT Id, LastModifiedDate, Payment__c, Bonus__c
            FROM BonusToPaymentLink__c
        ]);

        System.assert(!mapBonusToPaymentLinksStored.containsKey(listBonusToPaymentLinks.get(0).Id), 'BonusToPaymentLink__c with index 0 should be deleted by import');
        System.assert(mapBonusToPaymentLinksStored.containsKey(listBonusToPaymentLinks.get(1).Id), 'BonusToPaymentLink__c with index 1 should be left untouched by import');

        System.assertEquals(
            oBonusToPaymentLinkLastModifiedDatetime, mapBonusToPaymentLinksStored.get(listBonusToPaymentLinks.get(1).Id).LastModifiedDate,
            'Expect unaltered LastModifiedDate for BonusToPaymentLink__c with index 1'
        );

        // Check cases
        List<Case> listCases = new List<Case>([SELECT Id, Subject, Description FROM Case]);

        System.debug(DEBUG_HERE + 'Created cases:');
        // 1. Bonus for import payment not found
        // 2. Payments with missing contract no.
        // 3. Payment's contract no. not found
        for (Case oCase : listCases) {
            System.debug(DEBUG_HERE + '    * ' + oCase.Subject);
        }

        System.assertEquals(3, listCases.size());
    }

    /**
     * Test insert of LumenazaMeterInstallation at Lumenaza
     *
     * @since 2018-03-28
     */
    @isTest static void testLumenazaMeterInstallationInsert() {

        String DEBUG_HERE = 'testLumenazaMeterInstallationInsert() - ';

        setupStatic();

        // Prepare Contract
        Contract oContract = [SELECT Id FROM Contract LIMIT 1];
        oContract.LumenazaCustomerId__c = LumenazaRestApiMockDispatcher.CUSTOMER_ID;
        oContract.LumenazaContractId__c = LumenazaRestApiMockDispatcher.CONTRACT_ID;
        oContract.RecordTypeId = recordTypeDeveloperNameToId.get('Contract').get('sonnenflat');
        oContract.Type__c = 'sonnenbatterieHome-DE';
        oContract.TariffType__c = 'sonnenFlat';
        oContract.LumenazaSkipApiCall__c = TRUE;
        update oContract;

        MeterInstallation__c oMeterInstallation = new MeterInstallation__c(
            Account__c                  = oContract.AccountId,
            Contract__c                 = oContract.Id,
            MeterOperator__c            = 'Solandeo', // IMPORTANT!
            LumenazaApiSyncActivated__c = true,
            GridMeterIDZ1__c            = '1234567',
            ConsumptionMeterIDZ2__c     = '1234567',
            FinalInstallationDateandTime__c = System.now() // Since 2018-05-03 (SOBCRM-1185)
        );

        Test.startTest();

        insert oMeterInstallation;

        Test.stopTest();

        oMeterInstallation = [SELECT LumenazaApiStatusCodeZ1__c, LumenazaApiStatusCodeZ2__c FROM MeterInstallation__c WHERE Id = :oMeterInstallation.Id];

        // Check only Z2
        // (see https://interaktiv.jira.com/browse/SOBCRM-1185)
        //System.assertEquals('201', oMeterInstallation.LumenazaApiStatusCodeZ1__c);
        System.assertEquals('201', oMeterInstallation.LumenazaApiStatusCodeZ2__c);
    }

    /**
     * Test update of LumenazaMeterInstallation at Lumenaza
     *
     * @since 2018-03-28
     */
    @isTest static void testLumenazaMeterInstallationUpdate() {

        String DEBUG_HERE = 'testLumenazaMeterInstallationUpdate() - ';

        setupStatic();

        // Prepare Contract
        Contract oContract = [SELECT Id FROM Contract LIMIT 1];
        oContract.LumenazaCustomerId__c = LumenazaRestApiMockDispatcher.CUSTOMER_ID;
        oContract.LumenazaContractId__c = LumenazaRestApiMockDispatcher.CONTRACT_ID;
        oContract.RecordTypeId = recordTypeDeveloperNameToId.get('Contract').get('sonnenflat');
        oContract.Type__c = 'sonnenbatterieHome-DE';
        oContract.TariffType__c = 'sonnenFlat';
        oContract.LumenazaSkipApiCall__c = true;
        update oContract;

        Datetime dtNow = System.now();

        MeterInstallation__c oMeterInstallation = new MeterInstallation__c(
            Account__c                  = oContract.AccountId,
            Contract__c                 = oContract.Id,
            MeterOperator__c            = 'Solandeo', // IMPORTANT!
            LumenazaApiSyncActivated__c = false,
            GridMeterIDZ1__c            = '1234567',
            ConsumptionMeterIDZ2__c     = '1234567',
            LumenazaApiStatusCodeZ1__c  = '201', // Expect no further update
            LumenazaApiRequestTimeZ1__c = dtNow,
            LumenazaApiStatusCodeZ2__c  = '400', // Expect update
            LumenazaApiRequestTimeZ2__c = null,
            FinalInstallationDateandTime__c = System.now() // Since 2018-05-03 (SOBCRM-1185)
        );

        insert oMeterInstallation;

        Test.startTest();

        oMeterInstallation.LumenazaApiSyncActivated__c = true;
        update oMeterInstallation;

        Test.stopTest();

        oMeterInstallation = [SELECT LumenazaApiStatusCodeZ2__c, LumenazaApiRequestTimeZ1__c, LumenazaApiRequestTimeZ2__c FROM MeterInstallation__c WHERE Id = :oMeterInstallation.Id];

        // Check only Z2
        // (see https://interaktiv.jira.com/browse/SOBCRM-1185)
        System.assertEquals(dtNow, oMeterInstallation.LumenazaApiRequestTimeZ1__c);
        System.assert(oMeterInstallation.LumenazaApiRequestTimeZ2__c != null);
        System.assertEquals('201', oMeterInstallation.LumenazaApiStatusCodeZ2__c);
    }

    /**
     * Test LumenazaContractInvoiceSynchronizerScheduler
     *
     * Just for code coverage
     *
     * @since 2016-06-22
     * @see https://interaktiv.jira.com/browse/SOBCRM-705
     */
    @isTest static void testLumenazaContractInvoiceSynchronizerScheduler() {
        // Schedule job (only for code coverage)
        String CRON_EXPRESSION = '0 0 23 * * ?';
        String jobId = System.schedule('Scheduled LumenazaContractInvoiceSched', CRON_EXPRESSION, new LumenazaContractInvoiceSched());
    }
}