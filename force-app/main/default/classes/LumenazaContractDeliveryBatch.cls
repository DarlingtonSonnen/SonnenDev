/**
 * LumenazaContractDeliveryBatch
 *
 * Changelog
 * ---------
 *
 * v1.3.0-2018-07-05 (SOBCRM-1228)
 * - Remove Stage on cases - 'Sync Lumenaza Error'
 *
 * v1.2.0-2018-04-27 (marko@die-interaktiven.de, SOBCRM-1177)
 * - Changed to ContractTriggerHandler.bypassMethod('synchronizeToLumenaza');
 *
 * v1.1.0-2018-04-17 (marko@die-interaktiven.de, SOBCRM-1175)
 * - Switched from DML to Database at updating contracts to keep allOrNone = false so
 *   that updating could partially fail
 * - Raise error case if update fails on a contract
 *
 * v1.0.0-2018-01-10
 * - Initial version (SOBCRM-1025)
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.2.0-2018-04-27
 * @see https://interaktiv.jira.com/browse/SOBCRM-1025
 * @see LumenazaContractBatchTests
 */
global class LumenazaContractDeliveryBatch implements Database.Batchable<SObject>,Database.Stateful,Database.AllowsCallouts,Schedulable {

    public static final String DEBUG_HEADER = 'LumenazaContractDeliveryBatch.';
    public static final Integer MAX_CONTRACTS_IN_BATCH = 90; // 1 Callout for oAuth, 10 buffer, rest for requests

    public static final String ERROR_CASE_SUBCATEGORY = 'E13, Sonstiges';

    private String debugLumenazaContractId;
    private Boolean doPersist = true;

    private Map<String,Map<String,Object>> testMockResponse;

    /**
     * execute() with SchedulableContext
     */
    global void execute(SchedulableContext SC) {
        Database.executeBatch(new LumenazaContractDeliveryBatch(), MAX_CONTRACTS_IN_BATCH);
    }

    /**
     * start()
     */
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // If you use a QueryLocator object, the governor limit for the total number
        // of records retrieved by SOQL queries is bypassed (up to 50 million records)
        String sQuery =
            'SELECT ' +
            '    Id, ' +
            '    Status, ' +
            '    LumenazaCustomerId__c, ' +
            '    LumenazaContractId__c, ' +
            '    ConfirmedDeliveryStart__c, ' +
            '    ConfirmedDeliveryEnd__c ' +
            'FROM ' +
            '    Contract ' +
            'WHERE ' +
            '    LumenazaCustomerId__c != NULL AND' +
            '    LumenazaContractId__c != NULL AND' +
            '    (ConfirmedDeliveryStart__c = NULL OR ConfirmedDeliveryEnd__c = NULL) AND' +
            '    Status = \'Activated\'';

        if (this.debugLumenazaContractId != null) {
            sQuery += ' AND LumenazaContractId__c = \'' + this.debugLumenazaContractId + '\'';
        }

        System.debug(DEBUG_HEADER + 'start() - SOQL: ' + sQuery);
        return Database.getQueryLocator(sQuery);
    }

    /**
     * Set Test API Mock Response
     *
     * @param testApiMockResponse
     */
    global void setTestApiMockResponse(Map<String,Map<String,Object>> testApiMockResponseForLumenazaContractId) {
        this.testMockResponse = testApiMockResponseForLumenazaContractId;
    }

    /**
     * execute() with BatchableContext
     */
    global void execute(Database.BatchableContext BC, List<SObject> scopeObjects) {

        String DEBUG_HERE = DEBUG_HEADER + 'execute() - ';

        List<Contract> listContracts = (List<Contract>) scopeObjects;
        System.debug(DEBUG_HERE + 'Handle ' + listContracts.size() + ' Contracts');

        if (listContracts.size() > MAX_CONTRACTS_IN_BATCH) {
            throw new LumenazaContractDeliveryBatchException('Amount of Contracts in a batch should not exceed ' + MAX_CONTRACTS_IN_BATCH + ' because of Apex callout limit');
        }

        LumenazaApi oLumenazaApi = new LumenazaApi();
        List<Contract> listContractsToUpdate = new List<Contract>();

        Integer i = 1;
        for (Contract oContract : listContracts) {

            System.debug(DEBUG_HERE + '#' + i + ' Get contract info for contract ' + oContract.Id);

            // Request Contract info from Lumenaza
            try {

                if (Test.isRunningTest() && this.testMockResponse != null && this.testMockResponse.containsKey(oContract.LumenazaContractId__c)) {
                    String sResponse = String.valueOf(this.testMockResponse.get(oContract.LumenazaContractId__c).get('response'));
                    Integer iStatus = Integer.valueOf(this.testMockResponse.get(oContract.LumenazaContractId__c).get('status'));
                    LumenazaRestApiMockDispatcher.setResultBodyNextRoute(sResponse, iStatus);
                }

                LumenazaApi.LumenazaApiResponse oLumenazaApiResponse = oLumenazaApi.fetchContractInfo(oContract.LumenazaCustomerId__c, oContract.LumenazaContractId__c);
                System.debug(DEBUG_HERE + oLumenazaApiResponse);

                if (oLumenazaApiResponse.success == false) {
                    System.debug(DEBUG_HERE + 'Error: ' + oLumenazaApiResponse.error + ' | Request info: ' + oLumenazaApiResponse.requestInfo);
                    continue;
                }

                Map<String,Object> mapResponse = (Map<String,Object>)JSON.deserializeUntyped(oLumenazaApiResponse.responseBody);

                /*
                Example JSON Response
                ---------------------
                {
                    "deliv_address_street": "Charlotte-Bamberg-Str.",
                    "deliv_address_house_number": "2",
                    "deliv_address_zipcode": "35578",
                    "deliv_address_city": "Wetzlar",
                    "deliv_address_addition": "",
                    "saas_contract_id": "C18124850-1",
                    "annual_consumption": 10000,
                    "status_info": "keine Statusinformation vorhanden.",
                    "meter_id": [
                        "7147192"
                    ],
                    "preferred_delivery_start": "2018-02-10",
                    "previous_provider": "9904383000003",
                    "subscription_reason": "E01",
                    "reg_status": "open_join",
                    "contract_termination_date": null,
                    "order_date": "2018-01-10",
                    "delivery_end": null,
                    "delivery_start": null,
                    "deliv_status": "not_delivering",
                    "contract_parameters": {},
                    "tariff_type": [
                        "package"
                    ],
                    "bonuses": []
                }

                 */
                System.debug(DEBUG_HERE + 'Response map: ' + mapResponse);

                // Get delivery start and end
                Date dateDeliveryStart = mapResponse.get('delivery_start') != null ? Date.valueOf(String.valueOf(mapResponse.get('delivery_start'))) : null;
                Date dateDeliveryEnd   = mapResponse.get('delivery_end') != null   ? Date.valueOf(String.valueOf(mapResponse.get('delivery_end')))   : null;

                Boolean bHasChange = false;

                if (mapResponse.containsKey('delivery_start') && oContract.ConfirmedDeliveryStart__c != dateDeliveryStart) {
                    bHasChange = true;
                    System.debug(DEBUG_HERE + 'ConfirmedDeliveryStart__c changed from ' + oContract.ConfirmedDeliveryStart__c + ' to ' + dateDeliveryStart);
                    oContract.ConfirmedDeliveryStart__c = dateDeliveryStart;
                }
                if (mapResponse.containsKey('delivery_end') && oContract.ConfirmedDeliveryEnd__c != dateDeliveryEnd) {
                    bHasChange = true;
                    System.debug(DEBUG_HERE + 'ConfirmedDeliveryEnd__c changed from ' + oContract.ConfirmedDeliveryEnd__c + ' to ' + dateDeliveryEnd);
                    oContract.ConfirmedDeliveryEnd__c = dateDeliveryEnd;
                }

                if (bHasChange) {

                    // Force a validation error on the third contract (see testContractInformationBatch())
                    // to ensure that the DML update fails for this contract
                    if (Test.isRunningTest() && i == 3) {
                        oContract.Type__c = 'Blablabla';
                    }

                    System.debug(DEBUG_HERE + 'Register Contract ' + oContract.Id + ' for update (Lumenaza: costumer ' + oContract.LumenazaCustomerId__c + ', contract ' + oContract.LumenazaContractId__c + ')');
                    listContractsToUpdate.add(oContract);
                }
            }
            catch (Exception e) {

                System.debug(DEBUG_HERE + 'Exception for Contract ' + oContract + ': ' + e);

                if (!Test.isRunningTest()) {
                    // This exception should not generate a Case as a problem here
                    // could not be resolved by the eService team!
                    throw new LumenazaContractDeliveryBatchException('Exception for Contract ' + oContract.Id + ': ' + e.getMessage() + ' - ' + e.getStackTraceString());
                }
            }

            i++;
        }

        if (!listContractsToUpdate.isEmpty()) {

            if (!this.doPersist) {
                System.debug(DEBUG_HERE + 'Skip persisting of ' + listContractsToUpdate.size() + ' Contract(s) as configured');
            }
            else {

                // Bypass trigger handlers
                ContractTriggerHandler.bypassMethod('synchronizeToLumenaza');
                ContractTriggerHandler.bypassMethod('synchronizeToAwattar');

                System.debug(DEBUG_HERE + 'Updating ' + listContractsToUpdate.size() + ' Contract(s)');
                List<Database.SaveResult> listSaveResults = Database.update(listContractsToUpdate, false); // allOrNone = false

                List<Case> listCases = new List<Case>();

                Integer iContractIndex = 0;

                for (Database.SaveResult oSaveResult : listSaveResults) {

                    Id idContract = listContractsToUpdate.get(iContractIndex).Id;

                    if (!oSaveResult.isSuccess()) {

                        System.debug(DEBUG_HERE + 'Error at updating contract ' + idContract + ' - ' + oSaveResult);

                        List<String> listErrors = new List<String>();

                        for (Database.Error oError : oSaveResult.getErrors()) {

                            String sError = oError.getStatusCode() + ': ' + oError.getMessage();

                            if (!oError.getFields().isEmpty()) {
                                sError += ', Field(s): ' + String.join(oError.getFields(), ', ');
                            }

                            listErrors.add(sError);
                        }

                        String sErrorSeparator = '\n    • ';

                        listCases.add(this.prepareCase(
                            idContract,
                            'Error updating contract at Delivery Batch',
                            'Errors: ' + sErrorSeparator + String.join(listErrors, sErrorSeparator)
                        ));
                    }
                    else {
                        System.debug(DEBUG_HERE + 'Contract ' + idContract + ' successfully updated');
                    }

                    iContractIndex++;
                }

                // Restore trigger handlers
                ContractTriggerHandler.clearBypassMethod('synchronizeToLumenaza');
                ContractTriggerHandler.clearBypassMethod('synchronizeToAwattar');

                if (!listCases.isEmpty()) {
                    System.debug('Insert error cases: ' + listCases);
                    insert listCases;
                }
            }
        }

        System.debug(DEBUG_HERE + 'finished');
    }

    /**
     * Prepare a case for error
     *
     * @param idContract
     * @param sSubject
     * @param sDescription
     *
     * @return
     */
    global Case prepareCase(Id idContract, String sSubject, String sDescription) {

        //1.7.0 - remove stage
        return new Case(
            RecordTypeId   = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Case', 'eServices'),
            Contract__c    = idContract,
            Subject        = sSubject,
            Description    = sDescription,
            Subcategory__c = ERROR_CASE_SUBCATEGORY,
            Status         = 'Open',
            Priority       = 'Low',
            Type           = 'Problem'
        );
    }

    /**
     * finish()
     */
    global void finish(Database.BatchableContext BC) {
    }

    global void setDebugLumenazaContractId(String lumenazaContractId) {
        this.debugLumenazaContractId = lumenazaContractId;
    }

    global void setPersistence(Boolean doPersist) {
        this.doPersist = doPersist;
    }

    private class LumenazaContractDeliveryBatchException extends Exception {}
}