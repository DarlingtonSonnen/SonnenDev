/**
 * ContractCreatorFromOpportunityCtrlTest
 *
 * Tests for the controller of Lightning Component "ContractCreatorFromOpportunity"
 *
 * v1.1.0   2018-04-26  Polina Tsuban-Drobot        initial (SOBCRM-1163)
 * v1.2.0   2018-05-11  Marko Schmalenbach          testCreateContract(): Added check on attached contract files (SOBCRM-1169)
 * v1.3.0   2018-06-18  Marko Schmalenbach          testCreateContract(): Added check on creation of Terms and Conditions acceptance (SOBCRM-1189)
 * v1.4.0   2018-06-20  Marko Schmalenbach          testCreateContract(): Added check on creation of PV Plant Asset (SOBCRM-1216)
 * v1.5.0   2018-07-03  Marko Schmalenbach          testCreateContract(): Added check on creation of Meter Installation (SOBCRM-1154)
 * v1.6.0   2018-09-19  Marko Schmalenbach          - testCreateContract(): Set mandatory checkbox fields to true to be able to activate the Contract (SOBCRM-1238)
 *                                                  - testCreateContract(): Check on Terms and Conditions Acceptance Contact (SOBCRM-1259)
 * v1.6.1   2018-10-12  Marko Schmalenbach          Added debugging
 * v1.6.2   2018-11-01  Marko Schmalenbach          Test relation of Contract to created PV Plant Asset not PV Plant to Contract anymore (SOBCRM-1288)
 * v1.7.0   2019-01-14  Marko Schmalenbach          Test testCreateContractChange (SOBCRM-1310)
 * v1.7.1   2019-02-18  Marko Schmalenbach          Switched test from dedicated field for Change Reason on Opportunity to existing Order Input Definition Value (SOBCRM-1310)
 *
 * @see ContractCreatorFromOpportunityCtrl
 * @see RESTServiceOrder_Test
 * @see WebOrderContractCreator
 */
@isTest
private class ContractCreatorFromOpportunityCtrlTest {

    private static final String DEBUG_HEADER = 'ContractCreatorFromOpportunityCtrlTest.';

    private static Boolean createContractInSetup = false;
    private static Contract contractFromSetup;
    private static Opportunity opportunityFromSetup;

    private static void setupStatic() {

        final String DEBUG_HERE = DEBUG_HEADER + 'setupStatic() - ';

        RESTServiceOrder_Test.setupStatic();
        Test.startTest();

        RestRequest request = new RestRequest();
        request.requestURI = '/order/';
        request.httpMethod = 'POST';

        String sRequestJson = (String)JSON.serialize(RESTServiceOrder_Test.requestDataRESTServiceOrder);
        request.requestBody = Blob.valueOf(sRequestJson);

        // Set REST context
        RestContext.request  = request;
        RestContext.response = new RestResponse();

        // Insert contract
        RESTServiceOrder.Response oResponse = RESTServiceOrder.handlePost();
        System.debug(DEBUG_HERE + 'RESTServiceOrder.Response: ' + oResponse.error);
        System.assertEquals(200, RestContext.response.statusCode, 'Expect status code 200');

        // Create Contract
        if (createContractInSetup) {

            opportunityFromSetup = [SELECT Id, CloseDate, Pricebook2Id, AccountId FROM Opportunity LIMIT 1];

            ContractCreatorFromOpportunityCtrl oController = ContractCreatorFromOpportunityCtrl.initComponent(opportunityFromSetup.Id);
            oController = ContractCreatorFromOpportunityCtrl.createContract(JSON.serialize(oController));

            List<Contract> listContracts = [SELECT Id, ContractNumber, ContractingPartnerFirstname__c, ContractingPartnerLastname__c, ContractPrevious__c FROM Contract];
            System.assertEquals(1, listContracts.size(), 'Expected one Contract');

            contractFromSetup = listContracts.get(0);
        }

        Test.stopTest();
    }

    @isTest
    static void testInitComponent() {
        setupStatic();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        ContractCreatorFromOpportunityCtrl ctrl = ContractCreatorFromOpportunityCtrl.initComponent(opp.Id);

        System.assertNotEquals(null, ctrl.opp);
        System.assertNotEquals(null, ctrl.orderInpDefVal);
    }

    /**
     * Test for Contract changes
     *
     * @since 2019-01-14
     * @see https://interaktiv.jira.com/browse/SOBCRM-1310
     */
    @isTest
    static void testCreateContractChange() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testCreateContractChange() - ';

        RESTServiceOrder.suppressDebug = true;
        createContractInSetup = true;
        setupStatic();

        System.debug(DEBUG_HERE + 'Start main');

        System.assert(contractFromSetup.ContractPrevious__c == null, 'Expected ContractPrevious__c to be null here');

        contractFromSetup.LumenazaSkipApiCall__c      = true;
        contractFromSetup.Status                      = 'Activated';
        contractFromSetup.IsPVSizeSpezified__c        = true;
        contractFromSetup.IsInstallerSpezified__c     = true;
        contractFromSetup.IsEnergyTariffClassified__c = true;
        contractFromSetup.IsInstallationDocumented__c = true;
        contractFromSetup.ContractDataApproved__c     = true;
        update contractFromSetup;

        // Clone Opportunity and set Subscription Reason for next Contract to change to
        Opportunity oppForChange = opportunityFromSetup.clone();
        oppForChange.Name = 'Opp for Change';
        oppForChange.StageName = 'Draft';
        System.debug(DEBUG_HERE + 'oppForChange: ' + oppForChange);
        insert oppForChange;

        // Clone Line Items
        List<OpportunityLineItem> listOpportunityLineItems = new List<OpportunityLineItem>();

        for (OpportunityLineItem oOpportunityLineItem : [SELECT TotalPrice, Product2Id, Quantity FROM OpportunityLineItem WHERE OpportunityId = :opportunityFromSetup.Id]) {
            listOpportunityLineItems.add(
                new OpportunityLineItem(
                    OpportunityId = oppForChange.Id,
                    Product2Id    = oOpportunityLineItem.Product2Id,
                    Quantity      = oOpportunityLineItem.Quantity,
                    TotalPrice    = oOpportunityLineItem.TotalPrice
                )
            );
        }

        insert listOpportunityLineItems;

        // Get OID Value holding subscription reason and clone it
        List<OrderInputDefinitionValue__c> listOrderInputDefinitionValues = [
            SELECT
                OrderInputDefinitionFieldId__c,
                Opportunity__c,
                OpportunityLineItem__c,
                OrderInputDefinitionJunction__c,
                OrderInputDefinition__c
            FROM OrderInputDefinitionValue__c
            WHERE OrderInputDefinitionFieldId__c = :ContractCreatorFromOpportunityCtrl.CONTRACT_CHANGE_REASON_OID_ID
        ];
        System.assert(listOrderInputDefinitionValues.size() == 1, 'Expected OID value of ID "'  + ContractCreatorFromOpportunityCtrl.CONTRACT_CHANGE_REASON_OID_ID + '"');

        OrderInputDefinitionValue__c oOrderInputDefinitionValueSubscriptionReason = listOrderInputDefinitionValues.get(0).clone();
        oOrderInputDefinitionValueSubscriptionReason.Value__c = ContractCreatorFromOpportunityCtrl.CONTRACT_CHANGE_REASON;
        oOrderInputDefinitionValueSubscriptionReason.Opportunity__c = oppForChange.Id;
        insert oOrderInputDefinitionValueSubscriptionReason;

        ContractCreatorFromOpportunityCtrl oController = ContractCreatorFromOpportunityCtrl.initComponent(oppForChange.Id);

        System.assertEquals(true, oController.isContractChange, 'Expected Contract Change');
        System.assert(oController.newContract != null, 'Expected dummy Contract newContract to be not null');

        System.assert(oController.lookupSearchResultPreviousContractProposal != null, 'Proposal for previous Contract should be initialized');
        System.assertEquals(contractFromSetup.Id, oController.lookupSearchResultPreviousContractProposal.getId(), 'Proposed Contract should match previous');

        // Test search method
        Test.setFixedSearchResults(new List<Id>{ contractFromSetup.Id });
        List<LookupSearchResult> listLookupSearchResults = ContractCreatorFromOpportunityCtrl.search(contractFromSetup.ContractNumber, null);
        System.assert(!listLookupSearchResults.isEmpty(), 'Expected a search result');

        // Create new Contract

        // This would be set by the LEX Component Javascript controller (helper)
        LookupSearchResult oLookupSearchResult = oController.lookupSearchResultPreviousContractProposal;

        oController.newContract.ContractPrevious__c       = oLookupSearchResult.getId();
        oController.newContract.MeterReadingValueStart__c = 123456;

        System.assertEquals('Contract', oLookupSearchResult.getSObjectType());
        System.assertNotEquals(null, oLookupSearchResult.getIcon());
        System.assertNotEquals(null, oLookupSearchResult.getSubtitle());
        System.assertNotEquals(null, oLookupSearchResult.getTitle());

        System.debug(DEBUG_HERE + 'Queries - before createContract : ' + Limits.getQueries());

        ContractCreatorFromOpportunityCtrl.createContract(JSON.serialize(oController));
        List<Contract> listContracts = [SELECT Id, MeterReadingValueStart__c FROM Contract WHERE ContractPrevious__c = :contractFromSetup.Id];
        System.assertEquals(1, listContracts.size(), 'Expected one Contract with previous Contract matching ' + contractFromSetup.Id);
        System.assertEquals(oController.newContract.MeterReadingValueStart__c, listContracts.get(0).MeterReadingValueStart__c);

        System.debug(DEBUG_HERE + 'Queries - End: ' + Limits.getQueries());
    }

    @isTest
    static void testCreateContract() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testCreateContract() - ';

        RESTServiceOrder.suppressDebug = true;
        setupStatic();

        System.debug(DEBUG_HERE + 'Start main');

        // Get Order JSON map from RESTServiceOrder_Test
        List<Object> listLineItems = (List<Object>)RESTServiceOrder_Test.requestDataRESTServiceOrder.get('lineItems');
        Map<String,Object> mapMainProduct = (Map<String,Object>)listLineItems.get(0);
        Map<String,Object> mapCustom = (Map<String,Object>)mapMainProduct.get('custom');
        Map<String,Object> mapCustomProductFields = (Map<String,Object>)mapCustom.get('fields');

        String sMeterInstallationProductionMeterID = String.valueOf(mapCustomProductFields.get('cMeterId'));

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        ContractCreatorFromOpportunityCtrl ctrl = ContractCreatorFromOpportunityCtrl.initComponent(opp.Id);

        // Set currently mandatory fields to automatically activate the Contract
        // (MSB, 2018-09-19, SOBCRM-1238)
        ctrl.opp.IsPVSizeSpezified__c        = true;
        ctrl.opp.IsInstallerSpezified__c     = true;
        ctrl.opp.IsEnergyTariffClassified__c = true;
        ctrl.opp.IsInstallationDocumented__c = true;
        ctrl.opp.ContractDataApproved__c     = true;

        ctrl = ContractCreatorFromOpportunityCtrl.createContract(JSON.serialize(ctrl));

        List<Contract> listContracts = [
            SELECT
                Id,
                AccountId,
                CustomerSignedId,
                PVAsset__c,
                PVAsset__r.PVSizekWp__c,
                PVAsset__r.AccountId,
                (SELECT ContentDocumentId FROM ContentDocumentLinks),
                (SELECT Id, TermsAndConditions__c, TnCType__c, Contact__c FROM TnCsContracts__r),
                (SELECT Id, ProductionMeterID__c, Account__c FROM Meter_Installation__r WHERE ProductionMeterID__c = :sMeterInstallationProductionMeterID)
            FROM
                Contract
        ];

        System.assertEquals(1, listContracts.size());
        System.assertEquals(true, ctrl.contractCreated);
        System.assertEquals(true, [SELECT IsClosed FROM Opportunity WHERE Id = :opp.Id].IsClosed);
        System.assertEquals(1, [SELECT COUNT() FROM FeedItem WHERE ParentId = :opp.Id]);

        //----------------------------------------------------------------
        // Check on ContentDocumentLinks for attached files (SOBCRM-1169)
        //----------------------------------------------------------------
        Contract oContract = listContracts.get(0);
        System.assertEquals(2, oContract.ContentDocumentLinks.size());

        ContentVersion oContentVersion = [SELECT VersionData, VersionNumber FROM ContentVersion WHERE ContentDocumentId = :oContract.ContentDocumentLinks.get(0).ContentDocumentId];

        String sFileContents = EncodingUtil.base64Decode(EncodingUtil.base64Encode(oContentVersion.VersionData)).toString();
        String sExpectedFileContents = (new RESTServiceOrder.AttachmentLoaderMockDispatcher()).RESPONSE_BODY;
        System.assertEquals(sFileContents, sExpectedFileContents);

        //----------------------------------------------------------------
        // Check on Terms and Conditions acceptance (SOBCRM-1189)
        //----------------------------------------------------------------
        System.assertEquals(1, oContract.TnCsContracts__r.size());
        // Check if Contact is set to the signee of the Contract (SOBCRM-1259)
        System.assert(oContract.CustomerSignedId != null);
        System.assertEquals(
            oContract.CustomerSignedId,
            oContract.TnCsContracts__r.get(0).Contact__c,
            'Expected Terms and Conditions Acceptance\'s Contact to match Contract\'s CustomerSignedId'
        );

        //----------------------------------------------------------------
        // Check on created PV Plant Asset (SOBCRM-1216)
        //----------------------------------------------------------------
        System.assert(oContract.PVAsset__c != null);

        System.assertEquals(Decimal.valueOf(String.valueOf(mapCustomProductFields.get('cPVSize__c'))), Decimal.valueOf(String.valueOf(oContract.PVAsset__r.PVSizekWp__c)), 'Expected Asset.PVSizekWp__c to equal value from Order JSON');
        System.assertEquals(oContract.AccountId, oContract.PVAsset__r.AccountId, 'Assert the same Account on Contract and PV Plant Asset');

        //----------------------------------------------------------------
        // Check on created Meter Installation (SOBCRM-1154)
        //----------------------------------------------------------------
        System.assertEquals(1, oContract.Meter_Installation__r.size());
        MeterInstallation__c oMeterInstallation = oContract.Meter_Installation__r.get(0);

        System.assertEquals(oContract.AccountId, oMeterInstallation.Account__c, 'Assert the same Account on Contract and Meter Installation');

        System.debug(DEBUG_HERE + 'Finished');
    }
}