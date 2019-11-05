/**
 * EnergestSynchronizerTest
 *
 * v1.0.0   2019-03-04  Marko Schmalenbach          Initial
 * v1.1.0   2019-03-08  Marko Schmalenbach          fetchAndProcessContractPods():
 *                                                  - set minPodStartDate
 *                                                  - Test partial upserts
 * v1.2.0   2019-08-19  Marko Schmalenbach          Added Duplicate Rule Test
 *
 * @see EnergestSynchronizer
 * @see https://interaktiv.jira.com/browse/SOBCRM-1321
 */
@IsTest
private class EnergestSynchronizerTest {

    private static final String DEBUG_HEADER = 'EnergestSynchronizerTest.';

    @TestSetup
    static void setup() {

        EnergestApi.mapSettings = new Map<String, GeneralSetting__mdt>{

            'EnergestApiHost' => new GeneralSetting__mdt(
                TextValue__c = 'http://www.test.de'
            ),
            'EnergestApiSecret' => new GeneralSetting__mdt(
                TextValue__c = '123456abc'
            ),
            'EnergestResellerId' => new GeneralSetting__mdt(
                TextValue__c = '987654'
            )
        };
    }

    @IsTest
    static void fetchAndProcessContractPods() {

        final String DEBUG_HERE = DEBUG_HEADER + 'fetchContractPods() - ';

        final String sPod1InternalId = '1';
        final String sPod2InternalId = '2';
        final String sPod3InternalId = '3';
        final String sPod4InternalId = '4';

        // Account for fuzzy search
        // Fuzzy is not really that fuzzy ...
        // So though if Rule is FirstName:fuzzy and LastName:fuzzy
        // changing both of them only in ONE letter will result into
        // a non-match (even if email and code match exact)
        // Matching Rule "EnergestCustomer"
        // (Person Account: EnergestCustomerID EXACT MatchBlank = FALSE)
        // OR
        // (
        //     (Person Account: FirstName FUZZY: FIRST NAME MatchBlank = FALSE) AND (Person Account: LastNameFUZZY: LAST NAME MatchBlank = FALSE)
        //     AND
        //     (
        //         (Person Account: PersonEmail EXACT MatchBlank = FALSE) OR (Person Account: BillingPostalCode EXACT MatchBlank = FALSE)
        //     )
        // )
        Account oAccountForDuplicateFuzzySearch = new Account(
            FirstName = 'Rudi',
            LastName = 'Mento',
            PersonEmail = '',
            BillingPostalCode = '7384',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId()
        );

        String sJson = '[{\n' +
            '"Voltage" : 400.00,\n' +
            '"UpdatedDate" : "2018-12-03T00:00:00.000Z",\n' +
            '"Type" : 1,\n' +
            '"TransportOption" : "TDR",\n' +
            '"SupplyPostalCode" : "00012",\n' +
            '"SupplyPlace" : null,\n' +
            '"SupplyMunicipalityICode" : "12058047",\n' +
            '"SupplyMunicipality" : "GUIDONIA MONTECELIO",\n' +
            '"SupplyHouseNumber" : "7",\n' +
            '"SupplyDistrictCode" : "RM",\n' +
            '"SupplyDistrict" : "ROMA",\n' +
            '"SupplyCountry" : "ITA",\n' +
            '"SupplyAddress" : "VIA DEI MONTI SIRINI",\n' +
            '"StartDate" : "2019-01-01T00:00:00.000Z",\n' +
            '"PreviousSupplier" : "ENEGAN S.p.a.",\n' +
            '"Power" : 11.000000,\n' +
            '"PoDNumber" : "IT001E64982106",\n' +
            '"PoDInternalId" : ' + sPod1InternalId + ',\n' +
            '"PaymentTerms" : "SDD Core",\n' +
            '"PaymentSDDMandateCode" : null,\n' +
            '"PaymentIBAN" : "IT41B0200  873622000 400497617",\n' +
            '"LegalPostalCode" : "00012",\n' +
            '"LegalPlace" : null,\n' +
            '"LegalMunicipalityICode" : "12058047",\n' +
            '"LegalMunicipality" : "GUIDONIA MONTECELIO",\n' +
            '"LegalHouseNumber" : "7",\n' +
            '"LegalDistrictCode" : "RM",\n' +
            '"LegalDistrict" : "ROMA",\n' +
            '"LegalCountry" : "ITA",\n' +
            '"LegalAddress" : "VIA DEI MONTI SIRINI",\n' +
            '"InsertedDate" : "2018-11-29T09:53:10.643Z",\n' +
            '"HistoricalConsumption" : 3184.00,\n' +
            '"EndDate" : null,\n' +
            '"DistributorTollFreeNumber" : "803500",\n' +
            '"Distributor" : "Enel Distribuzione S.p.A.",\n' +
            '"CustomerVATId" : "1234567890",\n' +
            '"CustomerSurname" : "Totti",\n' +
            '"CustomerName" : "Franco",\n' +
            '"CustomerInternalId" : 150140,\n' +
            '"CustomerFiscalCode" : "RCNPLA65D28H501BC",\n' +
            '"CustomerERPCode" : null,\n' +
            '"CustomerCompany" : "Franco Totti",\n' +
            '"CTE" : "SONNEN ENERGY",\n' +
            '"AttorneyUsername" : "f149406_98ea25bc-85b2-4cef-956f-674daf3f54b4",\n' +
            '"AttorneySurname" : "Totti",\n' +
            '"AttorneyName" : "Franco",\n' +
            '"CustomerMobileNumber" : "+33 123912300",\n' +
            '"CustomerPhoneNumber" : "+33 123123 234324",\n' +
            '"CallbackDate" : "2019-08-15T08:32:40",\n' +
            '"AttorneyEmail" : "franco@totti.com"\n' +
            '},' +
            '{\n' +
            '"Voltage" : 400.00,\n' +
            '"UpdatedDate" : "2018-12-03T00:00:00.000Z",\n' +
            '"Type" : 1,\n' +
            '"TransportOption" : "TDR",\n' +
            '"SupplyPostalCode" : "00012",\n' +
            '"SupplyPlace" : null,\n' +
            '"SupplyMunicipalityICode" : "12058047",\n' +
            '"SupplyMunicipality" : "GUIDONIA MONTECELIO",\n' +
            '"SupplyHouseNumber" : "7",\n' +
            '"SupplyDistrictCode" : "RM",\n' +
            '"SupplyDistrict" : "ROMA",\n' +
            '"SupplyCountry" : "ITA",\n' +
            '"SupplyAddress" : "VIA DEI MONTI SIRINI",\n' +
            '"StartDate" : "2019-01-01T00:00:00.000Z",\n' +
            '"PreviousSupplier" : "ENEGAN S.p.a.",\n' +
            '"Power" : 11.000000,\n' +
            '"PoDNumber" : "IT001E64982106",\n' +
            '"PoDInternalId" : ' + sPod2InternalId + ',\n' +
            '"PaymentTerms" : "SDD Core",\n' +
            '"PaymentSDDMandateCode" : null,\n' +
            '"PaymentIBAN" : "IT41B0200  873622000 400497617",\n' +
            '"LegalPostalCode" : "00012",\n' +
            '"LegalPlace" : null,\n' +
            '"LegalMunicipalityICode" : "12058047",\n' +
            '"LegalMunicipality" : "GUIDONIA MONTECELIO",\n' +
            '"LegalHouseNumber" : "7",\n' +
            '"LegalDistrictCode" : "RM",\n' +
            '"LegalDistrict" : "ROMA",\n' +
            '"LegalCountry" : "ITA",\n' +
            '"LegalAddress" : "VIA DEI MONTI SIRINI",\n' +
            '"InsertedDate" : "2018-11-29T09:53:10.643Z",\n' +
            '"HistoricalConsumption" : 3184.00,\n' +
            '"EndDate" : null,\n' +
            '"DistributorTollFreeNumber" : "803500",\n' +
            '"Distributor" : "Enel Distribuzione S.p.A.",\n' +
            '"CustomerVATId" : "1234567890",\n' +
            '"CustomerSurname" : "Mancini",\n' +
            '"CustomerName" : "Carla",\n' +
            '"CustomerInternalId" : 150133,\n' +
            '"CustomerFiscalCode" : "RCNPLA65D28H501BC",\n' +
            '"CustomerERPCode" : null,\n' +
            '"CustomerCompany" : "Carla Mancini",\n' +
            '"CTE" : "SONNEN ENERGY",\n' +
            '"AttorneyUsername" : "f149406_98ea25bc-85b2-4cef-956f-674daf3f54b4",\n' +
            '"AttorneySurname" : "Mancini",\n' +
            '"AttorneyName" : "Carla",\n' +
            '"CustomerMobileNumber" : "+33 123912300",\n' +
            '"CustomerPhoneNumber" : "+33 123123 234324",\n' +
            '"CallbackDate" : "2019-07-01T08:32:40",\n' +
            '"AttorneyEmail" : "Carla@test.com"\n' +
            '},' +
            // This one should raise an error as Name is not set!
            '{\n' +
            '"Voltage" : 400.00,\n' +
            '"UpdatedDate" : "2018-12-03T00:00:00.000Z",\n' +
            '"Type" : 1,\n' +
            '"TransportOption" : "TDR",\n' +
            '"SupplyPostalCode" : "00012",\n' +
            '"SupplyPlace" : null,\n' +
            '"SupplyMunicipalityICode" : "12058047",\n' +
            '"SupplyMunicipality" : "GUIDONIA MONTECELIO",\n' +
            '"SupplyHouseNumber" : "7",\n' +
            '"SupplyDistrictCode" : "RM",\n' +
            '"SupplyDistrict" : "ROMA",\n' +
            '"SupplyCountry" : "ITA",\n' +
            '"SupplyAddress" : "VIA DEI MONTI SIRINI",\n' +
            '"StartDate" : "2019-01-01T00:00:00.000Z",\n' +
            '"PreviousSupplier" : "ENEGAN S.p.a.",\n' +
            '"Power" : 11.000000,\n' +
            '"PoDNumber" : "IT001E64982106",\n' +
            '"PoDInternalId" : ' + sPod3InternalId + ',\n' +
            '"PaymentTerms" : "SDD Core",\n' +
            '"PaymentSDDMandateCode" : null,\n' +
            '"PaymentIBAN" : "IT41B0200  873622000 400497617",\n' +
            '"LegalPostalCode" : "00012",\n' +
            '"LegalPlace" : null,\n' +
            '"LegalMunicipalityICode" : "12058047",\n' +
            '"LegalMunicipality" : "GUIDONIA MONTECELIO",\n' +
            '"LegalHouseNumber" : "7",\n' +
            '"LegalDistrictCode" : "RM",\n' +
            '"LegalDistrict" : "ROMA",\n' +
            '"LegalCountry" : "ITA",\n' +
            '"LegalAddress" : "VIA DEI MONTI SIRINI",\n' +
            '"InsertedDate" : "2018-11-29T09:53:10.643Z",\n' +
            '"HistoricalConsumption" : 3184.00,\n' +
            '"EndDate" : null,\n' +
            '"DistributorTollFreeNumber" : "803500",\n' +
            '"Distributor" : "Enel Distribuzione S.p.A.",\n' +
            '"CustomerVATId" : "1234567890",\n' +
            '"CustomerSurname" : null,\n' +
            '"CustomerName" : null,\n' +
            '"CustomerInternalId" : 150134,\n' +
            '"CustomerFiscalCode" : "RCNPLA65D28H501BC",\n' +
            '"CustomerERPCode" : null,\n' +
            '"CustomerCompany" : "Donatella Versace",\n' +
            '"CTE" : "SONNEN ENERGY",\n' +
            '"AttorneyUsername" : "f149406_98ea25bc-85b2-4cef-956f-674daf3f54b4",\n' +
            '"AttorneySurname" : "VERSACE",\n' +
            '"AttorneyName" : "DONATELLA",\n' +
            '"CustomerMobileNumber" : "+33 123912300",\n' +
            '"CustomerPhoneNumber" : "+33 123123 234324",\n' +
            '"CallbackDate" : "2019-06-10T08:32:40",\n' +
            '"AttorneyEmail" : "test2@test.com"\n' +
            '},' +
            // Will have a fuzzy match
            '{\n' +
            '"Voltage" : 300.00,\n' +
            '"UpdatedDate" : "2018-12-24T00:00:00.000Z",\n' +
            '"Type" : 1,\n' +
            '"TransportOption" : "TDR",\n' +
            '"SupplyPostalCode" : "00012",\n' +
            '"SupplyPlace" : null,\n' +
            '"SupplyMunicipalityICode" : "12058047",\n' +
            '"SupplyMunicipality" : "ROMA",\n' +
            '"SupplyHouseNumber" : "7",\n' +
            '"SupplyDistrictCode" : "RM",\n' +
            '"SupplyDistrict" : "ROMA",\n' +
            '"SupplyCountry" : "ITA",\n' +
            '"SupplyAddress" : "VIA DEI NIXO",\n' +
            '"StartDate" : "2019-08-01T00:00:00.000Z",\n' +
            '"PreviousSupplier" : "ENEGAN S.p.a.",\n' +
            '"Power" : 15.0000,\n' +
            '"PoDNumber" : "IT001E64982106",\n' +
            '"PoDInternalId" : ' + sPod4InternalId + ',\n' +
            '"PaymentTerms" : "SDD Core",\n' +
            '"PaymentSDDMandateCode" : null,\n' +
            '"PaymentIBAN" : "IT41B0200  873622000 400497617",\n' +
            '"LegalPostalCode" : "' + oAccountForDuplicateFuzzySearch.BillingPostalCode + '",\n' +
            '"LegalPlace" : null,\n' +
            '"LegalMunicipalityICode" : "12058047",\n' +
            '"LegalMunicipality" : "ROMA",\n' +
            '"LegalHouseNumber" : "7",\n' +
            '"LegalDistrictCode" : "RM",\n' +
            '"LegalDistrict" : "ROMA",\n' +
            '"LegalCountry" : "ITA",\n' +
            '"LegalAddress" : "PLACE DEL SPAGHETTI",\n' +
            '"InsertedDate" : "2018-11-29T09:53:10.643Z",\n' +
            '"HistoricalConsumption" : 3184.00,\n' +
            '"EndDate" : null,\n' +
            '"DistributorTollFreeNumber" : "803500",\n' +
            '"Distributor" : "Enel Distribuzione S.p.A.",\n' +
            '"CustomerVATId" : "73463477",\n' +
            '"CustomerSurname" : "Mente",\n' +
            '"CustomerName" : "Rudi",\n' +
            '"CustomerInternalId" : 123456,\n' +
            '"CustomerFiscalCode" : "RCNPLA65D28H501BC",\n' +
            '"CustomerERPCode" : null,\n' +
            '"CustomerCompany" : "Rudi Mente",\n' +
            '"CTE" : "SONNEN ENERGY",\n' +
            '"AttorneyUsername" : "f149406_98ea25bc-85b2-4cef-956f-674daf3f54b4",\n' +
            '"AttorneySurname" : "Mente",\n' +
            '"AttorneyName" : "Rudi",\n' +
            '"CustomerMobileNumber" : "+33 7346347",\n' +
            '"CustomerPhoneNumber" : "+33 823839 234324",\n' +
            '"CallbackDate" : "2019-08-01T08:32:40",\n' +
            '"AttorneyEmail" : "rudi@mente.com"\n' +
            '}' +
            ']';

        List<EnergestEntityPod.EnergestPod> listPodWrappers = (List<EnergestEntityPod.EnergestPod>) JSON.deserialize(sJson, List<EnergestEntityPod.EnergestPod>.class);

        RESTClient.setPredefinedCalloutMock(new RESTClient.PredefinedCalloutMock(
            200,
            'OK',
            sJson,
            new Map<String, String>{
                'Content-type' => 'application/json'
            }
        ));

        //------------------------------------------------------------
        Test.startTest();

        EnergestSynchronizer.DEFAULT_PERIOD_OF_TIME_DAYS = 10;
        Integer iPeriodOfDays = EnergestSynchronizer.DEFAULT_PERIOD_OF_TIME_DAYS + 1;

        EnergestSynchronizer oSynchronizer = new EnergestSynchronizer();
        oSynchronizer.minPodStartDate = Date.newInstance(2019, 1, 1);
        oSynchronizer.periodOfDaysToFetch = iPeriodOfDays;
        oSynchronizer.fetch();

        List<EnergestPod__c> listEnergestPods = [
            SELECT
                Name,
                PodInternalId__c,
                Account__c, Contract__c, BankData__c,
                DataAsJson__c, EnergestLastModified__c, LastCheckedModifiedDatetime__c
            FROM
                EnergestPod__c
            LIMIT 10
        ];

        System.assertEquals(4, listEnergestPods.size(), 'Expected exactly 4 PODs to be inserted');

        Integer iIndex = 0;

        for (EnergestPod__c oEnergestPod : listEnergestPods) {
            System.assertEquals(null, oEnergestPod.Account__c, 'Assert Account__c to be null');
            System.assertEquals(null, oEnergestPod.Contract__c, 'Assert Contract__c to be null');
            System.assertEquals(null, oEnergestPod.BankData__c, 'Assert BankData__c to be null');
            System.assertEquals(null, oEnergestPod.LastCheckedModifiedDatetime__c, 'Assert LastCheckedModifiedDatetime__c to be null');
            System.assertEquals(listPodWrappers.get(iIndex).UpdatedDate, oEnergestPod.EnergestLastModified__c, 'Assert EnergestLastModified__c to match UpdatedDate from JSON');
            iIndex++;
        }

        // Create existing SObjects
        EnergestEntityPod oEnergestEntityPod = new EnergestEntityPod(listEnergestPods.get(1));
        Account oAccountExisting      = oEnergestEntityPod.energestAccount.oAccount;
        Contract oContractExisting    = oEnergestEntityPod.energestContract.oContract;
        BankData__c oBankDataExisting = oEnergestEntityPod.energestBankData.oBankData;

        // Change something to have an update on the existing Account
        oAccountExisting.Phone = '98329423048230482348';

        // If this would be set to null the existing oBankDataExisting could not be found
        // as it has EnergestPseudoId__c which is built like
        // Account__r.EnergestCustomerID__c & "-" & SUBSTITUTE(IBAN__c, " ", "")
        // But test scenario makes no sense as oContractExisting (Contract) is also relating
        // to the POD.
        //oAccountExisting.EnergestCustomerID__c = null;

        // Clone existing Account for Duplicate search check. This would not be
        // taken as EnergestCustomerID__c is null and match is bad therefore
        Account oAccountExistingCloneForDuplicateSearch = oAccountExisting.clone();
        oAccountExistingCloneForDuplicateSearch.EnergestCustomerID__c = null;

        // On using Duplicate Finder Class both of these account would
        // match 100%. But only the latter one has also an exact match
        // on the EnergestCustomerID__c. The ordering is assured by
        // EnergestEntityPod.getOrderedMatchRecords()
        insert new List<Account>{
            oAccountExistingCloneForDuplicateSearch,
            oAccountExisting,
            oAccountForDuplicateFuzzySearch
        };

        oAccountExisting = [SELECT PersonContactId, Phone FROM Account WHERE Id = :oAccountExisting.Id];

        System.debug(DEBUG_HERE + 'Insert Bank Account');
        oBankDataExisting.Account__c = oAccountExisting.Id;

        TriggerHandler.bypass('BankDataTriggerHandler');
        insert oBankDataExisting;
        TriggerHandler.clearBypass('BankDataTriggerHandler');

        TriggerHandler.bypass('ContractTriggerHandler');
        oContractExisting.AccountId        = oAccountExisting.Id;
        oContractExisting.CustomerSignedId = oAccountExisting.PersonContactId;
        oContractExisting.BankData__c      = oBankDataExisting.Id;
        insert oContractExisting;

        oContractExisting.Status = 'Activated';
        update oContractExisting;
        TriggerHandler.clearBypass('ContractTriggerHandler');

        Database.executeBatch(oSynchronizer);

        Test.stopTest();
        //------------------------------------------------------------

        System.assertEquals(EnergestSynchronizer.DEFAULT_PERIOD_OF_TIME_DAYS, oSynchronizer.getPeriodOfDaysToFetchFromSettings(), 'Expected getPeriodOfDaysToFetchFromSettings() to return ' + EnergestSynchronizer.DEFAULT_PERIOD_OF_TIME_DAYS);
        System.assertEquals(iPeriodOfDays, oSynchronizer.periodOfDaysToFetch, 'Expected "periodOfDaysToFetch" not to be changed as it was overwritten');

        List<Case> listCases = [SELECT Id, Subject, Description FROM Case WHERE Subject = :EnergestSynchronizer.ERROR_CASE_SUBJECT];

        if (!listCases.isEmpty()) {
            System.debug(DEBUG_HERE + 'Error Case: ' + listCases);
        }
        System.assertEquals(1, listCases.size(), 'Expected an error case');

        Case oCase = listCases.get(0);
        System.assert(oCase.Description.contains('REQUIRED_FIELD_MISSING'));
        System.assert(oCase.Description.contains(String.valueOf(listEnergestPods.get(2).Id)));

        // Duplicate Case
        listCases = [SELECT Id, Subject, Description, EnergestPod__r.PodInternalId__c FROM Case WHERE Subject = :EnergestEntityPod.MULTIPLE_DUPLICATES_CASE_SUBJECT];
        System.assert(listCases.size() == 1, 'Expected one Case due to multiple duplicates');
        System.debug(DEBUG_HERE + 'Duplicate Case: ' + JSON.serializePretty(listCases.get(0)));

        // Fuzzy match Cases
        listCases = [SELECT Id, Subject, Description, EnergestPod__r.PodInternalId__c FROM Case WHERE Subject = :EnergestEntityPod.FUZZY_MATCH_CASE_SUBJECT];
        System.assert(listCases.size() == 1, 'Expected one Case due to a fuzzy match');
        System.assertEquals(sPod4InternalId, listCases.get(0).EnergestPod__r.PodInternalId__c, 'Expected POD 4 to raise a Case due to fuzzy match');
        System.debug(DEBUG_HERE + 'Fuzzy Match Case: ' + JSON.serializePretty(listCases.get(0)));

        // Check PODs

        // Get SOQL fields to request
        Map<String, Set<String>> mapFieldsBySObject = new Map<String, Set<String>>();
        oEnergestEntityPod = new EnergestEntityPod(listEnergestPods.get(0));
        EnergestEntityPod.mergeFieldMap(mapFieldsBySObject, oEnergestEntityPod.getSObjectFieldsForSoql());

        Set<String> lsetAllFields = new Set<String>();
        for (String sLookupField : mapFieldsBySObject.keySet()) {
            lsetAllFields.addAll(mapFieldsBySObject.get(sLookupField));
        }

        String sSOQL = 'SELECT Id, Name, Error__c, LastCheckedModifiedDatetime__c, EnergestLastModified__c, ' +
            'NeedsCheck__c, PodInternalId__c, ' + String.join(new List<String>(lsetAllFields), ', ') + ' ' +
            'FROM EnergestPod__c WHERE Id IN :listEnergestPods';

        System.debug(DEBUG_HERE + 'Query EnergestPod__c: ' + sSOQL);
        listEnergestPods = (List<EnergestPod__c>)Database.query(sSOQL);

        for (EnergestPod__c oEnergestPod : listEnergestPods) {

            if (oEnergestPod.PodInternalId__c == sPod1InternalId
                || oEnergestPod.PodInternalId__c == sPod2InternalId
                || oEnergestPod.PodInternalId__c == sPod4InternalId) {

                System.assertNotEquals(null, oEnergestPod.Account__c, 'Assert Account__c NOT to be null');
                System.assertNotEquals(null, oEnergestPod.Contract__c, 'Assert Contract__c NOT to be null');
                System.assertNotEquals(null, oEnergestPod.BankData__c, 'Assert BankData__c NOT to be null');

                Account oAccount      = oEnergestPod.Account__r;
                Contract oContract    = oEnergestPod.Contract__r;
                BankData__c oBankData = oEnergestPod.BankData__r;

                System.debug(DEBUG_HERE + 'SObjects afterwards for POD ' + oEnergestPod.PodInternalId__c + ':');
                System.debug(DEBUG_HERE + oAccount);
                System.debug(DEBUG_HERE + oContract);
                System.debug(DEBUG_HERE + oBankData);

                System.assertEquals(oBankData.Account__c, oAccount.Id, 'Expect BankData Account to match the created Account');
                System.assertEquals(oAccount.Id, oContract.AccountId, 'Expect Contract Account to match the created Account');
                System.assertEquals(oBankData.Id, oContract.BankData__c, 'Expect Contract BankData__c to match the created BankData__c');
                System.assertEquals(oAccount.PersonContactId, oContract.CustomerSignedId, 'Expect Contract CustomerSignedId to match Account.PersonContactId');

                if (oEnergestPod.PodInternalId__c == sPod2InternalId) {

                    System.assertEquals(oAccountExisting.Id, oEnergestPod.Account__c, 'Expect Account to match the pre existing Account');
                    System.assertEquals(oContractExisting.Id, oEnergestPod.Contract__c, 'Expect Contract to match the pre existing Contract');
                    System.assertEquals(oBankDataExisting.Id, oEnergestPod.BankData__c, 'Expect BankData to match the pre existing BankData');

                    System.assertNotEquals(
                        oAccountExisting.Phone,
                        oAccount.Phone,
                        'Expected to be updated with values from Energest as existing Account was ' +
                        'an exact match for duplicate search'
                    );
                }
                else if (oEnergestPod.PodInternalId__c == sPod4InternalId) {

                    Map<Id, Boolean> mapSObjectDuplicateFuzzy = EnergestEntityPod.mapDuplicateMatchesByPodId.get(oEnergestPod.Id);

                    System.assert(mapSObjectDuplicateFuzzy != null, 'Expected duplicate search for Pod 4 Account');
                    System.assert(mapSObjectDuplicateFuzzy.containsKey(oAccount.Id), 'Expected to find Pod 4 Account by duplicate search');
                    System.assert(mapSObjectDuplicateFuzzy.get(oAccount.Id), 'Expected to found Pod 4 Account by fuzzy search');

                    // Check fuzzy search
                    if (!EnergestEntityPod.ALLOW_DUPLICATE_UPDATE) {
                        System.assertEquals(oAccountForDuplicateFuzzySearch.LastName, oAccount.LastName, 'LastName should NOT have been changed as ALLOW_DUPLICATE_UPDATE is FALSE');
                    }
                    else {
                        System.assertEquals(oAccountForDuplicateFuzzySearch.LastName, oAccount.LastName, 'LastName should not have been changed as existing Account was fuzzy found');
                    }
                }

                System.assertEquals(oEnergestPod.EnergestLastModified__c, oEnergestPod.LastCheckedModifiedDatetime__c, 'Expected equal dates');
                System.assertEquals(false, oEnergestPod.NeedsCheck__c, 'Assert no further checks');

                // Just for code coverage as updates are currently not required!
                EnergestSObjectWrapper.getChecksum(oAccount);
                continue;
            }

            if (oEnergestPod.PodInternalId__c == sPod3InternalId) {

                System.debug(DEBUG_HERE + 'Error__c: ' + oEnergestPod.Error__c);

                System.assertEquals(null, oEnergestPod.Account__c, 'Assert Account__c to be null');
                System.assertEquals(null, oEnergestPod.Contract__c, 'Assert Contract__c to be null');
                System.assertEquals(null, oEnergestPod.BankData__c, 'Assert BankData__c to be null');
                System.assertNotEquals(null, oEnergestPod.Error__c, 'Assert an error set');
                System.assertEquals(false, oEnergestPod.NeedsCheck__c, 'Assert no further checks');

                System.assertEquals(null, oEnergestPod.LastCheckedModifiedDatetime__c, 'Expected LastCheckedModifiedDatetime__c to be still unset');

                continue;
            }
        }

        // Check if Duplicates have been found and taken into account
        System.debug(DEBUG_HERE + 'EnergestEntityPod.mapDuplicateMatchesByPodId: ' + EnergestEntityPod.mapDuplicateMatchesByPodId);
        //System.assert(EnergestEntityPod.mapExistingDuplicates.containsKey(oAccountExisting.Id), 'Expected duplicate for ' + oAccountExisting); // Carla Mancini
    }
}