/**
 * Lumenaza API
 *
 * Class for handling Lumenaza callouts
 *
 * Changelog
 * ---------
 *
 * v1.8.1   2019-06-11  Marko Schmalenbach          initUpsert(): Added check for Queueable limit in asynchronous modus
 *                                                  as number of Queueables is then limited to 1. This will now create a
 *                                                  Case with the hint to update the object manually (cause: SOBCRM-1325)
 * v1.8.0-2018-04-10 (marko@die-interaktiven.de)
 * - Added contract change functionality (SOBCRM-1164)
 *
 * v1.7.0 (MSB 2018-03-28)
 * - upsertMeter(): Use of LumenazaMeterInstallation.toTypedLumenazaFields
 *   to provide typed JSON (SOBCRM-1050)
 *
 * v1.6.0 (MSB 2017-11-09)
 * - Added upsertMeter() (SOBCRM-1050)
 *
 * v1.6.0 (MSB 2017-12-05)
 * - initUpsert(): Lock LumenazaObject to prevent redundant callouts
 *
 * v1.5.0 (MSB 2017-06-20)
 * - Added fetchInvoices() (SOBCRM-705)
 * - Test environment is forced if Sandbox Org is detected even if
 *   settings.ApiUseTest__c is not set to avoid live pollution
 * - Added option to force live environment in constructor
 *
 * v1.4.0 (MSB 2016-12-16)
 * - upsertContract(): Implemented adding new Contracts to existing
 *   Lumenaza Customers (SOBCRM-763)
 *
 * v1.3.0 (MSB 2016-12-14)
 * - initUpsert(): Added handling of custom upsert of Lumenaza
 *   objects (currently used only for Contracts) (SOBCRM-669)
 * - Added addChange() for adding a Contract change
 * - LumenazaApiResponse: Success only given now if status >= 200
 *   and < 300
 *
 * v1.2.0 (MSB 2016-10-06)
 * - Implemented revokation of contract (SOBCRM-668)
 *
 * v1.1.0 (MSB 2016-10-05)
 * - Revised callouts for Bonus and Contract due to switch
 *   to Lumenaza API v3 (SOBCRM-666 and SOBCRM-667)
 *
 * v1.0.0
 * - Initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.8.0-2018-04-10
 */
public class LumenazaApi implements Queueable, Database.AllowsCallouts {

    private static final String DEBUG_HEADER = 'LumenazaApi';
    public static final String settingsName = 'api';

    private String environment;
    private String apiBaseUrl;
    private String apiUsername;
    private String apiPassword;
    private String apiAuthClient; // Basic auth!
    private String apiAuthSecret; // Basic auth!
    private String apiToken;
    private String apiRefreshToken;
    private Datetime apiTokenExpiration;

    private String authEndpoint = '/oauth/token/';

    private LumenazaApiResponse lastResponse;
    private LumenazaApiResponse lastContractChangeCheckResponse;

    public Set<LumenazaObject> lumenazaObjects = new Set<LumenazaObject>();
    public String queueAction;

    private LumenazaSettings__c settings;

    public Map<String,String> lastCalloutValues = new Map<String,String>();

    /**
     * Constructor without argument
     */
    public LumenazaApi() {
        this(FALSE);
    }

    /**
     * Constructor
     */
    public LumenazaApi(Boolean forceLiveEnvironment) {

        // Get setting
        this.settings = LumenazaSettings__c.getValues(settingsName);

        if (this.settings == NULL) {
            throw new LumenazaApiException('Lumenaza API - settings with name "' + settingsName + '" not found');
        }
        if (this.settings.ApiDoSync__c == false) {
            throw new LumenazaApiException('Lumenaza API - Use of API is halted, ApiDoSync__c is not activated!');
        }

        if (!forceLiveEnvironment && (DiaUtilities.orgIsSandbox() || this.settings.ApiUseTest__c == TRUE)) {
            this.environment = 'TEST';
            this.apiBaseUrl         = this.settings.ApiTestUrl__c;
            this.apiUsername        = this.settings.ApiTestUsername__c;
            this.apiPassword        = this.settings.ApiTestPassword__c;
            this.apiAuthClient		= this.settings.ApiTestAuthClient__c;
            this.apiAuthSecret		= this.settings.ApiTestAuthSecret__c;
            //this.apiToken           = this.settings.ApiTestToken__c;
            //this.apiRefreshToken    = this.settings.ApiTestRefreshToken__c;
            //this.apiTokenExpiration = this.settings.ApiTestTokenExpiration__c;
        }
        else {
            this.environment = 'LIVE';
            this.apiBaseUrl         = this.settings.ApiLiveUrl__c;
            this.apiUsername        = this.settings.ApiLiveUsername__c;
            this.apiPassword        = this.settings.ApiLivePassword__c;
            this.apiAuthClient		= this.settings.ApiLiveAuthClient__c;
            this.apiAuthSecret		= this.settings.ApiLiveAuthSecret__c;
            //this.apiToken           = this.settings.ApiLiveToken__c;
            //this.apiRefreshToken    = this.settings.ApiLiveRefreshToken__c;
            //this.apiTokenExpiration = this.settings.ApiLiveTokenExpiration__c;
        }

        if (this.apiBaseUrl == NULL || this.apiBaseUrl.length() < 10) {
            throw new LumenazaApiException('Lumenaza API URL for environment "' + this.environment + '" not defined');
        }
        if (this.apiUsername == NULL) {
            throw new LumenazaApiException('Lumenaza API Username for environment "' + this.environment + '" not defined');
        }
        if (this.apiPassword == NULL) {
            throw new LumenazaApiException('Lumenaza API Password for environment "' + this.environment + '" not defined');
        }
    }

    /**
     * Returns if sync is activated
     */
    public static Boolean isSyncActive() {

        LumenazaSettings__c settings = LumenazaSettings__c.getValues(settingsName);

        if (settings == NULL || settings.ApiDoSync__c == false) {
            return false;
        }
        return true;
    }

    /**
     * Adds a Lumeneza Bonus
     */
    public LumenazaApiResponse addBonus(LumenazaBonus lumenazaBonus) {

        System.debug('LumenazaApi - addBonus() with ' + lumenazaBonus);

        Map<String,Object> lumenazaFields = lumenazaBonus.getLumenazaFields();
        String contractId = lumenazaBonus.getLumenazaContractId();
        String consumerId = lumenazaBonus.getLumenazaCustomerId();

        // String endpoint = '/v2/consumer/' + contractId + '/add_bonus/';
        String endpoint = '/v3/consumers/' + consumerId + '/contracts/' + contractId + '/add_bonus/';

        String method = 'POST';

        // Convert lumenazaFields to JSON
        String requestJson = JSON.serialize(this.removeNullFieldValues(lumenazaFields));
        System.debug('LumenazaApi - Make callout on ' + endpoint + ' with body ' + requestJson);
        return this.callout(endpoint, method, requestJson);
    }

    /**
     * Adds a Contract Change
     */
    public LumenazaApiResponse addChange(LumenazaChange lumenazaChange) {

        String sDebugHere = DEBUG_HEADER + '.addChange() - ';

        System.debug(sDebugHere + 'with ' + lumenazaChange);

        Map<String,Object> lumenazaFields = lumenazaChange.getLumenazaFields();
        String endpoint = '/v3/master_data/changes/';
        String method = 'POST';

        // Convert lumenazaFields to JSON
        String requestJson = JSON.serialize(this.removeNullFieldValues(lumenazaFields));
        System.debug(sDebugHere + 'Make callout on ' + endpoint + ' with body ' + requestJson);
        return this.callout(endpoint, method, requestJson);
    }

    /**
     * Adds a Contract Change
     */
    public LumenazaApiResponse checkChange(LumenazaChange lumenazaChange) {

        String sDebugHere = DEBUG_HEADER + '.checkChange() - ';
        System.debug(sDebugHere + 'with ' + lumenazaChange);

        Map<String,Object> lumenazaFields = lumenazaChange.getLumenazaFields();
        String endpoint = '/v3/master_data/changes/';
        String method = 'GET';

        // Cache response as callout returns a list with all changes
        if (lastContractChangeCheckResponse == NULL) {
            System.debug(sDebugHere + 'Make callout on ' + endpoint);
            lastContractChangeCheckResponse = this.callout(endpoint, method);
        }
        else {
            System.debug(sDebugHere + 'Return last cached callout response for ' + endpoint);
        }

        return lastContractChangeCheckResponse;
    }

    /**
     * Fetches invoices for specified year and month
     */
    public LumenazaApiResponse fetchInvoices(String type, Integer year, Integer month) {

        String sDebugHere = DEBUG_HEADER + '.fetchInvoices() for type ' + type + ' - ';
        String sType = type.toLowerCase();

        if (sType != 'bill' && sType != 'summarized') {
            throw new LumenazaApiException('Type has to be either "bill" or "summarized"');
        }

        String sYear  = String.valueOf(year);
        String sMonth = String.valueOf(month);
        sMonth = month < 10 ? '0' + sMonth : sMonth;

        String endpoint = '/v3/bss_documents/customer_statistics/' + sType + '/' + sYear + '/' + sMonth + '/';
        String method = 'GET';

        // Cache response as callout returns a list with all changes
        System.debug(sDebugHere + 'Make callout on ' + endpoint);

        return this.callout(endpoint, method);
    }

    /**
     * Fetches Contract information
     */
    public LumenazaApiResponse fetchContractInfo(String customerId, String contractId) {

        String sDebugHere = DEBUG_HEADER + '.fetchContractInfo() - ';

        String endpoint = '/v3/consumers/' + customerId + '/contracts/' + contractId + '/';
        String method = 'GET';

        // Cache response as callout returns a list with all changes
        System.debug(sDebugHere + 'Make callout on ' + endpoint);

        return this.callout(endpoint, method);
    }

    /**
     * Upserts a Lumenaza Contract
     */
    public LumenazaApiResponse upsertContract(LumenazaContract oLumenazaContract) {

        String sDebugHere = DEBUG_HEADER + '.upsertContract() - ';

        System.debug(sDebugHere + 'LumenazaContract: ' + oLumenazaContract);

        Map<String,Object> lumenazaFields = oLumenazaContract.getLumenazaFields();

        String customerId = oLumenazaContract.getLumenazaCustomerId();
        String contractId = oLumenazaContract.getLumenazaContractId();

        String sUpsertMode = oLumenazaContract.getUpsertMode();

        String endpoint = '/v3/consumers/';
        String method = 'POST';
        String requestJson;

        // Contract change (since 2018-04-04, SOBCRM-1164)
        if (oLumenazaContract.getSpecialAction() == LumenazaContract.SPECIAL_ACTION_CONTRACT_CHANGE) {

            System.debug(sDebugHere + 'Special action "' + LumenazaContract.SPECIAL_ACTION_CONTRACT_CHANGE + '"');

            contractId = oLumenazaContract.getLumenazaPreviousContractId();
            customerId = oLumenazaContract.getLumenazaPreviousCustomerId();

            if (contractId == null || contractId.length() == 0) {
                throw new LumenazaApiException('Lumenaza API - action "' + LumenazaContract.SPECIAL_ACTION_CONTRACT_CHANGE + '" needs the previous Lumenaza Contract ID');
            }
            if (customerId == null || customerId.length() == 0) {
                throw new LumenazaApiException('Lumenaza API - action "' + LumenazaContract.SPECIAL_ACTION_CONTRACT_CHANGE + '" needs a Lumenaza Customer ID');
            }

            method = 'PUT';
            endpoint += customerId + '/contracts/' + contractId + '/contract_change/';

            // Convert lumenazaFields to JSON
            requestJson = JSON.serialize(this.removeNullFieldValues(lumenazaFields));
        }
        // Update
        else if (sUpsertMode == 'update') {

            if (oLumenazaContract.getSpecialAction() == LumenazaContract.SPECIAL_ACTION_REVOKE) {

                System.debug(sDebugHere + 'Special action "' + LumenazaContract.SPECIAL_ACTION_REVOKE + '"');

                if (contractId == NULL || contractId.length() == 0) {
                    throw new LumenazaApiException('Lumenaza API - action "revoke" needs also the Lumenaza Contract ID');
                }
                if (customerId == NULL || customerId.length() == 0) {
                    throw new LumenazaApiException('Lumenaza API - action "revoke" needs also the Lumenaza Customer ID');
                }

                // since 2016-10-06 (SOBCRM-668)
                endpoint += customerId + '/contracts/' + contractId + '/revoke/';
            }
            else {
                // Update is deprecated as changes to master data are very
                // complex an changes cannot be committed immediately as
                // one or more further systems are in account and respond
                // asynchronously. This is do be done later via /v3/master_data/changes/
                // (see SOBCRM-667)
                //endpoint += customerId + '/';
                //method = 'PUT';
                throw new LumenazaApiException('Lumenaza API - updating an existing contract is currently not possible (SOBCRM-667)');
            }
        }
        // Insert
        else if (sUpsertMode == 'insert' || sUpsertMode == 'insertForExistingCustomer') {

            // since v1.4.0
            if (sUpsertMode == 'insertForExistingCustomer') {

                String existingCustomerId = oLumenazaContract.getLumenazaCustomerIdOfExistingContract();

                if (existingCustomerId == NULL || existingCustomerId.length() == 0) {
                    throw new LumenazaApiException('Lumenaza API - For adding another Contract to an existing Customer the existing Lumenaza Customer ID must be given');
                }

                endpoint += existingCustomerId + '/contracts/add_contract/';
            }
            else {
                endpoint += 'create/';
            }

            // Convert lumenazaFields to JSON
            requestJson = JSON.serialize(this.removeNullFieldValues(lumenazaFields));
        }
        else {
            throw new LumenazaApiException('Lumenaza API - Unhandled upsertMode "' + sUpsertMode + '" for LumenazaContract');
        }

        System.debug('LumenazaApi - Make callout on ' + endpoint + ' with body ' + requestJson);

        return this.callout(endpoint, method, requestJson);
    }

    /**
     * Upserts a Lumeneza Meter data
     *
     * @since 2017-11-09 (SOBCRM-1050)
     */
    public LumenazaApiResponse upsertMeter(LumenazaMeterInstallation oLumenazaMeterInstallation) {

        String DEBUG_HERE = DEBUG_HEADER + '.upsertMeter() - ';

        System.debug(DEBUG_HERE + 'LumenazaMeterInstallation: ' + oLumenazaMeterInstallation);

        Map<String,Object> lumenazaFields = oLumenazaMeterInstallation.getLumenazaFields();

        String endpoint = '/v3/meter/create/';
        String method = 'POST';
        String requestJson;

        // Convert lumenazaFields to JSON
        requestJson = JSON.serialize(this.removeNullFieldValues(lumenazaFields));

        System.debug(DEBUG_HERE + 'Make callout on ' + endpoint + ' with body ' + requestJson);

        //return new LumenazaApiResponse().setResponse('CALLOUT STOP');

        return this.callout(endpoint, method, requestJson);
    }

    /**
     * Remove NULL field values
     */
    private Map<String,Object> removeNullFieldValues(Map<String,Object> valueMap) {

        for (String fieldName : valueMap.keySet()) {
            if (valueMap.get(fieldName) == null) {
            	valueMap.remove(fieldName);
            }
        }
        return valueMap;
    }

    /**
     * Callout
     */
    private LumenazaApiResponse callout(String endpoint, String method, String postParameters, String getParameters, Map<String,String> headers) {

        String DEBUG_HERE = DEBUG_HEADER + '.callout() - ';
        String restUrl = this.apiBaseUrl + endpoint + (getParameters.length() > 0 ? '?' + getParameters : '');

        headers.put('Accept', 'application/json');

        // If endpoint is not auth endpoint then get token
        // and attach it to header
        if (endpoint != this.authEndpoint) {

            String token = this.getToken();

            if (token.length() == 0) {
                return this.lastResponse;
            }

            headers.put('Content-Type', 'application/json');
            headers.put('Authorization', 'Bearer ' + token);
        }

        LumenazaApiResponse lumenazaResponse = new LumenazaApiResponse();
        this.lastResponse = lumenazaResponse;

        // Set request info
        lumenazaResponse.requestInfo = method + ' call on ' + restUrl + ((postParameters != NULL && postParameters.length() > 0) ? ' with POST parameters: ' + postParameters : '');

        this.lastCalloutValues.put('endpoint', endpoint);
        this.lastCalloutValues.put('method', method);
        this.lastCalloutValues.put('postParameters', postParameters);
        this.lastCalloutValues.put('info', lumenazaResponse.requestInfo);

        try {

            // Set mock in test mode
            if (Test.isRunningTest() == true) {
                System.debug(DEBUG_HERE + 'Call test mock with ' + lumenazaResponse.requestInfo);
                Test.setMock(HttpCalloutMock.class, new LumenazaRestApiMockDispatcher());
            }

        	RESTClient restClient = new RESTClient(restUrl, method, headers, postParameters);
            lumenazaResponse.setResponse(restClient.response);
        }
        catch (Exception e) {
            lumenazaResponse.setResponse('Exception in callout() at line ' + e.getLineNumber() + ' with ' + lumenazaResponse.requestInfo + ': ' + e.getMessage() + ' (' + e.getStackTraceString() + '); HTTP Headers were: ' + headers);
        }

        return lumenazaResponse;
    }

    /**
     *
     */
    private LumenazaApiResponse callout(String endpoint, String method, String parameters, Map<String,String> headers) {

        LumenazaApiResponse lumenazaResponse = new LumenazaApiResponse();
        method = method.toUpperCase();

        if (method == 'POST' || method == 'PUT') {
            lumenazaResponse = this.callout(endpoint, method, parameters, '', headers);
        }
        else if (method == 'GET') {
            lumenazaResponse = this.callout(endpoint, method, '', parameters, headers);
        }
        else {
			lumenazaResponse.setResponse('Unhandled method "' + method + '"');
        }

        return lumenazaResponse;
    }

    /**
     *
     */
    private LumenazaApiResponse callout(String endpoint, String method, String parameters) {
        return this.callout(endpoint, method, parameters, new Map<String,String>());
    }

    /**
     *
     */
    private LumenazaApiResponse callout(String endpoint, String method) {
        return this.callout(endpoint, method, '', new Map<String,String>());
    }

    /**
     * Enqueue LumenazaObjects for upsert
     *
     * @param Set<LumenazaObject> Set of Objects to upsert
     */
    public static Boolean initUpsert(Set<LumenazaObject> lumenazaObjects) {

        String debugHere = DEBUG_HEADER + '.initUpsert() - ';

        if (isSyncActive() == false) {
            System.debug(debugHere + 'Sync is not active, skipping upsert (see isSyncActive())');
            return false;
        }

        Integer errors = 0;
        Set<LumenazaObject> objectsToUpsert = new Set<LumenazaObject>();
        Set<LumenazaObject> objectsWithCustomUpsert = new Set<LumenazaObject>();

        System.debug(debugHere + 'Lumenaza objects: ' + lumenazaObjects);

        // Iterate over Lumenaza objects and validate
        for (LumenazaObject oLumenazaObject : lumenazaObjects) {

            // If upsert should be done by object itsself
            if (oLumenazaObject.hasCustomUpsert()) {
                System.debug(debugHere + 'Object handles its own upsert');
                if (oLumenazaObject.customUpsert() == FALSE) {
                    errors++;
                }
                else {
                    objectsWithCustomUpsert.add(oLumenazaObject);
                }
            }
            // Default upsert
            else {

                System.debug(debugHere + 'Doing default upsert');

                if (oLumenazaObject.needsUpdate() == TRUE) {
                    if (oLumenazaObject.validate() == TRUE) {
                        oLumenazaObject.lock('upsert');
                        objectsToUpsert.add(oLumenazaObject);
                    }
                    else {
                        errors++;
                    }
                }
                else {
                    System.debug(debugHere + 'Object with ID "' + oLumenazaObject.sObjectId + '" needs no update');
                }
            }
        }

        // Enqueue LumenazaObjects for upsert
        if (errors == 0) {

            if (objectsToUpsert.size() > 0) {

                if (isAsync() && Limits.getLimitQueueableJobs() == Limits.getQueueableJobs()) {
                    System.debug(debugHere + 'No more Queueable Jobs left! Limit: ' + Limits.getLimitQueueableJobs() + ', current queued: ' + Limits.getQueueableJobs());
                    System.debug(debugHere + 'Objects have to be upserted manually: ' + objectsToUpsert);
                    insert new Case(
                        RecordTypeId   = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Case', 'eServices'),
                        Subject        = 'Internal error on synchronizing objects to Lumenaza',
                        Description    = 'In asynchronous mode there cannot be more then ' + Limits.getLimitQueueableJobs() + ' Queueables at the same time.' +
                                         'Please update these objects manually:\n\n' + objectsToUpsert,
                        Status         = 'Open',
                        Priority       = 'Low',
                        Type           = 'Problem'
                    );
                    return true;
                }

                System.debug(debugHere + 'Enqueued ' + objectsToUpsert.size() + ' object(s) for default upsert');
                LumenazaApi lumenazaApi = new LumenazaApi();
                lumenazaApi.lumenazaObjects = objectsToUpsert;
                lumenazaApi.queueAction = 'upsert';
                System.enqueueJob(lumenazaApi);
            }

            if (!objectsWithCustomUpsert.isEmpty()) {

                System.debug(debugHere + 'Handled ' + objectsWithCustomUpsert.size() + ' object(s) with custom upsert, call processObjectsForUpsert() now');

                // For Lumenaza objects of the same type SObjects to upsert are
                // colleted in a static member property which than is processes
                // by the method processObjectsForUpsert() of the object
                new List<LumenazaObject>(objectsWithCustomUpsert).get(0).processObjectsForUpsert();
            }

            return TRUE;
        }
        else {
        	System.debug(debugHere + 'Return with ' + errors + ' validation errors on ' + (objectsToUpsert.size() + objectsWithCustomUpsert.size()) + ' LumenazaObjects');
        }

        return FALSE;
    }

    /**
     * Check on asynchronous context
     *
     * @return
     */
    public static Boolean isAsync() {
        return System.isBatch() || System.isQueueable() || System.isScheduled() || System.isFuture();
    }

    /**
     * Queueable method "execute"
     */
    public void execute(QueueableContext context) {

        if (this.queueAction == NULL || this.queueAction != 'upsert') {
            System.debug('LumenazaApi - execute(): Queue action must be \'upsert\'');
            return;
        }
        if (this.lumenazaObjects.size() == 0) {
            System.debug('LumenazaApi - execute(): No LumenazaObjects to handle');
            return;
        }

        System.debug('LumenazaApi - execute(): Current objects ' + this.lumenazaObjects);

        for (LumenazaObject oLumenazaObject : this.lumenazaObjects) {
            oLumenazaObject.initFutureUpsert();
            this.lumenazaObjects.remove(oLumenazaObject);
            break;
        }

        // Move on if there are contract IDs left
        if (this.lumenazaObjects.size() == 0) {
        	System.debug('LumenazaApi - execute(): No more objects to process');
            return;
        }

        System.debug('LumenazaApi - execute(): Objects left to process ' + this.lumenazaObjects.size());
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

    /**
     * Get an auth token if none exists
     *
     * @return String The token
     */
    private String getToken() {

        String token = '';

        Boolean hasToken     = (this.apiToken != NULL && this.apiToken.length() > 0);
        Boolean tokenExpired = (this.apiTokenExpiration == NULL || this.apiTokenExpiration.getTime() <= (Datetime.now().getTime()-60));

        if (hasToken && !tokenExpired) {
        	return this.apiToken;
        }

        // Get new token
        while (true) {

            LumenazaApiResponse lumenazaResponse = new LumenazaApiResponse();
            this.lastResponse = lumenazaResponse;

			// Set basic auth header
            Map<String,String> headers = new Map<String,String>();
            if (this.apiAuthClient != NULL && this.apiAuthSecret != NULL) {
            	headers.put('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(this.apiAuthClient + ':' + this.apiAuthSecret)));
            }

            try {
            	lumenazaResponse = this.callout(this.authEndpoint, 'POST', 'grant_type=password&username=' + this.apiUsername + '&password=' + this.apiPassword, headers);
            }
            catch (Exception e) {
                lumenazaResponse.setResponse('Calling ' + this.authEndpoint + ' received no valid result (' + e.getMessage() + ')');
                break;
            }

            if (lumenazaResponse.success == false) {
                break;
            }

            Map<String,String> resultMap = lumenazaResponse.resultMap;

            if (resultMap.containsKey('access_token') == false) {
            	lumenazaResponse.setResponse('Result of token request via ' + this.authEndpoint + ' contains no access_token');
                break;
            }

            token = resultMap.get('access_token');
            Datetime expiration = DateTime.now().addSeconds(Integer.valueOf(resultMap.get('expires_in')));

            // Set token
            this.setToken(token, expiration);

            System.debug('LumenazaApi - Got token ' + token);
            break;
        }

        return token;
    }

    /**
     * Set the auth token for reuse
     *
     * @param Sting Token
     * @param DateTime Expiration time of token
     */
    private void setToken(String token, Datetime tokenExpiration) {

        /*
        if (this.environment == 'LIVE') {
            this.settings.ApiLiveToken__c = token;
            this.settings.ApiLiveTokenExpiration__c = tokenExpiration;
        }
        else {
            this.settings.ApiTestToken__c = token;
            this.settings.ApiTestTokenExpiration__c = tokenExpiration;
        }
		// If there are callouts after a DML operation it breaks with
		// "System.CalloutException: You have uncommitted work pending. Please
		// commit or rollback before calling out" Unfortunately one cannot
		// force a commit.
        update this.settings;
		*/

        this.apiToken = token;
		this.apiTokenExpiration = tokenExpiration;
    }

   	public class LumenazaApiException extends Exception {}

    /**
     * Response of an LumenazaApi call
     */
    public class LumenazaApiResponse {

        public String requestInfo = '';
        public Boolean success = false;
        public Map<String,String> resultMap;
        public HttpResponse response;
        public String error = 'Unknown error';
        public String responseBody = '';

        public LumenazaApiResponse() {
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

            if (this.success == true) {

                this.responseBody = response.getBody();

                this.error = '';
                // Try JSON
                try {
            		this.resultMap = (Map<String,String>)JSON.deserialize(this.responseBody, Map<String,String>.class);
                }
                // If not then screw
                catch (Exception e) {
                }
            }
            else {
                this.error = response.getBody();
            }
            System.debug(response);
        }
    }
}