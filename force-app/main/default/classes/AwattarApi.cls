/**
 * AwattarApi
 *
 * Class for handling Awattar callouts
 *
 * Changelog
 * ---------
 *
 * v2.0.1-2018-01-11 (marko@die-interaktiven.de)
 * - initObjectAction(): Lock action to prevent redundant callouts
 *
 * v2.0.0-2017-10-09 (marko@die-interaktiven.de)
 * - Complete revision with initAction method which makes enqueuing
 *   more flexible
 * - Implemented method triggerEmailToCustomerForContract() (SOBCRM-1034)
 *
 * v1.0.0-2017-08-01
 * - Initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 2.0.1-2018-01-11
 */
public class AwattarApi implements Queueable, Database.AllowsCallouts {

    private static final String DEBUG_HEADER = 'AwattarApi.';
    public static final String settingsName = 'API';

    private String objectAction;
    private String environment;
    private String apiBaseUrl;
    private String apiToken;

    private AwattarApiResponse lastResponse;
    private AwattarApiResponse lastContractChangeCheckResponse;

    public Set<AwattarObject> awattarObjects = new Set<AwattarObject>();

    private AwattarSettings__c settings;

    public Map<String,String> lastCalloutValues = new Map<String,String>();

    /**
     * Constructor without argument
     */
    public AwattarApi() {
        this(FALSE);
    }

    /**
     * Constructor
     */
    public AwattarApi(Boolean forceLiveEnvironment) {

        // Get setting
        this.settings = AwattarSettings__c.getValues(settingsName);

        if (this.settings == NULL) {
            throw new AwattarApiException('Awattar API - settings with name "' + settingsName + '" not found');
        }
        if (this.settings.APIDoSync__c == false) {
            throw new AwattarApiException('Awattar API - Use of API is halted, ApiDoSync__c is not activated!');
        }

        // Set URL and credentials
        if (forceLiveEnvironment || (this.settings.APIUseLive__c && !DiaUtilities.orgIsSandbox())) {
            this.environment = 'LIVE';
            this.apiBaseUrl = this.settings.APILiveUrl__c;
            this.apiToken   = this.settings.APILiveToken__c;
        }
        else {
            this.environment = 'TEST';
            this.apiBaseUrl = this.settings.APITestUrl__c;
            this.apiToken   = this.settings.APITestToken__c;
        }

        if (this.apiBaseUrl == NULL || this.apiBaseUrl.length() < 10) {
            throw new AwattarApiException('Awattar API URL for environment "' + this.environment + '" not defined');
        }
        if (this.apiToken == NULL) {
            throw new AwattarApiException('Awattar API Token for environment "' + this.environment + '" not defined');
        }
    }

    /**
     * Returns if sync is activated
     */
    public static Boolean isSyncActive() {

        AwattarSettings__c settings = AwattarSettings__c.getValues(settingsName);

        if (settings == NULL || settings.APIDoSync__c == false) {
            return false;
        }
        return true;
    }

    /**
     * Upserts a Lumeneza Contract
     */
    public AwattarApiResponse upsertContract(AwattarContract awattarContract) {

        String DEBUG_HERE = DEBUG_HEADER + 'upsertContract() - ';

        System.debug(DEBUG_HERE + 'AwattarContract: ' + awattarContract);

        Map<String,Object> mapAwattarFields = awattarContract.getAwattarFields();

        String idContract = awattarContract.getAwattarContractId();
        String sUpsertMode = awattarContract.getUpsertMode();

        String endpoint = '/v1/contracts';
        String method = 'POST';

        // Update
        if (sUpsertMode == 'update') {
            endpoint += '/' + idContract;
        }

        // Convert mapAwattarFields to JSON
        String requestJson = JSON.serialize(mapAwattarFields);

        return this.callout(endpoint, method, requestJson);
    }

    /**
     * Triggers the email to customer
     */
    public AwattarApiResponse triggerEmailToCustomerForContract(AwattarContract awattarContract) {

        String DEBUG_HERE = DEBUG_HEADER + 'triggerEmailToCustomerForContract() - ';

        System.debug(DEBUG_HERE + 'AwattarContract: ' + awattarContract);

        String endpoint = '/v1/contracts/' + awattarContract.getAwattarContractId() + '/mail';
        String method = 'POST';

        return this.callout(endpoint, method);
    }

    /**
     * Make a callout
     */
    private AwattarApiResponse callout(String endpoint, String method, String postParameters, String getParameters, Map<String,String> headers) {

        String DEBUG_HERE = 'callout() - ';

        String restUrl = this.apiBaseUrl + endpoint + (getParameters.length() > 0 ? '?' + getParameters : '');

        headers.put('Accept', 'application/json');
        headers.put('Content-Type', 'application/json');
        headers.put('Authorization',  'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(this.apiToken + ':')));

        AwattarApiResponse awattarResponse = new AwattarApiResponse();
        this.lastResponse = awattarResponse;

        // Set request info
        awattarResponse.requestInfo = method + ' call on ' + restUrl + ((postParameters != NULL && postParameters.length() > 0) ? ' with POST parameters: ' + postParameters : '');

        System.debug(DEBUG_HERE + awattarResponse.requestInfo);

        this.lastCalloutValues.put('endpoint', endpoint);
        this.lastCalloutValues.put('method', method);
        this.lastCalloutValues.put('postParameters', postParameters);
        this.lastCalloutValues.put('info', awattarResponse.requestInfo);

        try {

            // Set mock in test mode
            if (Test.isRunningTest() == true) {
                Test.setMock(HttpCalloutMock.class, new AwattarRestApiMockDispatcher());
            }

            RESTClient restClient = new RESTClient(restUrl, method, headers, postParameters);
            awattarResponse.setResponse(restClient.response);
        }
        catch (Exception e) {
            awattarResponse.setResponse('Exception in callout() at line ' + e.getLineNumber() + ' with ' + awattarResponse.requestInfo + ': ' + e.getMessage() + ' (' + e.getStackTraceString() + '); HTTP Headers were: ' + headers);
        }

        return awattarResponse;
    }

    /**
     * Make callout alias
     */
    private AwattarApiResponse callout(String endpoint, String method, String parameters, Map<String,String> headers) {

        AwattarApiResponse awattarResponse = new AwattarApiResponse();
        method = method.toUpperCase();

        if (method == 'POST' || method == 'PUT') {
            awattarResponse = this.callout(endpoint, method, parameters, '', headers);
        }
        else if (method == 'GET') {
            awattarResponse = this.callout(endpoint, method, '', parameters, headers);
        }
        else {
            awattarResponse.setResponse('Unhandled method "' + method + '"');
        }

        return awattarResponse;
    }

    /**
     * Make callout alias
     */
    private AwattarApiResponse callout(String endpoint, String method, String parameters) {
        return this.callout(endpoint, method, parameters, new Map<String,String>());
    }

    /**
     * Make callout alias
     */
    private AwattarApiResponse callout(String endpoint, String method) {
        return this.callout(endpoint, method, '', new Map<String,String>());
    }

    /**
     * Init an action on an AwattarObject
     */
    public static Boolean initObjectAction(Set<AwattarObject> awattarObjects, String action) {


        String DEBUG_HERE = DEBUG_HEADER + 'initObjectAction() - ';

        if (isSyncActive() == FALSE) {
            System.debug(DEBUG_HERE + 'Sync is not active, skipping upsert (see isSyncActive())');
            return FALSE;
        }

        System.debug(DEBUG_HERE + 'Enqueue ' + awattarObjects.size() + ' object(s) for action "' + action + '"');

        Set<AwattarObject> lsetObjectsToHandle = new Set<AwattarObject>();
        Integer iCountErrors = 0;

        // Iterate over Awattar objects and prepare
        for (AwattarObject awattarObjectToHandle : awattarObjects) {

            String sResult = awattarObjectToHandle.prepareAction(action);

            if (sResult != AwattarObject.ACTION_STATUS_NOT_REQUIRED) {

                if (sResult == AwattarObject.ACTION_STATUS_OK) {
                    // Lock action for object
                    awattarObjectToHandle.lock(action);
                    lsetObjectsToHandle.add(awattarObjectToHandle);
                }
                else {
                    iCountErrors++;
                }
            }
        }

        if (iCountErrors == 0) {

            // Enqueue objects
            if (lsetObjectsToHandle.size() > 0) {
                System.debug(DEBUG_HERE + 'Enqueued ' + lsetObjectsToHandle.size() + ' object(s)');
                AwattarApi oAwattarApi = new AwattarApi();
                oAwattarApi.awattarObjects = lsetObjectsToHandle;
                oAwattarApi.objectAction = action;
                System.enqueueJob(oAwattarApi);
            }

            return TRUE;
        }

        System.debug(DEBUG_HERE + 'Return with ' + iCountErrors + ' validation errors on ' + (lsetObjectsToHandle.size()) + ' AwattarObjects');
        return FALSE;
    }

    /**
     * Queuable method "execute"
     */
    public void execute(QueueableContext context) {

        String DEBUG_HERE = 'execute() - ';

        if (this.awattarObjects.size() == 0) {
            System.debug(DEBUG_HERE + 'No AwattarObjects to handle');
            return;
        }

        System.debug(DEBUG_HERE + 'Current objects ' + this.awattarObjects);

        for (AwattarObject oAwattarObject : this.awattarObjects) {
            oAwattarObject.initAction(this.objectAction);
            this.awattarObjects.remove(oAwattarObject);
            break;
        }

        // Move on if there are contract IDs left
        if (this.awattarObjects.size() == 0) {
            System.debug(DEBUG_HERE + 'No more objects to process');
            return;
        }

        System.debug(DEBUG_HERE + 'Objects left to process ' + this.awattarObjects.size());
        System.enqueueJob(this);
    }


    /**
     * Returns last callout info
     *
     * @return Map<String,String> Info
     */
    public Map<String,String> getLastCalloutInfo() {
        return this.lastCalloutValues;
    }

    public class AwattarApiException extends Exception {}
    
    /**
     * Response of an AwattarApi call
     */
    public class AwattarApiResponse {

        public String requestInfo = '';
        public Boolean success = false;
        public Map<String,Object> resultMap;
        public HttpResponse response;
        public String error = 'Unknown error';
        public String responseBody = '';

        public AwattarApiResponse() {
        }

        public void setResponse(String error) {
            this.success = false;
            this.error = error;
        }

        public void setResponse(Exception e) {
            this.success = false;
            this.error = e.getMessage();
        }

        public void setResponse(HttpResponse response) {

            this.success = (response.getStatusCode() >= 200 && response.getStatusCode() < 300);
            this.response = response;

            if (this.success == TRUE) {

                this.responseBody = response.getBody();

                // Try JSON
                try {
                    this.resultMap = (Map<String,Object>)JSON.deserializeUntyped(this.responseBody);
                    this.error = '';
                }
                // If not then screw
                catch (Exception e) {
                    this.error = 'Unknown format (no JSON, ' + e.getMessage() + ')';
                }
            }
            else {
                this.error = response.getBody();
            }
            System.debug(response);
        }
    }
}