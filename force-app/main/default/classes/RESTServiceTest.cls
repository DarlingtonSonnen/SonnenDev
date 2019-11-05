/**
 * Tests for RESTService classes
 *
 * Changelog
 * ---------
 *
 * v1.5.0-2017-10-06 (MSB, SOBCRM-1076)
 * - Added test of language determination in testRESTServiceContractLanguageISOCodeMapping()
 *   and testRESTServiceContractEnergy()
 *
 * v1.4.0-2017-09-21 (MSB, SOBCRM-1042)
 * - Added new fields for "solar" Contracts in testRESTServiceContractSonnenStrom()
 *
 * v1.3.0-2017-06-20 (MSB, SOBCRM-984)
 * - Added testRESTServiceContractSonnenStrom()
 *
 * v1.2.0-2017-04-11 (MSB, SOBCRM-825)
 * - Added testRESTServiceContractCommunityWithFlatOption()
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.5.0-2017-10-06
 */
@IsTest
private class RESTServiceTest {

    private static Map<String,String> requestDataRESTServiceContract;

    private static Map<String,Map<String,Id>> recordTypeDeveloperNameToId;

    private static Account accountForCommunityContract;
    private static Contract communityContract;

    @isTest static void setupStatic() {

        // Get record types
        recordTypeDeveloperNameToId = new Map<String,Map<String,String>>();
        List<RecordType> recordTypes = new List<RecordType>([SELECT Id, Name, DeveloperName, SObjectType FROM RecordType WHERE IsActive = true AND (SObjectType = 'Contract' OR SObjectType = 'Account')]);

        for (RecordType recordType : recordTypes) {
            if (recordTypeDeveloperNameToId.get(recordType.SObjectType) == NULL) {
                recordTypeDeveloperNameToId.put(recordType.SObjectType, new Map<String,String>());
            }
            recordTypeDeveloperNameToId.get(recordType.SObjectType).put(recordType.DeveloperName.toLowerCase(), recordType.Id);
        }

        requestDataRESTServiceContract = new Map<String,String>{
                'contractType'            => 'energy',
                'isBusiness'              => 'true',
                'email'                   => 'voidy@die-interaktiven.de',
                'withdrawalConfirmed'     => 'true',
                'company'                 => 'ACME',
                'salutation'              => 'Herr',
                'academicTitle'           => 'Dr.',
                'firstName'               => 'Voidy',
                'lastName'                => '',
                'phone'                   => '012345-46454',
                'shippingStreet'          => '',
                'shippingStreetNo'        => '',
                'shippingZip'             => '',
                'shippingCity'            => '',
                'billingStreet'           => 'Nullstr.',
                'billingStreetNo'         => '1',
                'billingZip'              => '12345',
                'billingCity'             => 'Anywhere',
                'billingCountry'          => 'DE',
                'deliveryStartDate'       => String.valueOf(System.today().addMonths(1)),
                'subscriptionReason'      => 'Move into Location (E01)', // Move into Location (E01) | New Site (E02) | Change of Provider (E03)
                'meterId'                 => '7147192',
                'meteringPointId'         => '',
                'previousProvider'        => '9904383000003',
                'annualConsumption'       => '10000',
                'bankAccountFirstName'    => 'Voidy',
                'bankAccountLastName'     => 'Bogusberg',
                'bankIbanNo'              => 'DE49733200730022666045',
                'sepaDate'                => String.valueOf(System.today()),
                'rateType'                => 'household', // household | heatpump
                'type'                    => 'sonnenbatterieHome-DE', // added 2017-03-27 (SOBCRM-852)
                'withdrawalConfirmed'     => 'true',
                'termsOfServiceConfirmed' => 'true'
        };
    }

    @testSetup static void setup() {

        setupStatic();

        Id recordTypeBusinessAccount   = recordTypeDeveloperNameToId.get('Account').get('businessaccount');
        Id recordTypePrivateAccount    = recordTypeDeveloperNameToId.get('Account').get('private');
        Id recordTypeContractEnergy    = recordTypeDeveloperNameToId.get('Contract').get('energy');
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
                Salutation        = 'Herr',
                AcademicTitle__pc = 'Dr.',
                FirstName         = 'Hans',
                LastName          = 'Pampel',
                PersonEmail       = 'pampel@test.org',
                Phone             = '02354-5488924',
                RecordTypeId      = recordTypePrivateAccount
        ));
        insert accounts;

        Contact oContact = new Contact(
            FirstName = 'Walter',
            LastName = 'Wurstsalat',
            AccountId = accounts.get(0).Id
        );
        insert oContact;

        // Energy Contract
        Contract contract = new Contract(
                RecordTypeId                         = recordTypeContractEnergy,
                AccountId                            = accounts.get(0).Id,
                Status                               = 'Draft',
                ContractingPartySalutation__c        = 'Herr',
                ContractingPartnerFirstname__c       = 'Voidy',
                ContractingPartnerLastname__c        = 'Bogusman',
                ContractingPartyAcademicTitle__c     = 'Dr.',
                ContractingPartyAccountName__c       = '',
                ContractingPartyEmail__c             = 'test@die-interaktiven.de',
                ContractingPartyPhone__c             = '007-123456',
                AnnualConsumption__c                 = '5000',
                BankDataFirstname__c                 = 'Voidy',
                BankDataLastname__c                  = 'Bogusman',
                BankDataIBAN__c                      = ' de49 7332_0073 0022.6660 45$',
                DeliveryStart__c                     = System.today().addMonths(1),
                BillingStreet__c                     = 'Voidstreet',
                BillingStreetNumber__c               = '4a',
                BillingPostalCode__c                 = '12345',
                BillingCity__c                       = 'Boguscity',
                MeterId__c                           = '7147192',
                PreviousProvider__c                  = '9904383000003',
                SEPADate__c                          = System.today(),
                ShippingStreet__c                    = 'Locusweg',
                ShippingStreetNumber__c              = '28',
                ShippingPostalCode__c                = '54321',
                ShippingCity__c                      = 'Shipcity',
                TariffType__c                        = 'household',
                Type__c                              = 'sonnenbatterieHome-DE',
                SubscriptionReason__c                = 'New Site (E02)',
                CustomerSignedId                     = oContact.Id
        );
        insert contract;

        // Lumenaza Settings
        LumenazaSettings__c settings = new LumenazaSettings__c(
                Name                 = LumenazaApi.settingsName,
                ApiDoSync__c         = true,
                ApiUseTest__c        = true,
                ApiTestUrl__c        = 'http://bogus.whitehouse.org',
                ApiTestUsername__c   = 'bogus',
                ApiTestPassword__c   = 'bogus',
                ApiTestAuthClient__c = 'bogus',
                ApiTestAuthSecret__c = 'bogus',
                ApiLiveUrl__c        = 'http://bogus.whitehouse.org',
                ApiLiveUsername__c   = 'bogus',
                ApiLivePassword__c   = 'bogus',
                ApiLiveAuthClient__c = 'bogus',
                ApiLiveAuthSecret__c = 'bogus'
        );
        insert settings;
    }

    @isTest static void setupCommunityContract() {

        if (accountForCommunityContract == NULL) {
            return;
        }

        Id idContactId =
            accountForCommunityContract.PersonContactId != null ?
            accountForCommunityContract.PersonContactId :
            accountForCommunityContract.Contacts.get(0).Id;

        communityContract = new Contract(
            RecordTypeId                         = [SELECT Id FROM RecordType WHERE Developername = 'Community' AND SObjectType = 'Contract'].Id,
            AccountId                            = accountForCommunityContract.Id,
            Type__c                              = 'sonnenbatterieCity-DE',
            Status                               = 'Draft',
            ContractingPartySalutation__c        = 'Herr',
            ContractingPartnerFirstname__c       = 'Voidy',
            ContractingPartnerLastname__c        = 'Bogusman',
            ContractingPartyAcademicTitle__c     = 'Dr.',
            ContractingPartyAccountName__c       = 'ACME Corp.',
            ContractingPartyEmail__c             = 'test@die-interaktiven.de',
            ContractingPartyPhone__c             = '007-123456',
            BillingStreet__c                     = 'Voidstreet',
            BillingStreetNumber__c               = '4a',
            BillingPostalCode__c                 = '12345',
            BillingCity__c                       = 'Boguscity',
            CustomerSignedId                     = idContactId
        );

        insert communityContract;

        // Activate Community Contract
        communityContract.Status = 'Activated';
        update communityContract;
    }

    /**
     * Test RESTServiceContract with successfull Energy Contract creation
     */
    @isTest static void testRESTServiceContractEnergy() {

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('lastName', 'Boogieman');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractEnergy() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractEnergy() Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractEnergy() Expected status OK');

        String email = requestDataRESTServiceContract.get('email');
        List<Contract> contracts = [
            SELECT
                Id,
                RecordType.DeveloperName,
                CustomerSignedId,
                ContractingPartyAccountName__c,
                ContractingPartyEmail__c,
                BankData__r.SepaReference__c,
                BillingCountry__c
            FROM
                Contract
            WHERE
                ContractingPartyEmail__c = :email
        ];
        System.debug('RESTServiceTest - testRESTServiceContractEnergy() Contracts: ' + contracts);

        Boolean hasCommunityContract = false;
        Boolean hasEnergyContract = false;

        Id customerSignedId = contracts[0].CustomerSignedId;
        System.assert(customerSignedId != NULL, 'Expect a CustomerSignedId');

        for (Contract contract : contracts) {

            System.assert(contract.BankData__r.SepaReference__c != NULL);

            if (contract.RecordType.DeveloperName.toLowerCase() == 'community') {
                hasCommunityContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
                System.debug('RESTServiceTest - testRESTServiceContractEnergy() "community" SepaReference__c: ' + contract.BankData__r.SepaReference__c);
            }
            if (contract.RecordType.DeveloperName.toLowerCase() == 'energy') {
                hasEnergyContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
                System.debug('RESTServiceTest - testRESTServiceContractEnergy() "energy" SepaReference__c: ' + contract.BankData__r.SepaReference__c);
            }
        }

        // Get created Account / Contact
        // Expecting business account so contact had to be created
        Contact contact = [SELECT Id, FirstName, LastName, Language__c FROM Contact WHERE Id = :customerSignedId];
        System.assertEquals(requestDataRESTServiceContract.get('lastName'), contact.LastName, 'Expecting LastName of contact to be "' + requestDataRESTServiceContract.get('lastName') + '"');
        System.assertEquals('de', contact.Language__c, 'Expected language ISO code to be "de" according to billingCountry "' + contracts[0].BillingCountry__c);

        System.assertEquals(2, contracts.size(), 'RESTServiceTest - testRESTServiceContractEnergy() Expected exactly 2 contracts');
        System.assert((hasCommunityContract && hasEnergyContract), 'RESTServiceTest - testRESTServiceContractEnergy() Expect 1 "community" and one "energy" Conctract');
    }

    /**
     * Test RESTServiceContract with successfull "sonnenFlat" Contract creation
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @see https://interaktiv.jira.com/browse/SOBCRM-678
     * @since 2016-10-20
     */
    @isTest static void testRESTServiceContractSonnenFlat() {

        String DEBUG_HERE = 'RESTServiceTest - testRESTServiceContractSonnenFlat() ';

        setupStatic();

        // Create a Partner Account to refer to by "installer"
        Id recordTypePartnerAccount = recordTypeDeveloperNameToId.get('Account').get('sbc');
        System.assertNotEquals(NULL, recordTypePartnerAccount);

        Account partnerAccount = new Account(
                RecordTypeId = recordTypePartnerAccount,
                Name = 'Partner'
        );
        insert partnerAccount;

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values to run in no validation errors
        requestDataRESTServiceContract.put('lastName', 'Boogieman');

        // Exclusive to "sonnenFlat"
        requestDataRESTServiceContract.put('contractType',           'sonnenFlat');
        requestDataRESTServiceContract.put('type',                   'sonnenbatterieCity-DE');
        requestDataRESTServiceContract.put('rateType',               'sonnenCity');
        requestDataRESTServiceContract.put('amountOfFreeEnergy',     '4250');
        requestDataRESTServiceContract.put('annualConsumptionTotal', '20000');
        requestDataRESTServiceContract.put('installer',              partnerAccount.Id);
        requestDataRESTServiceContract.put('isInstallerUnknown',     'true');
        requestDataRESTServiceContract.put('otherInstaller',         '');
        requestDataRESTServiceContract.put('previousProviderName',   'Hans Meiser');
        requestDataRESTServiceContract.put('termsAndConditions',     'Version 1.2.3');
        requestDataRESTServiceContract.put('externalOrderId',        'Bla-12345');
        requestDataRESTServiceContract.put('attachment1Name',        'Invoice.pdf');
        requestDataRESTServiceContract.put('attachment1URL',         'http://www.test.de/uploads/Invoice.pdf');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug(DEBUG_HERE + 'Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();

        Test.stopTest();

        //-------------------------------
        // ASSERTIONS
        //-------------------------------
        System.debug(DEBUG_HERE + 'Response: ' + response);

        System.assertEquals('OK', response.getStatus(), DEBUG_HERE + 'Expected status OK');

        String email = requestDataRESTServiceContract.get('email');
        List<Contract> contracts = [SELECT Id, RecordType.DeveloperName, CustomerSignedId, ContractingPartyAccountName__c, ContractingPartyEmail__c FROM Contract WHERE ContractingPartyEmail__c = :email];
        System.debug(DEBUG_HERE + 'Contracts: ' + contracts);

        Boolean hasCommunityContract = false;
        Boolean hasSonnenFlatContract = false;

        Id customerSignedId = contracts[0].CustomerSignedId;
        System.assert(customerSignedId != NULL, 'Expect a CustomerSignedId');

        Contract sonnenFlatContract;

        for (Contract contract : contracts) {
            if (contract.RecordType.DeveloperName.toLowerCase() == 'community') {
                hasCommunityContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
            }
            if (contract.RecordType.DeveloperName.toLowerCase() == 'sonnenflat') {
                hasSonnenFlatContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
                sonnenFlatContract = contract;
            }
        }

        System.assertEquals(2, contracts.size(), DEBUG_HERE + 'Expected exactly 2 contracts');
        System.assert((hasCommunityContract && hasSonnenFlatContract), DEBUG_HERE +  'Expect 1 "community" and one "sonnenFlat" Conctract');
        System.assertEquals(1, RESTServiceContract.attachmentsForUnitTest.size());

        Map<String,String> mapAttachment = RESTServiceContract.attachmentsForUnitTest.get(0);

        System.assertEquals('INVOICE - ' + requestDataRESTServiceContract.get('attachment1Name'), mapAttachment.get('name'));
        System.assertEquals(sonnenFlatContract.Id, mapAttachment.get('contractId'));
    }

    /**
     * Test RESTServiceContract with successfull "sonnenStrom" Contract creation
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @see https://interaktiv.jira.com/browse/SOBCRM-984
     * @since 2017-06-16
     */
    @isTest static void testRESTServiceContractSonnenStrom() {

        String DEBUG_HERE = 'RESTServiceTest - testRESTServiceContractSonnenStrom() ';

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values to run in no validation errors
        requestDataRESTServiceContract.put('lastName', 'Boogieman');

        // Exclusive to "sonnenStrom"
        requestDataRESTServiceContract.put('contractType',           'sonnenStrom');
        requestDataRESTServiceContract.put('type',                   'solar');
        requestDataRESTServiceContract.put('rateType',               'sonnenStrom');
        requestDataRESTServiceContract.put('appointedEnergyRate',    '12345.67');
        requestDataRESTServiceContract.put('communityFee',           '9.99');
        requestDataRESTServiceContract.put('confirmedDeliveryStart', String.valueOf(System.today().addDays(90)));
        requestDataRESTServiceContract.put('powerPVPlant',           '10.99');
        requestDataRESTServiceContract.put('pvInstallationDate',     String.valueOf(System.today().addDays(-60)));

        // Special for Type "solar"
        requestDataRESTServiceContract.put('optionalHardware',       'Powerline mit Gehäuse');
        requestDataRESTServiceContract.put('mi_meteringConcept',     'mc5');
        requestDataRESTServiceContract.put('mi_productionMeterId',   '123456');
        requestDataRESTServiceContract.put('mi_meterOperator',       'Discovergy');
        requestDataRESTServiceContract.put('mi_gatewayType',         'internetConnectionCustomer');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug(DEBUG_HERE + 'Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();

        Test.stopTest();

        //-------------------------------
        // ASSERTIONS
        //-------------------------------
        System.debug(DEBUG_HERE + 'Response: ' + response);

        System.assertEquals('OK', response.getStatus(), DEBUG_HERE + 'Expected status OK');

        String email = requestDataRESTServiceContract.get('email');
        List<Contract> contracts = [SELECT Id, RecordType.DeveloperName, CustomerSignedId, ContractingPartyAccountName__c, ContractingPartyEmail__c FROM Contract WHERE ContractingPartyEmail__c = :email];
        System.debug(DEBUG_HERE + 'Contracts: ' + contracts);

        Boolean hasCommunityContract = false;
        Boolean hasSonnenStromContract = false;

        Id customerSignedId = contracts[0].CustomerSignedId;
        System.assert(customerSignedId != NULL, 'Expect a CustomerSignedId');

        Contract sonnenFlatContract;

        for (Contract contract : contracts) {
            if (contract.RecordType.DeveloperName.toLowerCase() == 'community') {
                hasCommunityContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
            }
            if (contract.RecordType.DeveloperName.toLowerCase() == 'sonnenstrom') {
                hasSonnenStromContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
                sonnenFlatContract = contract;
            }
        }

        System.assert(!hasCommunityContract, DEBUG_HERE +  'Expect NO "community" Contract');
        System.assert(hasSonnenStromContract, DEBUG_HERE +  'Expect a "sonnenStrom" Conctract');

        // Type "solar" should create a MeterInstallation object
        List<MeterInstallation__c> listMeterInstallations = [
            SELECT Id, MeteringConcept__c, ProductionMeterID__c, MeterOperator__c, GatewayType__c, OptionalHardware__c
            FROM MeterInstallation__c
            WHERE Contract__c = :sonnenFlatContract.Id
        ];
        System.assertEquals(1, listMeterInstallations.size());

        MeterInstallation__c oMeterInstallation = listMeterInstallations.get(0);

        System.assertEquals(requestDataRESTServiceContract.get('optionalHardware'),     oMeterInstallation.OptionalHardware__c,  'OptionalHardware__c');
        System.assertEquals(requestDataRESTServiceContract.get('mi_meteringConcept'),   oMeterInstallation.MeteringConcept__c,   'MeteringConcept__c');
        System.assertEquals(requestDataRESTServiceContract.get('mi_productionMeterId'), oMeterInstallation.ProductionMeterID__c, 'ProductionMeterID__c');
        System.assertEquals(requestDataRESTServiceContract.get('mi_meterOperator'),     oMeterInstallation.MeterOperator__c,     'MeterOperator__c');
        System.assertEquals(requestDataRESTServiceContract.get('mi_gatewayType'),       oMeterInstallation.GatewayType__c,       'GatewayType__c');
    }

    /**
     * Testing asynchronous callout of RESTServiceContract.saveURLAsAttachment()
     *
     * This is very annoying: There is NO way to run this in the test above
     * as this always raise the error "You have uncommitted work pending bla bla".
     * According to https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_restful_http_testing_dml.htm
     * it should work if you wrap callouts in Test.startTest() and Test.stopTest() - no way.
     * The test always shifts the whole process in a synchronous state which
     * raises the error.
     *
     * So go fuck yourself Salesforce! What's the point of Unit Tests if this can't
     * be tested? saveURLAsAttachment() is annotated as a future callout so make
     * sure that this will be simulated. It's not my duty to care for this if the
     * code works fine in the "real" world.
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @see https://interaktiv.jira.com/browse/SOBCRM-678
     * @since 2016-10-20
     */
    @isTest static void testRESTServiceContractSaveAttachments() {

        String DEBUG_HERE = 'RESTServiceTest - testRESTServiceContractSaveAttachments() ';

        String attachmentName = 'Test';
        String attachmentURL  = 'http://www.test.de/uploads/rechnung.pdf';

        Contract contract = [SELECT Id FROM Contract LIMIT 1];

        Test.startTest();
        RESTServiceContract.saveURLAsAttachment(attachmentName, attachmentURL, contract.Id);
        Test.stopTest();

        contract = [SELECT Id, (SELECT Id, Name, BodyLength FROM Attachments) FROM Contract WHERE Id = :contract.Id];

        RESTServiceContract.AttachmentLoaderMockDispatcher temp = new RESTServiceContract.AttachmentLoaderMockDispatcher();

        System.debug(DEBUG_HERE + 'Attachments: ' + contract.Attachments);
        System.assertEquals(1, contract.Attachments.size());
        System.assertEquals(attachmentName, contract.Attachments.get(0).Name);
        System.assertEquals(temp.getResponseBody().length(), contract.Attachments.get(0).BodyLength);
    }

    /**
     * Same as above but with an error case created
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @see https://interaktiv.jira.com/browse/SOBCRM-678
     * @see testRESTServiceContractSaveAttachments()
     * @since 2016-10-20
     */
    @isTest static void testRESTServiceContractSaveAttachmentsWithErrorCase() {

        String DEBUG_HERE = 'RESTServiceTest - testRESTServiceContractSaveAttachmentsWithErrorCase() ';

        String attachmentName = 'Test';
        String attachmentURL  = 'http://www.test.de/uploads/rechnung.pdf';

        Test.startTest();
        RESTServiceContract.saveURLAsAttachment(attachmentName, attachmentURL, NULL);
        Test.stopTest();

        List<Case> errorCases = new List<Case>([SELECT Subject, Description FROM Case]);
        System.assertEquals(1, errorCases.size());
        System.debug(DEBUG_HERE + 'Case: ' + errorCases.get(0));
    }

    /**
     * Test RESTServiceContract with successfull Energy Contract creation
     * with Person Account creation
     */
    @isTest static void testRESTServiceContractEnergyPersonAccount() {

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('lastName', 'Bogusberg');
        requestDataRESTServiceContract.put('isBusiness', 'false'); // Expecting PersonAccount to be created!

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractEnergyPersonAccount() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractEnergyPersonAccount() Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractEnergyPersonAccount() Expected status OK');

        String email = requestDataRESTServiceContract.get('email');
        List<Contract> contracts = [SELECT Id, RecordType.DeveloperName, CustomerSignedId, ContractingPartyAccountName__c, ContractingPartyEmail__c FROM Contract WHERE ContractingPartyEmail__c = :email];
        System.debug('RESTServiceTest - testRESTServiceContractEnergyPersonAccount() Contracts: ' + contracts);

        Boolean hasCommunityContract = false;
        Boolean hasEnergyContract = false;

        Id customerSignedId = contracts[0].CustomerSignedId;
        System.assert(customerSignedId != NULL, 'Expect a CustomerSignedId');

        for (Contract contract : contracts) {
            if (contract.RecordType.DeveloperName.toLowerCase() == 'community') {
                hasCommunityContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
            }
            if (contract.RecordType.DeveloperName.toLowerCase() == 'energy') {
                hasEnergyContract = true;
                System.assertEquals(customerSignedId, contract.CustomerSignedId);
            }
        }

        // Get created Account / Contact
        // Expecting a PersonAccount to be created
        Account account = [SELECT Id, FirstName, LastName FROM Account WHERE PersonContactId = :customerSignedId];
        System.assertEquals(requestDataRESTServiceContract.get('lastName'), account.LastName, 'Expecting LastName of account to be "' + requestDataRESTServiceContract.get('lastName') + '"');

        System.assertEquals(2, contracts.size(), 'RESTServiceTest - testRESTServiceContractEnergy() Expected exactly 2 contracts');
        System.assert((hasCommunityContract && hasEnergyContract), 'RESTServiceTest - testRESTServiceContractEnergy() Expect 1 "community" and one "energy" Conctract');
    }

    /**
     * Test RESTServiceContract with successfull Community Contract creation
     */
    @isTest static void testRESTServiceContractCommunityOnly() {

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('contractType', 'community');
        requestDataRESTServiceContract.put('lastName', 'Boogieman');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractCommunityOnly() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractCommunityOnly() Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractCommunityOnly() Expected status OK');

        String email = requestDataRESTServiceContract.get('email');
        List<Contract> contracts = [SELECT Id, RecordType.DeveloperName, ContractingPartyAccountName__c, ContractingPartyEmail__c FROM Contract WHERE ContractingPartyEmail__c = :email];
        System.debug('RESTServiceTest - testRESTServiceContractCommunityOnly() Contracts: ' + contracts);

        System.assertEquals(1, contracts.size(), 'RESTServiceTest - testRESTServiceContractCommunityOnly() Expected exactly 1 contract');
        System.assert(contracts.get(0).RecordType.DeveloperName == 'community', 'RESTServiceTest - testRESTServiceContractCommunityOnly() Expect Contract to be of type "community"');
    }

    /**
     * Test RESTServiceContract with successfull CommunityWithFlatOption Contract creation
     */
    @isTest static void testRESTServiceContractCommunityWithFlatOption() {

        String DEBUG_HERE = 'RESTServiceTest - testRESTServiceContractCommunityWithFlatOption(): ';

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('lastName', 'Boogieman');

        requestDataRESTServiceContract.put('contractType',          'communityWithFlatOption');
        requestDataRESTServiceContract.put('type',                  'sonnenbatterieHome-IT');
        requestDataRESTServiceContract.put('identificationNumber',  '123456789897');
        requestDataRESTServiceContract.put('optInEdison',           'true');
        requestDataRESTServiceContract.put('powerOfMeter',          '15.5');
        requestDataRESTServiceContract.put('rateType',              '');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug(DEBUG_HERE + 'Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug(DEBUG_HERE + 'Response: ' + response);
        System.assertEquals('OK', response.getStatus(), DEBUG_HERE + 'Expected status OK');

        String email = requestDataRESTServiceContract.get('email');
        List<Contract> contracts = [
            SELECT
                Id,
                Status,
                RecordType.DeveloperName,
                ContractingPartyAccountName__c,
                ContractingPartyEmail__c,
                IsOptInEdison__c,
                PowerOfMeter__c,
                Account.IdentificationNumber__c
            FROM
                Contract
            WHERE
                ContractingPartyEmail__c = :email
        ];
        System.debug(DEBUG_HERE + 'Contracts: ' + contracts);

        System.assertEquals(1, contracts.size(), DEBUG_HERE + 'Expected exactly 1 contract');

        Contract oContractToCompare = contracts.get(0);
        System.assert(oContractToCompare.RecordType.DeveloperName == 'CommunityWithFlatOption', DEBUG_HERE + 'Expect Contract to be of type "CommunityWithFlatOption"');
        System.assertEquals(TRUE, oContractToCompare.IsOptInEdison__c);
        System.assertEquals(Double.valueOf(requestDataRESTServiceContract.get('powerOfMeter')), Double.valueOf(oContractToCompare.PowerOfMeter__c));
        System.assertEquals(requestDataRESTServiceContract.get('identificationNumber'), oContractToCompare.Account.IdentificationNumber__c);
        System.assertEquals('Draft', oContractToCompare.Status);
    }
    /**
     * Test RESTServiceContract with error
     */
    @isTest static void testRESTServiceContractWithError() {

        setupStatic();

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // convert to blob for body
        Map<String,String> values = requestDataRESTServiceContract;

        String requestJson = (String)JSON.serialize(values);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractWithError() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractWithError() - Response: ' + response);
        System.assertEquals('NOK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractWithError() Expected NOK status due to validation error');
    }

    /**
     * Test RESTServiceContract GET with querying an existing Community Contract
     * by communityContractNo and customerNo
     */
    @isTest static void testRESTServiceContractQueryExistingCommunityContract() {

        setupStatic();

        accountForCommunityContract = [SELECT Id, CustomerNo__c, PersonContactId FROM Account WHERE RecordTypeId = :recordTypeDeveloperNameToId.get('Account').get('private') LIMIT 1];
        setupCommunityContract();

        String communityContractNumber = [SELECT ContractNumber FROM Contract WHERE Id = :communityContract.Id].ContractNumber;

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.addParameter('communityContractNo', communityContractNumber);
        request.addParameter('customerNo', accountForCommunityContract.CustomerNo__c);
        request.httpMethod = 'GET';

        System.debug('RESTServiceTest - testRESTServiceContractQueryExistingCommunityContract(): Request parameters are ' + request);

        // Set REST context
        RestContext.request  = request;
        DiaRESTResponse response = RESTServiceContract.handleGet();

        System.debug('RESTServiceTest - testRESTServiceContractQueryExistingCommunityContract(): Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractQueryExistingCommunityContract() Expected status OK');

        List<Map<String,String>> genericObjects = response.getGenericObjects();
        System.assertEquals(1, genericObjects.size());

        Test.stopTest();
    }

    /**
     * Test RESTServiceContract POST with Energy Contract creating from
     * an existing Community Contract
     */
    @isTest static void testRESTServiceContractFromExistingCommunityContractBusinessAccount() {

        setupStatic();

        accountForCommunityContract = [SELECT Id, PersonContactId, CustomerNo__c, (SELECT Id FROM Contacts LIMIT 1) FROM Account WHERE RecordTypeId = :recordTypeDeveloperNameToId.get('Account').get('businessaccount') LIMIT 1];
        setupCommunityContract();

        // Create a Contact for Account
        Contact contact = new Contact(
                AccountId          = accountForCommunityContract.Id,
                Salutation         = requestDataRESTServiceContract.get('salutation'),
                AcademicTitle__c   = requestDataRESTServiceContract.get('academicTitle'),
                FirstName          = requestDataRESTServiceContract.get('firstName'),
                LastName           = 'Meier',
                MailingStreet      = (requestDataRESTServiceContract.get('billingStreet') + ' ' + requestDataRESTServiceContract.get('billingStreetNo')).trim(),
                MailingPostalCode  = requestDataRESTServiceContract.get('billingZip'),
                MailingCity        = requestDataRESTServiceContract.get('billingCity'),
                Email              = requestDataRESTServiceContract.get('email'),
                Phone			   = requestDataRESTServiceContract.get('phone')
        );
        insert contact;

        String communityContractNumber = [SELECT ContractNumber FROM Contract WHERE Id = :communityContract.Id].ContractNumber;

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('lastName', contact.LastName);
        requestDataRESTServiceContract.put('contractType', 'sonnenFlat');
        requestDataRESTServiceContract.put('type', 'sonnenbatterieCity-DE');
        requestDataRESTServiceContract.put('rateType', 'sonnenCity');
        requestDataRESTServiceContract.put('communityContractNo', communityContractNumber);
        requestDataRESTServiceContract.put('customerNo', accountForCommunityContract.CustomerNo__c);
        requestDataRESTServiceContract.put('phone', '007');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractFromExistingCommunityContractBusinessAccount() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractFromExistingCommunityContractBusinessAccount() Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractFromExistingCommunityContractBusinessAccount() Expected status OK ' + response);

        // Expect a new Energy Contract under Account
        Contract newEnergyContract = [SELECT Id, RecordType.DeveloperName FROM Contract WHERE CommunityContract__c = :communityContract.Id AND AccountId = :accountForCommunityContract.Id];
        System.assertEquals('SonnenFlat', newEnergyContract.RecordType.DeveloperName, 'Expect new Contract to be of type "SonnenFlat"');

        // Expect a change in the Contact's Phone
        List<Contact> accountContacts = [SELECT Id, Phone FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(requestDataRESTServiceContract.get('phone'), accountContacts.get(0).Phone, 'Expect change in Contact\'s LastName');
    }

    /**
     * Test RESTServiceContract POST with Energy Contract creating from
     * an existing Community Contract and creation of a new Contact as
     * there is none yet
     */
    @isTest static void testRESTServiceContractFromExistingCommunityContractBusinessAccountNewContact() {

        setupStatic();

        accountForCommunityContract = [SELECT Id, CustomerNo__c, PersonContactId, (SELECT Id FROM Contacts LIMIT 1) FROM Account WHERE RecordTypeId = :recordTypeDeveloperNameToId.get('Account').get('businessaccount') LIMIT 1];
        setupCommunityContract();

        String communityContractNumber = [SELECT ContractNumber FROM Contract WHERE Id = :communityContract.Id].ContractNumber;

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('lastName', 'Bogusberg');
        requestDataRESTServiceContract.put('contractType', 'sonnenFlat');
        requestDataRESTServiceContract.put('type', 'sonnenbatterieCity-DE');
        requestDataRESTServiceContract.put('rateType', 'sonnenCity');
        requestDataRESTServiceContract.put('communityContractNo', communityContractNumber);
        requestDataRESTServiceContract.put('customerNo', accountForCommunityContract.CustomerNo__c);
        requestDataRESTServiceContract.put('phone', '007');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractFromExistingCommunityContractBusinessAccount() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractFromExistingCommunityContractBusinessAccount() Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractFromExistingCommunityContractBusinessAccount() Expected status OK ' + response);

        // Expect a new Energy Contract under Account
        Contract newEnergyContract = [SELECT Id, RecordType.DeveloperName FROM Contract WHERE CommunityContract__c = :communityContract.Id AND AccountId = :accountForCommunityContract.Id];
        System.assertEquals('SonnenFlat', newEnergyContract.RecordType.DeveloperName, 'Expect new Contract to be of type "SonnenFlat"');

        List<Contact> accountContacts = [SELECT Id, Phone FROM Contact WHERE AccountId = :accountForCommunityContract.Id];
        System.assertEquals(2, accountContacts.size(), 'Expect two contacts');
    }

    /**
     * Test RESTServiceContract POST with Energy Contract creating from
     * an existing Community Contract owned by a Person Account
     */
    @isTest static void testRESTServiceContractFromExistingCommunityContractPersonAccount() {

        setupStatic();

        accountForCommunityContract = [SELECT Id, CustomerNo__c, PersonContactId, LastName FROM Account WHERE RecordTypeId = :recordTypeDeveloperNameToId.get('Account').get('private') LIMIT 1];
        setupCommunityContract();

        String communityContractNumber = [SELECT ContractNumber FROM Contract WHERE Id = :communityContract.Id].ContractNumber;

        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/contract/';
        request.addParameter('token', RESTService.ACCESS_TOKEN);
        request.httpMethod = 'POST';

        // Set values
        requestDataRESTServiceContract.put('lastName', accountForCommunityContract.LastName);
        requestDataRESTServiceContract.put('contractType', 'sonnenFlat');
        requestDataRESTServiceContract.put('type', 'sonnenbatterieCity-DE');
        requestDataRESTServiceContract.put('rateType', 'sonnenCity');
        requestDataRESTServiceContract.put('communityContractNo', communityContractNumber);
        requestDataRESTServiceContract.put('customerNo', accountForCommunityContract.CustomerNo__c);
        requestDataRESTServiceContract.put('phone', '007');

        String requestJson = (String)JSON.serialize(requestDataRESTServiceContract);
        request.requestBody = Blob.valueOf(requestJson);

        System.debug('RESTServiceTest - testRESTServiceContractFromExistingCommunityContractPersonAccount() Incoming JSON: ' + requestJson);

        // Set REST context
        RestContext.request  = request;

        // Insert contract
        DiaRESTResponse response = RESTServiceContract.handlePost();
        Test.stopTest();

        System.debug('RESTServiceTest - testRESTServiceContractFromExistingCommunityContractPersonAccount() Response: ' + response);
        System.assertEquals('OK', response.getStatus(), 'RESTServiceTest - testRESTServiceContractFromExistingCommunityContractPersonAccount() Expected status OK ' + response);

        // Expect a new Energy Contract under Account
        Contract newEnergyContract = [SELECT Id, RecordType.DeveloperName FROM Contract WHERE CommunityContract__c = :communityContract.Id AND AccountId = :accountForCommunityContract.Id];
        System.assertEquals('SonnenFlat', newEnergyContract.RecordType.DeveloperName, 'Expect new Contract to be of type "SonnenFlat"');

        // Expect a change in the Contact's Phone
        List<Contact> accountContacts = [SELECT Id, Phone FROM Contact WHERE AccountId = :accountForCommunityContract.Id];
        System.assertEquals(1, accountContacts.size(), 'Expect only one Contact');
        System.assertEquals(requestDataRESTServiceContract.get('phone'), accountContacts.get(0).Phone, 'Expect change in Contact\'s LastName');
    }

    /**
     * Test RESTServiceContractPartner GET
     */
    @isTest static void testRESTServiceContractPartnerGet() {

        String DEBUG_HERE = 'RESTServiceTest - testRESTServiceContractPartnerGet() ';

        setupStatic();

        Account oAccount = new Account(
            Name = 'Partner',
            Status__c = 'active',
            RecordTypeId = recordTypeDeveloperNameToId.get('Account').get('sbc')
        );
        insert oAccount;

        Test.startTest();

        RestRequest oRequest = new RestRequest();
        oRequest.requestURI = '/contract/partner/';
        oRequest.addParameter('token', RESTService.ACCESS_TOKEN);
        oRequest.httpMethod = 'GET';

        // Set REST context
        RestContext.request  = oRequest;
        DiaRESTResponse oResponse = RESTServiceContractPartner.handleGet();

        Test.stopTest();

        System.debug(DEBUG_HERE + 'Response: ' + oResponse);
    }

    /**
     * Tests the language mapping
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-1076
     */
    @isTest static void testRESTServiceContractLanguageISOCodeMapping() {

        String languageISOCode;
        String countryISOCode;

        // Default "en"
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('en', languageISOCode);

        countryISOCode = 'SE';
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('en', languageISOCode);

        // Force language
        languageISOCode = 'es';
        countryISOCode = 'AT';
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('es', languageISOCode);

        // DACH region
        languageISOCode = '';
        countryISOCode = 'DE';
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('de', languageISOCode);

        languageISOCode = '';
        countryISOCode = 'CH';
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('de', languageISOCode);

        languageISOCode = '';
        countryISOCode = 'AT';
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('de', languageISOCode);

        // "it" if Italia (IT)
        languageISOCode = '';
        countryISOCode = 'IT';
        languageISOCode = RESTServiceContract.determineLanguageISOCodeFromCountryISOCode(languageISOCode, countryISOCode);
        System.assertEquals('it', languageISOCode);
    }
}