/**
 * Case capture REST API
 *
 * v1.2.0   2018-07-30  Marko Schmalenbach          SOBCRM-1236
 *                                                  - Added rollback possibility with GET parameter "preventPersistence"
 *                                                  - Added return of created Case
 *                                                  - Added proper HTTP status on failure
 * v1.3.0   2018-09-07  Marko Schmalenbach          SOBCRM-1253
 *                                                  - Relate Battery by given Battery Serial Number
 *                                                  - Relate Contract by given Contract Number
 *                                                  - Relate Stock Item by given Battery Serial Number
 * v1.4.0   2019-02-04  Marko Schmalenbach          Save multiple attachments to the created Case by "_attachments"-key (SOBCRM-1316)
 *
 * @author Daniel Stange
 * @see LeadCaptureTests
 */
@RestResource(urlMapping='/case')

global without sharing class CaseCapture {

    private final static Integer MAX_ATTACHMENTS = 10;
    private final static String DEBUG_HEADER = 'CaseCapture.';

    @TestVisible
    private static List<String> listAttachmentsUnitTest;

    @HttpPost
    global static Response createCase() {

        final String DEBUG_HERE = DEBUG_HEADER + 'createCase() - ';
        Savepoint eineSchritteSuruck = Database.setSavepoint();

        Response oResponse = new Response();
        RestRequest oRestRequest = RestContext.request;

        Boolean bPreventPersistence = (oRestRequest.params.get('preventPersistence') == '1');
        System.debug(DEBUG_HERE + 'PERSISTENCE: ' + (bPreventPersistence ? 'OFF' : 'ON'));

        listAttachmentsUnitTest = null; // Reset

        try {

            Blob body = oRestRequest.requestBody;
            String bodyString = body.toString();

            Map<String, Object> mapRequest = (Map<String, Object>)JSON.deserializeUntyped(bodyString);

            // Get attachments
            List<String> listAttachments = new List<String>();

            if (mapRequest.containsKey('_attachments') && mapRequest.get('_attachments') instanceof List<Object>) {
                listAttachments = (List<String>)JSON.deserialize(JSON.serialize(mapRequest.get('_attachments')), List<String>.class);
                // Remove to be able to cast to Case below
                mapRequest.remove('_attachments');
                bodyString = JSON.serialize(mapRequest);
            }

            if (listAttachments.size() > MAX_ATTACHMENTS) {
                throw new CaseCaptureException('Exceeded maximum number of attachments ' + MAX_ATTACHMENTS);
            }

            Case oCase = (Case)JSON.deserialize(bodyString, Case.class);

            //--------------------------------------------------------------------------
            // Map given Battery Serial Number to an existing Asset
            //--------------------------------------------------------------------------
            String sBatterySerial;

            if (String.isNotBlank(oCase.BatterySerialNumberRequest__c)) {
                sBatterySerial = filterBatterySerialNumber(oCase.BatterySerialNumberRequest__c);
            }

            if (String.isBlank(oCase.Battery__c) && String.isNotBlank(oCase.BatterySerialNumberRequest__c)) {

                List<Asset> listFoundBatteryAssets = [SELECT Id, AccountId, ContactId FROM Asset WHERE SerialNumber = :sBatterySerial];

                if (listFoundBatteryAssets.size() == 1) {

                    Asset oBatteryAsset = listFoundBatteryAssets.get(0);
                    System.debug(DEBUG_HERE + 'Found Asset by Serial Number "' + sBatterySerial + '": ' + oBatteryAsset);

                    oCase.Battery__c = oBatteryAsset.Id;

                    // If Asset is related to an Account and/or an Contact and
                    // they are not set by the request set them on Case
                    // This is done on create by Process "New eService Case from Contract"
                    // if (String.isBlank(oCase.AccountId) && oBatteryAsset.AccountId != null) {
                    //     oCase.AccountId = oBatteryAsset.AccountId;
                    // }
                    // if (String.isBlank(oCase.ContactId) && oBatteryAsset.ContactId != null) {
                    //     oCase.ContactId = oBatteryAsset.ContactId;
                    // }
                }
            }

            //--------------------------------------------------------------------------
            // Map given Battery Serial Number to an existing StockItem__c
            //--------------------------------------------------------------------------
            if (String.isBlank(oCase.StockItem__c) && String.isNotBlank(oCase.BatterySerialNumberRequest__c)) {

                List<StockItem__c> listFoundStockItems = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = :sBatterySerial];

                if (listFoundStockItems.size() == 1) {
                    oCase.StockItem__c = listFoundStockItems.get(0).Id;
                }
            }

            //--------------------------------------------------------------------------
            // Map Contract Number to existing Contract
            //--------------------------------------------------------------------------
            if (String.isBlank(oCase.Contract__c) && String.isNotBlank(oCase.ContractNumberRequest__c)) {

                String sContractNumber = filterContractNumber(oCase.ContractNumberRequest__c);

                List<Contract> listFoundContracts = [SELECT Id, AccountId, CustomerSignedId FROM Contract WHERE ContractNumber = :sContractNumber];

                if (listFoundContracts.size() == 1) {

                    Contract oContract = listFoundContracts.get(0);
                    System.debug(DEBUG_HERE + 'Found Contract by Contract Number "' + oCase.ContractNumberRequest__c + '": ' + oContract);

                    oCase.Contract__c = oContract.Id;

                    // If Account and Contact aren't set yet set them on Case
                    // This is done on create by Process "New eService Case from Contract"
                    // if (String.isBlank(oCase.AccountId) && oContract.AccountId != null) {
                    //     oCase.AccountId = oContract.AccountId;
                    // }
                    // if (String.isBlank(oCase.ContactId) && oContract.CustomerSignedId != null) {
                    //     oCase.ContactId = oContract.CustomerSignedId;
                    // }
                }
            }

            insert oCase;

            //--------------------------------------------------------------------------
            // Save attachments (future callout)
            //--------------------------------------------------------------------------
            if (!listAttachments.isEmpty()) {

                if (!Test.isRunningTest()) {
                    saveAttachments(listAttachments, oCase.Id);
                }
                else {
                    listAttachmentsUnitTest = listAttachments;
                }
            }

            oResponse.caseid     = oCase.Id;
            oResponse.status     = 'Success';
            oResponse.message    = 'Case was created with Salesforce Case.Id ' + oCase.Id;
            oResponse.caseObject = oCase;
        }
        catch (Exception e) {

            oResponse.status  = 'Failure';
            oResponse.message = e.getMessage() + ' - ' + e.getStackTraceString();

            RestContext.response.statusCode = 500;
        }

        if (bPreventPersistence) {

            Database.rollback(eineSchritteSuruck);
            oResponse.message += ' - nothing stored: preventPersistence active';
            System.debug(DEBUG_HERE + 'Rollback performed');
        }

        return oResponse;
    }

    /**
     * Filter a Battery Serial Number
     *
     * @param serialNumber
     *
     * @return
     */
    @TestVisible
    static private String filterBatterySerialNumber(String serialNumber) {

        serialNumber = String.isBlank(serialNumber) ? '' : serialNumber;
        return serialNumber.replaceAll('[^0-9]', '');
    }

    /**
     * Filter a Contract Number
     *
     * @param contractNumber
     *
     * @return
     */
    @TestVisible
    static private String filterContractNumber(String contractNumber) {

        contractNumber = String.isBlank(contractNumber) ? '' : contractNumber;

        return contractNumber
            .replaceAll('[^0-9]', '') // only numbers
            .replaceAll('^0+', '')    // trim all leading zeros ...
            .leftPad(8, '0');         // ... and pad with 0 to 8 digits (longer works too!)
    }

    /**
     * Future callout
     *
     * Save given list of URLs as attachment to the given case
     * NOTICE: To attach files the class must be without sharing as the
     * Owner of the case is likely to be changed after creation!
     *
     *
     * @param listAttachmentUrls
     * @param idCase
     */
    @TestVisible
    @future(callout=true)
    static private void saveAttachments(List<String> listAttachmentUrls, Id idCase) {

        final String DEBUG_HERE = DEBUG_HEADER + 'saveURLAsAttachment() - ';

        if (listAttachmentUrls.isEmpty()) {
            return;
        }

        List<String> listErrors = new List<String>();
        List<Attachment> listAttachments = new List<Attachment>();

        for (String sAttachmentUrl : listAttachmentUrls) {

            sAttachmentUrl = sAttachmentUrl.replace(' ', '%20');

            String sFileName = sAttachmentUrl.substringAfterLast('/');

            HttpRequest request = new HttpRequest();
            request.setEndpoint(sAttachmentUrl);
            request.setMethod('GET');
            request.setTimeout(6000);

            Http http = new Http();

            System.debug(DEBUG_HERE + 'Calling ' + sAttachmentUrl);

            // Set mock in test mode
            if (Test.isRunningTest()) {
                Test.setMock(HttpCalloutMock.class, new AttachmentLoaderMockDispatcher());
            }

            try {
                HttpResponse response = http.send(request);
                Blob attachmentBlob = response.getBodyAsBlob();

                System.debug(DEBUG_HERE + 'Response: ' + response);
                System.debug(DEBUG_HERE + 'Attachment size: ' + attachmentBlob.size());

                if (attachmentBlob != null) {
                    listAttachments.add(new Attachment(
                        Name        = sFileName,
                        Body        = attachmentBlob,
                        ParentId    = idCase,
                        Description = 'Source-URL: ' + sAttachmentUrl
                    ));
                }
            }
            catch (Exception e) {
                System.debug(DEBUG_HERE + 'Exception: ' + e);
                listErrors.add(sAttachmentUrl + ': ' + e.getMessage());
            }
        }

        if (!listAttachments.isEmpty()) {
            try {
                insert listAttachments;
            }
            catch (Exception e) {
                listErrors.add('Couldn\'t save attachments: ' + e.getMessage());
            }
        }

        if (!listErrors.isEmpty()) {
            Case errorCase = new Case();
            errorCase.Subject = 'Error on downloading attachment' + (listErrors.size()>1 ? 's' : '');
            errorCase.Description = String.join(listErrors, '\n');
            errorCase.ParentId = idCase;
            insert errorCase;
        }
    }

    /**
     * Mock class for callout method saveURLAsAttachment()
     *
     * @see saveURLAsAttachment()
     */
    global class AttachmentLoaderMockDispatcher implements HttpCalloutMock {

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

    /**
     * Response class
     */
    global class Response {
        public String status;
        public String message;
        public String caseid;
        public Case caseObject;
    }

    global class CaseCaptureException extends Exception {}
}