/**
 * Awattar Tests
 *
 * Changelog
 * ---------
 *
 * v1.1.0-2017-10-09 (marko@die-interaktiven.de, SOBCRM-1034)
 * - Added testAwattarContractEmailToCustomer()
 *
 * v1.0.0-2017-08-10
 * - initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.1.0-2017-10-09
 */
@isTest
private class AwattarTest {

    private static final String DEBUG_HEADER = 'AwattarTest.';

    private static Map<String, Map<String, Id>> recordTypeDeveloperNameToId;

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


        // Energy Contract
        Contract contract = new Contract(
            RecordTypeId                    = recordTypeContractSonnenFlat,
            Type__c                         = 'sonnenbatterieHome-AT',
            AccountId                       = accounts.get(0).Id,
            Status                          = 'Draft',
            IsInstallerSpezified__c         = TRUE,
            IsPVSizeSpezified__c            = TRUE,
            IsEnergyTariffClassified__c     = TRUE,
            IgnoreRevokationTime__c         = TRUE,
            ContractingPartySalutation__c   = 'Herr',
            ContractingPartnerFirstname__c  = 'Voidy',
            ContractingPartnerLastname__c   = 'Bogusman',
            ContractingPartyAcademicTitle__c = 'Dr.',
            ContractingPartyAccountName__c  = '',
            ContractingPartyEmail__c        = 'test@die-interaktiven.de',
            ContractingPartyPhone__c        = '007-123456',
            BankDataFirstname__c            = 'Voidy',
            BankDataLastname__c             = 'Bogusman',
            BankDataIBAN__c                 = ' DE49 7332_0073 0022.6660 45$',
            BankDataSWIFT__c                = 'CSDB DE 71',
            DeliveryStart__c                = System.today().addMonths(1),
            BillingStreet__c                = 'Voidstreet',
            BillingStreetNumber__c          = '4a',
            BillingPostalCode__c            = '12345',
            BillingCity__c                  = 'Boguscity',
            MeterId__c                      = '7147192',
            PreviousProvider__c             = '9904383000003',
            SEPADate__c                     = System.today(),
            ShippingStreet__c               = 'Locusweg',
            ShippingStreetNumber__c         = '28',
            ShippingPostalCode__c           = '54321',
            ShippingCity__c                 = 'Shipcity',
            MandateReferenceNumber__c       = '123456545687',
            SubscriptionReason__c           = 'New Site (E02)',
            AmountOfFreeEnergy__c           = 5000,
            AnnualConsumption__c            = '5000',
            AnnualConsumptionTotal__c       = 10000,
            OwnConsumption__c               = 2599,
            MeterpointId__c                 = 'CONSUMPTION-1234567',
            MeterpointIdFeedIn__c           = 'GENERATION-1234567',
            ContractingPartyBirthday__c     = System.today().addYears(-39),
            Awattar_comment__c              = 'This is how we do it!',
            PVSize__c                       = 12,
            AwattarApiSyncActivated__c      = FALSE // deactivate sync at first
        );
        insert contract;

        // Awattar Settings
        AwattarSettings__c oAwattarSettings = new AwattarSettings__c(
            Name            = AwattarApi.settingsName,
            ApiDoSync__c    = true,
            ApiTestUrl__c   = 'http://bogus.whitehouse.org',
            ApiLiveUrl__c   = 'http://bogus.whitehouse.org',
            APILiveToken__c = '123456',
            APITestToken__c = '123456'
        );
        insert oAwattarSettings;
    }

    /**
     * Test successful creation of contract at aWATTar
     */
    @isTest static void testAwattarContractCreationSuccess() {

        String DEBUG_HERE = DEBUG_HEADER + '.testAwattarContractCreationSuccess() - ';

        Contract oContract = (Contract) Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');

        oContract.ShippingPostalCode__c = NULL;
        update oContract;

        Test.startTest();

        // Activate sync
        oContract.AwattarApiSyncActivated__c = TRUE;

        // Validation errors expected
        try {
            update oContract;
        }
        catch (Exception e) {
            System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
            System.Assert(e.getMessage().contains('Field "zipcode" is mandatory for Awattar API'));
        }

        // Activate contract
        oContract.ShippingPostalCode__c = '1234';
        oContract.AwattarApiSyncActivated__c = TRUE;

        update oContract;

        AwattarContract oAwattarContract = new AwattarContract(oContract.Id);
        System.assertEquals(true, oAwattarContract.isLocked(AwattarObject.ACTION_UPSERT), 'Assert upsert lock');

        oContract.ShippingPostalCode__c = '4321';
        update oContract;

        Test.stopTest();

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = \'' + oContract.Id + '\'');

    }

    /**
     * Test contract creation at aWATTar with API error
     */
    @isTest static void testAwattarContractCreationApiError() {

        String DEBUG_HERE = DEBUG_HEADER + '.testAwattarContractCreationError() - ';

        Contract oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');
        Integer iStatusCode = 500;

        AwattarRestApiMockDispatcher.setResultBodyNextRoute('API-Exception at aWATTar', iStatusCode);

        Test.startTest();

        // Activate sync
        oContract.AwattarApiSyncActivated__c = TRUE;

        update oContract;

        Test.stopTest();

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = \'' + oContract.Id + '\'');

        System.assertEquals(String.valueOf(iStatusCode), oContract.AwattarApiStatusCode__c);
        //System.debug('Contact: ' + JSON.serializePretty(oContract));

        // Assert a Case
        List<Case> listCases = [SELECT Contract__c, AccountId, ContactId, Subject, Description FROM Case];
        System.assertEquals(1, listCases.size());

        Case oCase = listCases.get(0);

        System.assertEquals(oCase.Contract__c, oContract.Id);
        //System.debug('Case: ' + JSON.serializePretty(oCase));
    }

    /**
     * Test Contract update with AwattarApiSyncActivated__c
     * turned off
     */
    @isTest static void testAwattarContractUpdateWithSyncOff() {

        String DEBUG_HERE = DEBUG_HEADER + '.testAwattarContractUpdateWithSyncOff() - ';

        Contract oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');
        oContract.AwattarContractId__c = 'con_123456';
        update oContract;

        Test.startTest();

        // Change some values
        oContract.ContractingPartnerLastname__c = 'Voidness';

        update oContract;

        Test.stopTest();

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = \'' + oContract.Id + '\'');

        // Expect NO callout
        System.assertEquals(NULL, oContract.AwattarApiStatusCode__c);
    }

    /**
     * Test updating a contract with an aWATTar ID which would normally not be
     * the case but can be forced by activating AwattarApiForceSync__c
     */
    @isTest static void testAwattarContractUpdateForced() {

        String DEBUG_HERE = DEBUG_HEADER + '.testAwattarContractUpdateForced() - ';

        Contract oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');
        oContract.AwattarContractId__c = 'con_123456';
        update oContract;

        Test.startTest();

        // Change some values
        oContract.AwattarApiSyncActivated__c = TRUE;
        oContract.AwattarApiForceSync__c = TRUE;
        oContract.ContractingPartnerLastname__c = 'Voidness';

        update oContract;

        Test.stopTest();

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = \'' + oContract.Id + '\'');

        //System.debug('Contract: ' + JSON.serializePretty(oContract));
        System.assertEquals('200', oContract.AwattarApiStatusCode__c);
    }

    /**
     * Test triggering of customer email after setting aWATTar
     * contract ID
     *
     * @since 2017-10-09
     * @see https://interaktiv.jira.com/browse/SOBCRM-1034
     */
    @isTest static void testAwattarContractEmailToCustomer() {

        String DEBUG_HERE = DEBUG_HEADER + '.testAwattarContractUpdateForced() - ';

        Contract oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract LIMIT 1');

        Test.startTest();

        oContract.AwattarApiSyncActivated__c = TRUE;
        oContract.AwattarContractId__c = 'con_123456';
        update oContract;

        Test.stopTest();

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = \'' + oContract.Id + '\'');

        System.assertNotEquals(NULL, oContract.AwattarApiCustomerEmailInitialized__c);
        System.assertEquals(false, oContract.AwattarApiCustomerEmailTrigger__c);
    }
}