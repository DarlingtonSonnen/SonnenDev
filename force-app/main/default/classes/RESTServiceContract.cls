@RestResource(urlMapping='/contract/*')

/**
 * REST Service for creating community and energy contracts
 * 
 * External testing via http://sonnenbatterie-dev.interapps.de/tests/contract/LumenazaContractRESTServiceTest.php
 * (Credentials: standard dia or see https://dia.my.salesforce.com/a0757000013gG5S)
 *
 * Apex Unit Testing via class RESTServiceTest.
 * 
 * Changelog:
 *
 * v1.16.2 (2018-01-22, marko@die-interaktiven.de)
 * - BankData was previously created only if Community Contract was created.
 *   This was an outdated behaviour as most of the Contracts now do not need a
 *   Community Contract anymore (SOBCRM-1137)
 *
 * v1.16.1 (2017-11-27, marko@die-interaktiven.de)
 * - Set italian identificationNumber on Account regardless if it's a business
 *   account or not (SOBCRM-1121)
 *
 * v1.16.0 (2017-11-23, marko@die-interaktiven.de)
 * - Added "termsOfServiceDiscovergyConfirmed" for sonnenStrom (SOBCRM-1098)
 *
 * v1.15.0 (2017-11-09, marko@die-interaktiven.de)
 * - Added "tariffVersion" for Sonnenflat 2.0 (SOBCRM-1093)
 *
 * v1.14.0 (2017-10-06, marko@die-interaktiven.de)
 * - Added setting of Contact.Language__c/Account.Language__pc (SOBCRM-1076)
 *
 * v1.13.0 (2017-09-21, marko@die-interaktiven.de)
 * - Added new fields for sonnenStrom "solar" (SOBCRM-1042)
 *
 * v1.12.0 (2017-06-16, marko@die-interaktiven.de)
 * - Added "billingStateProvince", "shippingStateProvince" which were missing for
 *   italian Contracts (communityWithFlatOption) (SOBCRM-825)
 * - Added fields and hanlding for contractType "sonnenStrom" (SOBCRM-984)
 *
 * v1.11.0 (2017-04-11, marko@die-interaktiven.de)
 * - Finalized CommunitWithFlatOption Contract creation (SOBCRM-825)
 *   Those Contracts are internally handled like Community Contracts but
 *   can hold information like Energy Contracts (without attachments):
 *      - Mapped identificationNumber__c to Account.IdentificationNumber__c
 *      - Added PowerOfMeter__c and IsOptInEdison__c for Community Contracts
 *      - Contracts are not activated automatically
 *      - Tested by RESTServiceTest.testRESTServiceContractCommunityWithFlatOption
 *
 * v1.10.0 (2017-03-29, marko@die-interaktiven.de)
 * - New fields for Austria (SOBCRM-897):
 *      - isNewRegistration
 *      - feelingInWanted
 *      - birthday
 *
 * v1.9.2 (2017-03-27, marko@die-interaktiven.de)
 * - Field "type" is NOT mandatory
 *
 * v1.9.1 (2017-03-24, marko@die-interaktiven.de)
 * - Field "type" is now mandatory
 *
 * v1.9.0 (2017-03-23, dino.ursic@die-interaktiven.de)
 * - SOBCRM-825 - Extending the API to support "Community Contract with Flat Option" for IT (i.e. Contracts with
 * 	'CommunityWithFlatOption' Record Type, and Type__c 'sonnenBatterieHome-IT')
 *
 * v1.8.1 (2017-02-06)
 * - SOBCRM-807 - After new Type picklist introduced in SOBCRM-800, Automatic activation of Community Contracts
 *   is allowed for all Types except 'sonnenbatterieCity-DE'; Contracts with 'sonnenbatterieCity-DE' will get
 *   activated only when the battery is installed at Customer's site
 *
 * v1.8.0 (2017-01-26)
 * - SOBCRM-800 - New picklist Type__c with values 'standard' and 'sonnenBatterieCity' required for Contracts
 *   with 'Community' or 'SonnenFlat' Record Type
 *
 * v1.7.0 (2017-01-26)
 * - SOBCRM-802 - Details of the created Account/Contact should be included in the response
 *
 * v1.6.1 (2016-12-23)
 * - Fix: BankData must be created AFTER Community Contract has been activated because SepaReference can only
 *        be created from Account.CustomerNoDatev__c is a Contract is activated
 * - Fix: Also relate Energy Contact to new created BankData
 *
 * v1.6.0 (2016-12-12)
 * - SOBCRM-733 - Bank Data for new Contracts should be stored to BankData__c instead of directly on the Contract.
 *   The Contract should contain a Lookup to the BankData. BankData should be linked to the Contract's Account.
 * - Added new Contract 'factory' method createCommunityContractWithBankDataFromContract() which creates Contract
 *   as well as inserts a BankData record. The BankData.SepaReference field will be filled via trigger, due to
 *   complex logic, unachievable in the REST class - SepaRef = Account.CustomerNoDatev + ACC_BANKDATAs_COUNT
 *   E.g. for an Account with existing related two BankData records, the SepaRef would end with ...0003
 * - Moved insert DML operation for new Contracts from the createCommunityContra..() 'factory' methods to after
 *   where the methods are invoked, in order to have overview of both insert and update DMLs at one place.
 *
 * v1.5.0 (2016-10-21)
 * - Added handling of new Contract type "sonnenFlat" with capability of adding
 *   attachments to the Contract
 * - Moved authentication to RESTService class
 * - Changed some constant names
 *
 * v1.4.1 (2016-10-17)
 * - Fix: createCommunityContractFromContract() didn't copy field BonusProgram__c
 *
 * v1.4.0 (2016-09-22)
 * - Added _skipLumenaza to skip Lumenaza call
 *
 * v1.3.0 (2016-08-24)
 * - Added querying an existing Community Contract (GET) (SOBCRM-159)
 * - Creation of an Energy Contract on basis of an existing Community Contract (SOBCRM-159)
 * 
 * v1.2.0 (2016-05-11)
 * - Creation of an Account-Contact if "isBusiness" is set (SOBCRM-181)
 * - Added address data to Account (SOBCRM-181)
 * 
 * v1.1.0 (2016-03-30)
 * - Added new fields "vatId" and "billingCountry" (SOBCRM-221) 
 * 
 * v1.0.0 
 * - Initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @see https://interaktiv.jira.com/wiki/pages/viewpage.action?pageId=167122163
 * @see RESTServiceTest
 * @version 1.16.2 (2018-01-22)
 */
global with sharing class RESTServiceContract {

    public static final Double MAX_ATTACHMENT_SIZE_MB = 10;
    public static final String OBJECT_NAME = 'Contract';

    public static final String CONTRACT_TYPE_COMMUNITY         = 'community';
    public static final String CONTRACT_TYPE_ENERGY            = 'energy';
    public static final String CONTRACT_TYPE_FLAT              = 'sonnenFlat';
    public static final String CONTRACT_TYPE_COMMUNITY_FLAT_IT = 'communityWithFlatOption';
    public static final String CONTRACT_TYPE_SONNEN_STROM      = 'sonnenStrom';

    public static final Set<String> VALID_CONTRACT_TYPES = new Set<String>{
        CONTRACT_TYPE_COMMUNITY, CONTRACT_TYPE_ENERGY, CONTRACT_TYPE_FLAT,
        CONTRACT_TYPE_COMMUNITY_FLAT_IT, CONTRACT_TYPE_SONNEN_STROM
    };

    public static List<Map<String,String>> attachmentsForUnitTest;

    private static final Map<String,String> mapping = new Map<String,String>{
        'isBusiness'              => '', // Set via Account record type later
        'contractType'            => '',        // community|energy|sonnenFlat|communityWithFlatOption|sonnenStrom
        'type'                    => 'Type__c', // sonnenbatterieCity-DE|sonnenbatterieHome-DE|sonnenbatterieHome-AT|sonnenbatterieHome-IT|start|solar|plus
        'company'                 => 'ContractingPartyAccountName__c',
        'salutation'              => 'ContractingPartySalutation__c',
        'academicTitle'           => 'ContractingPartyAcademicTitle__c',
        'firstName'               => 'ContractingPartnerFirstname__c',
        'lastName'                => 'ContractingPartnerLastname__c',
        'phone'                   => 'ContractingPartyPhone__c',
        'email'                   => 'ContractingPartyEmail__c',
        'birthday'                => 'ContractingPartyBirthday__c',
        'shippingStreet'          => 'ShippingStreet__c',
        'shippingStreetNo'        => 'ShippingStreetNumber__c',
        'shippingZip'             => 'ShippingPostalCode__c',
        'shippingCity'            => 'ShippingCity__c',
        'billingStreet'           => 'BillingStreet__c',
        'billingStreetNo'         => 'BillingStreetNumber__c',
        'billingZip'              => 'BillingPostalCode__c',
        'billingCity'             => 'BillingCity__c',
        'billingCountry'          => 'BillingCountry__c', // (DE|AT|IT) // SOBCRM-825 - 'IT' value allowed
        'vatId'                   => 'VatId__c', // (mandatory wenn Country != DE und Company)
        'deliveryStartDate'       => 'DeliveryStart__c',
        'subscriptionReason'      => 'SubscriptionReason__c',
        'meterId'                 => 'MeterId__c',
        'meteringPointId'         => 'MeterpointId__c',
        'previousProvider'        => 'PreviousProvider__c',
        'annualConsumption'       => 'AnnualConsumption__c',
        'bankAccountFirstName'    => 'BankDataFirstname__c',
        'bankAccountLastName'     => 'BankDataLastname__c',
        'bankIbanNo'              => 'BankDataIBAN__c',
        'sepaDate'                => 'SEPADate__c',
        'rateType'                => 'TariffType__c', // household|heatpump|sonnenFlat|sonnenCity|sonnenStrom
        'withdrawalConfirmed'     => 'WithdrawalConfirmed__c',
        'termsOfServiceConfirmed' => 'TermsOfServiceConfirmed__c',
        'bonusProgram'            => 'BonusProgram__c', // since 2016-03-30
        'batterySerialNumber'     => 'BatterySerialNumber__c', // since 2016-05-10 (SOBCRM-250)
        'bankSwift'               => 'BankDataSWIFT__c', // since 2016-06-07 (SOBCRM-296)
        '_skipLumenaza'           => 'LumenazaSkipApiCall__c', // since 2016-09-22

        // language Code (SOBCRM-1076, 2017-10-06, MSB)
        'languageISOCode'         => '', // mapped manually to Contact.Language__c/Account.Language__pc

        // For "sonnenFlat" (since 2016-10-20)
        // For "sonnenCity" (since 2017-03-24)
        // https://interaktiv.jira.com/browse/SOBCRM-678
        'amountOfFreeEnergy'      => 'AmountOfFreeEnergy__c', // 4250 | 5500
        'annualConsumptionTotal'  => 'AnnualConsumptionTotal__c',
        'installer'               => 'Installer__c', // Account of type "Partner"
        'isInstallerUnknown'      => 'IsInstallerUnknown__c',
        'otherInstaller'          => 'OtherInstaller__c',
        'previousProviderName'    => 'PreviousProviderName__c',
        'termsAndConditions'      => 'TermsAndConditions__c', // Version of Terms and Conditions
        'externalOrderId'         => 'ExternalOrderId__c', // Mainly to be able to fetch attachments via https://dev-sonnen.cs86.force.com/services/apexrest/contract/<External Order ID>/attachment/?token=<Token>
        
        // For "CommunityWithFlatOption" (SOBCRM-825, 2017-03-23)
        'identificationNumber'    => '', // mapped manually to Account.IdentificationNumber__c
        'optInEdison'			  => 'IsOptInEdison__c',
        'powerOfMeter'			  => 'PowerOfMeter__c',
        'billingStateProvince'    => 'BillingStateProvince__c',
        'shippingStateProvince'   => 'ShippingStateProvince__c',

        // Attachment will be handled separately
        'attachment1Name'         => '',
        'attachment1URL'          => '',
        'attachment2Name'         => '',
        'attachment2URL'          => '',

        // Especially for Austria
        'isNewRegistration'       => 'IsNewRegistration__c',
        'feedingInWanted'         => 'IsFeedingInWanted__c',

        // For "sonnenStrom" (since 2017-06-14)
        // https://interaktiv.jira.com/browse/SOBCRM-984
        'appointedEnergyRate'     => 'AppointedEnergyRate__c',
        'communityFee'            => 'CommunityFee__c',
        'confirmedDeliveryStart'  => 'ConfirmedDeliveryStart__c',
        'powerPVPlant'            => 'PowerPvPlant__c',
        'pvInstallationDate'      => 'PvPlantInstallationDate__c',
        // additionally for type "solar" (since 2017-09-21)
        // https://interaktiv.jira.com/browse/SOBCRM-1042
        'optionalHardware'        => 'OptionalHardware__c',
        // set to object MeterInstallation__c
        'mi_meteringConcept'      => '',
        'mi_productionMeterId'    => '',
        'mi_meterOperator'        => '',
        'mi_gatewayType'          => '',
        // Discovergy Terms (since 2017-11-23)
        // https://interaktiv.jira.com/browse/SOBCRM-1098
        'termsOfServiceDiscovergyConfirmed' => 'TermsOfServiceDiscovergyConfirmed__c',

        // Sonnenflat 2.0 (since 2017-11-09)
        // https://interaktiv.jira.com/browse/SOBCRM-1093
        // https://interaktiv.jira.com/browse/SOBCRM-1088
        'tariffVersion'           => 'Tariff_Version__c'
    };

    /**
     * Callout: Save URL as attachment on a Contract
     */
    @future(callout=true)
    global static void saveURLAsAttachment(String attachmentName, String attachmentURL, Id contractId) {

        String DEBUG_HEADER = 'RESTServiceContract::saveURLAsAttachment() - ';

        // Set mock in test mode
        if (Test.isRunningTest() == true) {
            Test.setMock(HttpCalloutMock.class, new RESTServiceContract.AttachmentLoaderMockDispatcher());
        }

        attachmentURL = attachmentURL.replace(' ', '%20');

        HttpRequest request = new HttpRequest();
        request.setEndpoint(attachmentURL);
        request.setMethod('GET');
        //request.setHeader('Content-Type', 'image/jpeg');
        //request.setCompressed(true);
        request.setTimeout(6000);

        Http http = new Http();

        System.debug(DEBUG_HEADER + 'Calling ' + attachmentURL);

        try {
            HttpResponse response = http.send(request);
            Blob attachmentBlob = response.getBodyAsBlob();

            System.debug(DEBUG_HEADER + 'Response: ' + response);
            System.debug(DEBUG_HEADER + 'Attachment size: ' + attachmentBlob.size());

            if (attachmentBlob != NULL) {
                Attachment attachment = new Attachment(
                    Name        = attachmentName,
                    Body        = attachmentBlob,
                    ParentId    = contractId,
                    Description = 'Source-URL: ' + attachmentURL
                );
                insert attachment;

                System.debug(DEBUG_HEADER + 'Insert Attachment: ' + attachment);
            }
        }
        catch (Exception e) {

            System.debug(DEBUG_HEADER + 'Exception: ' + e);

            Case errorCase = new Case();
            errorCase.Subject = 'Error on downloading attachment';
            errorCase.Description  = e.getMessage() + (e.getCause() != NULL ? ' ' + e.getCause() : '')  + (e.getLineNumber() > 0 ? ' in line #' + e.getLineNumber() : '') + '\n\n';
            errorCase.Description += 'Attachment Name: ' + attachmentName + '\n';
            errorCase.Description += 'Attachment URL: ' + attachmentURL + '\n';
            errorCase.Description += 'Contract ID: ' + contractId + '\n';
            insert errorCase;
        }
    }

    /**
     * Handle POST
     *
     * Contract creation
     */
    @HttpPost
    global static DiaRESTResponse handlePost() {

        String DEBUG_HEADER = 'RESTServiceContract::handlePost() - ';

        System.debug(DEBUG_HEADER + 'Entering');

        DiaRESTResponse response = new DiaRESTResponse(OBJECT_NAME);
        RestRequest request = RestContext.request;

        // POST data
        // Expects the data to be of content-type application/json!
        Blob body = request.requestBody;
        String dataAsJson = body.toString();

        SavePoint eineSchritteSuruck = Database.setSavepoint();

        while (true) {

            if (!RESTService.isAuthenticated(response)) {
                break;
            }

            try {

                Map<String,String> requestData = (Map<String,String>)JSON.deserialize(dataAsJson, Map<String,String>.class);
                response.addDebug('Request data: ' + requestData);

                String contractType = requestData.get('contractType');
                String isBusiness   = requestData.get('isBusiness');

                // Mandatory contractType
                // community: create a community contract
                // energy: create community (if not existing yet) AND Lumenaza contract
                if (!VALID_CONTRACT_TYPES.contains(contractType)) {
                    response.setError('Feld "contractType" muss einem der folgenden Werte entsprechen: ' + String.join(new List<String>(VALID_CONTRACT_TYPES), ',') , 'INVALID_CONTRACT_TYPE');
                    break;
                }

                // Must be available if customer already has a community contract
                Contract existingCommunityContract;

                String communityContractNo  = getNullOrString(requestData.get('communityContractNo'));
                String customerNo           = getNullOrString(requestData.get('customerNo'));
                String identificationNumber = getNullOrString(requestData.get('identificationNumber'));
                String languageISOCode      = getNullOrString(requestData.get('languageISOCode'));

                requestData.remove('communityContractNo');
                requestData.remove('customerNo');
                requestData.remove('identificationNumber');
                requestData.remove('languageISOCode');

                // Community Contracts cannot be created by existing Contract Number ...
                if (contractType == CONTRACT_TYPE_COMMUNITY || contractType == CONTRACT_TYPE_COMMUNITY_FLAT_IT) {
                    if (communityContractNo != NULL) {
                        response.setError('Community-Vertrag kann nicht mit bestehender Vertragsnummer abgeschlossen werden', 'CANNOT_CREATE_COMMUNITY_CONTRACT_FROM_EXISTING');
                        break;
                    }
                }
                // ... while others can
                else if (communityContractNo != NULL || customerNo != NULL) {

                    if (contractType == CONTRACT_TYPE_SONNEN_STROM) {
                        response.setError('SonnenStrom-Verträge können nicht aufgrund von bestehenden Community-Verträgen abgeschlossen werden', 'CANNOT_CREATE_SONNENSTROM_CONTRACT_FROM_EXISTING');
                        break;
                    }

                    existingCommunityContract = getCommunityContract(communityContractNo, customerNo, response);

                    if (response.hasError()) {
                        break;
                    }
                }

                // Check if Community Contract has already a related Energy Contract
                if (existingCommunityContract != NULL) {

                    List<Contract> relatedEnergyContracts = new List<Contract>([SELECT Id FROM Contract WHERE CommunityContract__c = :existingCommunityContract.Id]);
                    if (!relatedEnergyContracts.isEmpty()) {
                        response.setError('Zu diesem Community-Vertrag wurde schon ein Strom-Vertrag abgeschlossen' , 'COMMUNITY_CONTRACT_HAS_ENERGY_CONTRACT');
                        break;
                    }

                    response.addDebug('Found existing Community Contract: ' + existingCommunityContract);
                }

                if (isBusiness == NULL) {
                    response.setError('Feld "isBusiness" muss explizit gesetzt sein', 'FIELD_ISBUSINESS_MANDATORY');
                    break;
                }

                Boolean isBusinessAccount = (isBusiness == 'true');

                response.addDebug('Requested Contract type (RecordType): ' + contractType);

                // Map incoming fields data on contract fields
                //SObject contract = Schema.getGlobalDescribe().get(OBJECT_NAME).newSObject() ;
                Map<String,String> contractValues = new Map<String,String>();
                Boolean hasError = false;

                for (String field : requestData.keySet()) {

                    String mappedContractField = mapping.get(field);

                    if (mappedContractField == NULL) {
                        response.setError('Ungültiges Feld "' + field + '"', 'INVALID_FIELD');
                        hasError = true;
                        break;
                    }
                    else if (mappedContractField.length() > 0) {
                        contractValues.put(mappedContractField, requestData.get(field));
                    }
                }
                if (hasError == true) {
                    break;
                }

                // Create contract from value map
                Contract contract = (Contract)JSON.deserialize(JSON.serialize(contractValues), Type.forName(OBJECT_NAME));

                response.addDebug('Requested type (Type__c): ' + contract.Type__c);
                response.addDebug('Requested tariff type (TariffType__c): ' + contract.TariffType__c);

                // Init record types
                Map<String,Map<String,String>> recordTypes = getRecordTypes();

                String recordTypeDeveloperName = (isBusinessAccount == true) ? 'businessaccount' : 'private';
                String accountRecordTypeId = recordTypes.get('Account').get(recordTypeDeveloperName);

                String contractRecordTypeIdEnergy               = recordTypes.get('Contract').get(CONTRACT_TYPE_ENERGY.toLowerCase());
                String contractRecordTypeIdCommunity            = recordTypes.get('Contract').get(CONTRACT_TYPE_COMMUNITY.toLowerCase());
                String contractRecordTypeIdFlat                 = recordTypes.get('Contract').get(CONTRACT_TYPE_FLAT.toLowerCase());
                String contractRecordTypeIdCommunityWithFlatIT  = recordTypes.get('Contract').get(CONTRACT_TYPE_COMMUNITY_FLAT_IT.toLowerCase());
                String contractRecordTypeIdSonnenStrom          = recordTypes.get('Contract').get(CONTRACT_TYPE_SONNEN_STROM.toLowerCase());

                if (contractRecordTypeIdEnergy == NULL) {
                    response.setError('Record type für Vertragsart "' + CONTRACT_TYPE_ENERGY + '" konnte nicht ermittelt werden', 'INTERNAL_ERROR');
                    break;
                }
                if (contractRecordTypeIdFlat == NULL) {
                    response.setError('Record type für Vertragsart "' + CONTRACT_TYPE_FLAT + '" konnte nicht ermittelt werden', 'INTERNAL_ERROR');
                    break;
                }
                if (contractRecordTypeIdCommunity == NULL) {
                    response.setError('Record type für Vertragsart "' + CONTRACT_TYPE_COMMUNITY + '" konnte nicht ermittelt werden', 'INTERNAL_ERROR');
                    break;
                }
                if (contractRecordTypeIdCommunityWithFlatIT == NULL) {
                    response.setError('Record type für Vertragsart "' + CONTRACT_TYPE_COMMUNITY_FLAT_IT + '" konnte nicht ermittelt werden', 'INTERNAL_ERROR');
                    break;
                }
                if (contractRecordTypeIdSonnenStrom == NULL) {
                    response.setError('Record type für Vertragsart "' + CONTRACT_TYPE_SONNEN_STROM + '" konnte nicht ermittelt werden', 'INTERNAL_ERROR');
                    break;
                }
                if (accountRecordTypeId == NULL) {
                    response.setError('Record type für "' + recordTypeDeveloperName + '" konnte nicht ermittelt werden', 'INTERNAL_ERROR');
                    break;
                }

                // Set language if not given according to country
                languageISOCode = determineLanguageISOCodeFromCountryISOCode(languageISOCode, contract.BillingCountry__c);

                // If a Community Contract exists
                if (existingCommunityContract != NULL) {

                    if (existingCommunityContract.AccountId == NULL) {
                        response.setError('Account erwartet', 'INTERNAL_ERROR');
                        break;
                    }

                    // If Person Account than set data
                    if (existingCommunityContract.Account.RecordType.IsPersonType) {

                        Account account = new Account(Id = existingCommunityContract.AccountId);
                        account = setAccountFromContract(account, contract, FALSE, identificationNumber, languageISOCode);

                        update account;
                        response.addDebug('Updated existing Person Account: ' + account);

                        // Relate Account to Contract
                        contract.AccountId = account.Id;

                        // Contact available
                        contract.CustomerSignedId = existingCommunityContract.Account.PersonContactId;
                    }
                    // If Business Account
                    else {

                        Contact contact = new Contact();
                        contact = setContactFromContract(contact, contract, languageISOCode);

                        // Search Contact by Contract values set
                        List<Contact> foundContacts = [
                            SELECT Id, LastName
                            FROM Contact
                            WHERE
                                AccountId         = :existingCommunityContract.AccountId AND
                                FirstName         = :contact.FirstName AND
                                LastName          = :contact.LastName AND
                                MailingStreet     = :contact.MailingStreet AND
                                MailingPostalCode = :contact.MailingPostalCode
                            ORDER BY CreatedDate DESC
                            LIMIT 1
                        ];

                        // If found update Contact
                        if (!foundContacts.isEmpty()) {

                            Contact foundContact = foundContacts.get(0);

                            contact.Id = foundContact.Id;
                            update contact;
                            response.addDebug('Updated matching Contact for Account ' + existingCommunityContract.AccountId + ': ' + contact);
                        }
                        // Else create NEW Contact
                        else {
                            contact.AccountId = existingCommunityContract.AccountId;
                            insert contact;
                            response.addDebug('Inserted new Contact: ' + contact);
                        }

                        // Relate Account to Contract
                        contract.AccountId = existingCommunityContract.AccountId;

                        // Contact available
                        contract.CustomerSignedId = contact.Id;
                    }
                }
                // Else create an Account and eventually a Contact
                else {

                    response.addDebug('Take Account record type: ' + accountRecordTypeId + ' (' + recordTypeDeveloperName + ')');

                    AccountContactWrapper accountContactWrapper = createAccountFromContract(contract, Id.valueOf(accountRecordTypeId), isBusinessAccount, identificationNumber, languageISOCode);

                    Account account = AccountContactWrapper.account;
                    Contact contact = AccountContactWrapper.contact; // Only available if business account, otherwise Account is a PersonAccount

                    response.addDebug('Created Account: ' + account);

                    // Relate Account to Contract
                    contract.AccountId = account.Id;

                    // Contact available
                    contract.CustomerSignedId = isBusinessAccount ? contact.Id : accountContactWrapper.personContactId;
                }

                // Set general fields
                contract.Status    = 'Draft'; // Require on insert!
                contract.StartDate = System.today();

                // If contract has no shipping then copy from billing
                if (contract.ShippingStreet__c == NULL || contract.ShippingStreet__c.length() == 0) {
                    contract.ShippingStreet__c       = contract.BillingStreet__c;
                    contract.ShippingStreetNumber__c = contract.BillingStreetNumber__c;
                    contract.ShippingPostalCode__c   = contract.BillingPostalCode__c;
                    contract.ShippingCity__c         = contract.BillingCity__c;
                }

                // Create BankData and related it to the Contracts
                // (moved here due to https://interaktiv.jira.com/browse/SOBCRM-1137)
                BankData__c bankData = new BankData__c(
                    Account__c       = contract.AccountId,
                    FirstName__c     = contract.BankDataFirstname__c,
                    LastName__c      = contract.BankDataLastname__c,
                    SWIFT__c         = contract.BankDataSWIFT__c,
                    IBAN__c          = contract.BankDataIBAN__c,
                    SepaDate__c      = contract.SEPADate__c
                );
                insert bankData;
                // Relate it to the contract
                contract.BankData__c = bankData.Id;

                Contract communityContract;

                // Community contract is created if
                // - RecordType not "sonnenStrom" AND
                // - RecordType is "CommunityWithFlatOption" OR there is no existing Community contract found
                if (contractType != CONTRACT_TYPE_SONNEN_STROM) {

                    if (existingCommunityContract == NULL || contractType == CONTRACT_TYPE_COMMUNITY_FLAT_IT) {

                        if (contractType == CONTRACT_TYPE_COMMUNITY_FLAT_IT) {
                            // Contracts of type CommunityWithFlatOption get all standard
                            // values of an energy Contract but are handled internally as
                            // Community Contracts!
                            communityContract = contract;
                            communityContract.RecordTypeId = contractRecordTypeIdCommunityWithFlatIT;
                        }
                        else {
                            // Create Community Contract
                            communityContract = createCommunityContractFromContract(contract, contractRecordTypeIdCommunity);
                        }

                        insert communityContract;

                        // SOBCRM-807 - Activate Community Contract only if Type is different than 'sonnenbatterieCity-DE'
                        if (!'sonnenbatterieCity-DE'.equalsIgnoreCase(contract.Type__c) &&
                            contractType != CONTRACT_TYPE_COMMUNITY_FLAT_IT) {
                            // Activate "community" Contract
                            communityContract.Status = 'Activated';
                            update communityContract;
                            response.addDebug('Created and activated Ccommunity Contract: ' + communityContract);
                        }
                        else {
                            response.addDebug('Created Community Contract but did not activated it: ' + communityContract);
                        }

                        // Add information of created Community Contract
                        response.setGenericObjects(new List<Contract>{communityContract});
                    }
                    // Else take existing Community Contract
                    else if (existingCommunityContract != NULL) {
                        communityContract = existingCommunityContract;
                    }
                } // end if (contractType != CONTRACT_TYPE_SONNEN_STROM)

                // Now treat contract as "energy" contract
                if (contractType == CONTRACT_TYPE_ENERGY || contractType == CONTRACT_TYPE_FLAT || contractType == CONTRACT_TYPE_SONNEN_STROM) {

                    // Relate to Community Contract
                    // (will not be set if
                    // - CONTRACT_TYPE_COMMUNITY_FLAT_IT
                    // - CONTRACT_TYPE_SONNEN_STROM)
                    if (communityContract != NULL) {
                        contract.CommunityContract__c = communityContract.Id;
                    }

                    if (contractType == CONTRACT_TYPE_ENERGY) {
                        contract.RecordTypeId = contractRecordTypeIdEnergy;
                    }
                    else if (contractType == CONTRACT_TYPE_FLAT) {
                        contract.RecordTypeId = contractRecordTypeIdFlat;
                    }
                    else if (contractType == CONTRACT_TYPE_SONNEN_STROM) {
                        contract.RecordTypeId = contractRecordTypeIdSonnenStrom;
                    }

                    insert contract;
                    
                    // SOBCRM-802, dino@die-interaktiven.de, 26.01.2017
                    // Markus: "Details of the created Account/Contact should be included in the response"
                    response.setGenericObjects(new List<Contract>{contract});

                    // Will be activated manually later!
                    // Activate "energy" Contract
                    // contract.Status = 'Activated';
                    // update contract;
                    response.addDebug('Created "' + contractType + '" Contract: ' + contract + ', must be activated manually');

                    if (contractType == CONTRACT_TYPE_SONNEN_STROM) {

                        if (contract.Type__c == 'solar') {

                            // Insert a new MeterInstallation__c (since 2017-09-21)
                            // https://interaktiv.jira.com/browse/SOBCRM-1042
                            MeterInstallation__c oMeterInstallation = new MeterInstallation__c(
                                Contract__c          = contract.Id,
                                Account__c           = contract.AccountId,
                                MeteringConcept__c   = requestData.get('mi_meteringConcept'),      // Picklist
                                ProductionMeterID__c = requestData.get('mi_productionMeterId'),    // Text(10)
                                MeterOperator__c     = requestData.get('mi_meterOperator'),        // Picklist
                                GatewayType__c       = requestData.get('mi_gatewayType'),          // Picklist
                                OptionalHardware__c  = requestData.get('optionalHardware')         // Text(255)
                            );

                            insert oMeterInstallation;

                            response.addDebug('Created new Meter Installation: ' + oMeterInstallation);
                        }
                    }
                    else if (contractType == CONTRACT_TYPE_FLAT) {

                        // Add attachments if available

                        // Attachments for sonnenFlat
                        List<Map<String,String>> attachments = getAttachmentsFromRequest(requestData);

                        if (!attachments.isEmpty()) {

                            attachmentsForUnitTest = new List<Map<String,String>>();

                            for (Map<String,String> attachment : attachments) {

                                Integer indexType = Integer.valueOf(attachment.get('index'));
                                String attachmentType;

                                if (indexType == 1) {
                                    attachmentType = 'INVOICE';
                                }
                                else if (indexType == 2) {
                                    attachmentType = 'PROOF';
                                }

                                String attachmentName = (attachmentType != NULL ? attachmentType + ' - ' : '') + attachment.get('name');

                                // Future Callout
                                // NOT in Test mode as this requires to run synchronously and by
                                // that we get the error "You have uncommitted work pending. Please
                                // commit or rollback before calling out" because there are DML
                                // operations before this call (insert of Contract)
                                if (!Test.isRunningTest()) {
                                    saveURLAsAttachment(attachmentName, attachment.get('url'), contract.Id);
                                }
                                else {
                                    attachmentsForUnitTest.add(new Map<String,String>{
                                        'name'       => attachmentName,
                                        'url'        => attachment.get('url'),
                                        'contractId' => contract.Id
                                    });
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception e) {
                response.setError(e.getTypeName() + ': ' + e.getMessage() + ' (' + e.getStackTraceString() + ')', 'INTERNAL_ERROR');
            }
            break;
        }

        if (response.hasError() == true) {
            Database.rollback(eineSchritteSuruck);
        }

        return response;
    }

    /**
     * Convert an attached file which is
     * base64 encoded to blob representation
     */
    private static Blob convertAttachmentToBlob(String attachmentBase64Encoded) {

        if (attachmentBase64Encoded == NULL || attachmentBase64Encoded == '') {
            return NULL;
        }

        Blob attachment = EncodingUtil.base64Decode(attachmentBase64Encoded);

        if (attachment.size() * 8 > MAX_ATTACHMENT_SIZE_MB * 1048576) {
            throw new RESTServiceContractException('Attachment size is too large (max. ' + MAX_ATTACHMENT_SIZE_MB + ' MB)');
        }

        return attachment;
    }

    /**
     * Returns NULL or value
     */
    private static String getNullOrString(String value) {
        return (value == NULL || value.length() == 0) ? NULL : value;
    }

    /**
     * Get attachments from requestData
     */
    private static List<Map<String,String>> getAttachmentsFromRequest(Map<String,String> requestData) {

        Integer maxAttachments = 5;
        List<Map<String,String>> listAttachment = new List<Map<String,String>>();

        for (Integer i=1; i<=maxAttachments; i++) {

            String key = 'attachment' + i + 'Name';
            String attachmentName = requestData.get(key);
            requestData.remove(key);

            key = 'attachment' + i + 'URL';
            String attachmentUrl = requestData.get(key);
            requestData.remove(key);

            String attachmentType = '';

            if (attachmentName != NULL && attachmentName.length() > 0 && attachmentURL != NULL && attachmentURL.length() > 0) {
                listAttachment.add(new Map<String,String>{
                    'name'  => attachmentName,
                    'url'   => attachmentURL,
                    'index' => String.valueOf(i)
                });
            }
        }

        return listAttachment;
    }

    /**
     * Returns a Community Contract by given
     * - Conract Number and
     * - Customer Number
     */
    private static Contract getCommunityContract(String communityContractNo, String customerNo, DiaRESTResponse response) {

        Contract existingCommunityContract;

        customerNo = customerNo == NULL ? '' : customerNo;
        communityContractNo = communityContractNo == NULL ? '' : communityContractNo;

        while (true) {

            if (communityContractNo.length() == 0 || customerNo.length() == 0) {
                response.setError('Bitte Community Vertragsnummer und Kundennummer angeben', 'SPECIFY_COMMUNITY_NO_AND_CUSTOMER_NO');
                break;
            }

            List<Contract> existingCommunityContracts;

            // Search existing Community Contract
            // Pad to 8 digits by zero (e.g. 1599 to 00001599)
            communityContractNo = communityContractNo.leftPad(8, '0');

            Pattern myPattern = Pattern.compile('^[0-9]{8}$');
            Matcher matches = myPattern.matcher(communityContractNo);

            if (!myPattern.matcher(communityContractNo).find()) {
                response.setError('Ungültige Vertragsnummer', 'INVALID_CONTRACT_NO');
                break;
            }

            // Search Community Contract and query all fields set in mapping
            Set<String> contractFields = new Set<String>{'Id', 'Status', 'AccountId', 'Account.PersonContactId', 'Account.CustomerNo__c', 'Account.RecordType.Developername', 'Account.RecordType.IsPersonType'};
                for (String externalField : mapping.keySet()) {
                    String contractField = mapping.get(externalField);
                    if (contractField != NULL && contractField.length() > 0) {
                        contractFields.add(contractField);
                    }
                }

            String soql = 'SELECT ' + String.join(new List<String>(contractFields), ', ') + ' FROM Contract WHERE ContractNumber = :communityContractNo AND RecordType.DeveloperName = \'Community\' LIMIT 1';
            existingCommunityContracts = Database.query(soql);

            if (existingCommunityContracts.isEmpty()) {
                response.setError('Der Community-Vertrag ' + communityContractNo + ' konnte nicht gefunden werden' , 'COMMUNITY_CONTRACT_NOT_FOUND');
                break;
            }

            existingCommunityContract = existingCommunityContracts.get(0);

            if (existingCommunityContract.Status != 'Activated') {
                existingCommunityContract = NULL;
                response.setError('Der Community-Vertrag ist nicht mehr aktiv' , 'COMMUNITY_IS_NOT_ACTIVE');
                break;
            }

            if (existingCommunityContract.Account.CustomerNo__c == NULL || existingCommunityContract.Account.CustomerNo__c != customerNo) {
                existingCommunityContract = NULL;
                response.setError('Ungültige Kundennummer für diesen Vertrag' , 'WRONG_CUSTOMER_NO_FOR_CONTRACT');
                break;
            }

            break;
        }

        return existingCommunityContract;
    }

    /**
     * handle GET
     *
     * Querying Contracts
     */
    @HttpGet
    global static DiaRESTResponse handleGet() {

        DiaRESTResponse response = new DiaRESTResponse(OBJECT_NAME);
        RestRequest request = RestContext.request;

        while (true) {

            if (!RESTService.isAuthenticated(response)) {
                break;
            }
                        
            // Must be available if customer already has a community contract                
            String communityContractNo = getNullOrString(request.params.get('communityContractNo'));
            String customerNo          = getNullOrString(request.params.get('customerNo'));

            Contract existingCommunityContract = getCommunityContract(communityContractNo, customerNo, response);
            
            if (existingCommunityContract == NULL) {
                break;
            }
                        
            // Converts object to a Map<String,String>
            response.setGenericObjects(new List<Contract>{existingCommunityContract});
            List<Map<String,String>> genericObjects = response.getGenericObjects();
            
            Map<String,String> mapInternalToExternal = new Map<String,String>();                
            for (String externalField : mapping.keySet()) {
                String internalField = mapping.get(externalField);
                internalField = internalField != NULL ? internalField : '';                    
                if (internalField.length() > 0) {
                    mapInternalToExternal.put(internalField, externalField);
                }
            }
            
            List<Map<String,String>> convertedObjects = new List<Map<String,String>>();
            for (Map<String,String> genericObject : genericObjects) {
                
                Map<String,String> newReversedGenericObject = new Map<String,String>();
                
                for (String fieldName : genericObject.keySet()) { 
                    String externalField = mapInternalToExternal.get(fieldName);
                    if (externalField != NULL) {
                        newReversedGenericObject.put(externalField, genericObject.get(fieldName));
                    }
                }   
                
                // Manually add isBusiness
                newReversedGenericObject.put('isBusiness', existingCommunityContract.Account.RecordType.IsPersonType ? 'false' : 'true');
                
                convertedObjects.add(newReversedGenericObject);
            }
            
            response.setGenericObjects(convertedObjects);             

            break;
        }
        
        return response;
    }

    /**
     * Determine the language ISO code if not given from country ISO code
     *
     * @since 2017-10-06
     * @see https://interaktiv.jira.com/browse/SOBCRM-1076
     * @see RESTServiceTest.testRESTServiceContractLanguageISOCodeMapping()
     */
    @testVisible
    private static String determineLanguageISOCodeFromCountryISOCode(String currentLanguageISOCode, String countryISOCode) {

        if (currentLanguageISOCode == NULL || currentLanguageISOCode == '') {

            // Default english
            currentLanguageISOCode = 'en';

            if (countryISOCode != NULL) {
                if ((new Set<String>{'DE','AT','CH'}).contains(countryISOCode)) {
                    currentLanguageISOCode = 'de';
                }
                else if (countryISOCode == 'IT') {
                    currentLanguageISOCode = 'it';
                }
            }
        }

        return currentLanguageISOCode;
    }
    
    /**
     * Creates a Community Contract from a Contract
     */
    private static Contract createCommunityContractFromContract(Contract contract, Id recordTypeId) {
        
        Contract communityContract = new Contract(
            RecordTypeId                     = recordTypeId,
            Type__c                          = contract.Type__c,
            CustomerSignedId                 = contract.CustomerSignedId,
            StartDate                        = contract.StartDate,
            Status                           = contract.Status,
            AccountId                        = contract.AccountId,       
            ContractingPartyAccountName__c   = contract.ContractingPartyAccountName__c,
            ContractingPartySalutation__c    = contract.ContractingPartySalutation__c,
            ContractingPartyAcademicTitle__c = contract.ContractingPartyAcademicTitle__c,
            ContractingPartnerFirstname__c   = contract.ContractingPartnerFirstname__c,
            ContractingPartnerLastname__c    = contract.ContractingPartnerLastname__c,
            ContractingPartyPhone__c         = contract.ContractingPartyPhone__c,
            ContractingPartyEmail__c         = contract.ContractingPartyEmail__c,
            ContractingPartyBirthday__c      = contract.ContractingPartyBirthday__c,
            BillingStreet__c                 = contract.BillingStreet__c,
            BillingStreetNumber__c           = contract.BillingStreetNumber__c,
            BillingPostalCode__c             = contract.BillingPostalCode__c,
            BillingCity__c                   = contract.BillingCity__c, 
            BillingCountry__c                = contract.BillingCountry__c,
            ShippingStreet__c                = contract.ShippingStreet__c,
            ShippingStreetNumber__c          = contract.ShippingStreetNumber__c,
            ShippingPostalCode__c            = contract.ShippingPostalCode__c,
            ShippingCity__c                  = contract.ShippingCity__c,
            BankData__c                      = contract.BankData__c,
            BankDataFirstname__c             = contract.BankDataFirstname__c,
            BankDataLastname__c              = contract.BankDataLastname__c,
            BankDataIBAN__c                  = contract.BankDataIBAN__c,
            BankDataSWIFT__c                 = contract.BankDataSWIFT__c,
            SEPADate__c                      = contract.SEPADate__c,
            VatId__c                         = contract.VatId__c,
            BatterySerialNumber__c           = contract.BatterySerialNumber__c,
            BonusProgram__c                  = contract.BonusProgram__c,
            ExternalOrderId__c               = contract.ExternalOrderId__c,
            AmountOfFreeEnergy__c			 = contract.AmountOfFreeEnergy__c
        );
        
        // SOBCRM-807 - Community Contract Start Data can match the (SonnenFlat) Contract creation date only
        // if the Contract Type is different than 'sonnenbatterieCity-DE'
        if ('sonnenbatterieCity-DE'.equalsIgnoreCase(contract.Type__c)) {
            communityContract.StartDate = null;
        }

        return communityContract;
    }
    
    /**
     * Create an Accoung and eventually a Contact from a Contract
     */
    private static AccountContactWrapper createAccountFromContract(Contract contract, Id recordTypeId, Boolean isBusinessAccount, String identificationNumber, String languageISOCode) {
        
        AccountContactWrapper wrapper = new AccountContactWrapper();
        
        Account account = new Account();
        account.RecordTypeId = recordTypeId;
        
        account = setAccountFromContract(account, contract, isBusinessAccount, identificationNumber, languageISOCode);
                
        insert account;    
        
        // Add contact with personal info to business account
        if (isBusinessAccount) {
            Contact contact = new Contact(AccountId = account.Id);            
            setContactFromContract(contact, contract, languageISOCode);
            insert contact;
            wrapper.contact = contact;
        }
        else {
            // PersonAccount
            // Get PersonContactId for account!
            wrapper.personContactId = [SELECT PersonContactId FROM Account WHERE Id = :account.Id].PersonContactId;
        }
        
        wrapper.account = account;
        
        return wrapper;
    }
    
    /**
     * Set most Account values by a Contract
     */
    private static Account setAccountFromContract(Account account, Contract contract, Boolean isBusinessAccount, String identificationNumber, String languageISOCode) {
    
        if (isBusinessAccount) {
            // Business Account
            account.Name = contract.ContractingPartyAccountName__c;
        }
        else {
            // Person Account
            account.Salutation        = contract.ContractingPartySalutation__c;
            account.AcademicTitle__pc = contract.ContractingPartyAcademicTitle__c;
            account.FirstName         = contract.ContractingPartnerFirstname__c;
            account.LastName          = contract.ContractingPartnerLastname__c;
            account.PersonEmail       = contract.ContractingPartyEmail__c;
            account.Phone             = contract.ContractingPartyPhone__c;
            account.Language__pc      = languageISOCode;

            account.PersonBirthdate          = contract.ContractingPartyBirthday__c;
            account.PersonMailingStreet      = (contract.BillingStreet__c + ' ' + contract.BillingStreetNumber__c).trim();
            account.PersonMailingPostalCode  = contract.BillingPostalCode__c;
            account.PersonMailingCity        = contract.BillingCity__c;
            account.PersonMailingCountryCode = contract.BillingCountry__c;
        }

        // Set italian identificationNumber regardless if business account or not
        // (MSB, 2017-11-27, SOBCRM-1121)
        account.IdentificationNumber__c = identificationNumber;

        // Put billing address on account
        account.BillingStreet      = (contract.BillingStreet__c + ' ' + contract.BillingStreetNumber__c).trim();
        account.BillingPostalCode  = contract.BillingPostalCode__c;
        account.BillingCity        = contract.BillingCity__c;
        account.BillingCountryCode = contract.BillingCountry__c; 
        
        return account;
    }
    
    /**
     * Set most Contact values by a Contract
     */
    private static Contact setContactFromContract(Contact contact, Contract contract, String languageISOCode) {
        
        contact.Salutation         = contract.ContractingPartySalutation__c;
        contact.AcademicTitle__c   = contract.ContractingPartyAcademicTitle__c;
        contact.FirstName          = contract.ContractingPartnerFirstname__c;
        contact.LastName           = contract.ContractingPartnerLastname__c;
        contact.MailingStreet      = (contract.BillingStreet__c + ' ' + contract.BillingStreetNumber__c).trim();
        contact.MailingPostalCode  = contract.BillingPostalCode__c;
        contact.MailingCity        = contract.BillingCity__c;
        contact.MailingCountryCode = contract.BillingCountry__c;
        contact.Email              = contract.ContractingPartyEmail__c;
        contact.Phone              = contract.ContractingPartyPhone__c;
        contact.Birthdate          = contract.ContractingPartyBirthday__c;
        contact.Language__c        = languageISOCode;
        return contact;
    }
    
    /**
     * Get all relevant RecordTypes
     */
    private static Map<String,Map<String,String>> getRecordTypes() {
        
        Map<String,Map<String,String>> recordTypeDeveloperNameToId = new Map<String,Map<String,String>>();
        List<RecordType> recordTypes = new List<RecordType>([SELECT Id, Name, DeveloperName, SObjectType FROM RecordType WHERE IsActive = true AND (SObjectType = 'Contract' OR SObjectType = 'Account')]);                
        
        for (RecordType recordType : recordTypes) {                   
            if (recordTypeDeveloperNameToId.get(recordType.SObjectType) == NULL) {
                recordTypeDeveloperNameToId.put(recordType.SObjectType, new Map<String,String>());
            }                    
            recordTypeDeveloperNameToId.get(recordType.SObjectType).put(recordType.DeveloperName.toLowerCase(), recordType.Id);
        }        
                
        return recordTypeDeveloperNameToId;
    }
    
    /**
     * Class AccountContactWrapper
     */
    private class AccountContactWrapper {
        public Account account;
        public Contact contact;
        public Id personContactId;
    }

    /**
     * Mock class for callout method saveURLAsAttachment()
     *
     * @see saveURLAsAttachment()
     */
    public class AttachmentLoaderMockDispatcher implements HttpCalloutMock {

        public final String responseBody = 'Filecontent :P';

        /**
         * Implemented method from interface as route dispatcher
         */
        public HttpResponse respond(HttpRequest request) {

            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/pdf');

            response.setBody(responseBody);
            response.setStatusCode(200);

            return response;
        }

        public String getResponseBody() {
            return this.responseBody;
        }
    }

    public class RESTServiceContractException extends Exception {}
}