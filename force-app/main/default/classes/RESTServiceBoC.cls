/**
 * Created by m.muchow on 24.07.2019.
 */
@RestResource(UrlMapping='/bocEndpoint/*')
global with sharing class RESTServiceBoC {

    private static final String DEBUG_HEADER = 'RESTServiceBOC.';
    private static final String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

    @HttpPost
    global static Response handlePost() {

        String DEBUG_HERE = DEBUG_HEADER + 'handlePost() - ';

        RestRequest bocRequest = RestContext.request;
        String authToken = bocRequest.params.get('token');
        String type = bocRequest.params.get('type');

        // Default status
        RestContext.response.statusCode = 200;

        // POST data
        // Expects the data to be of content-type application/json!
        Blob body = bocRequest.requestBody;
        String sBoCAsJson = body.toString();

        // Inner class to have an own context
        RESTServiceBoC.BoCProcessor bBoCProcessor = new RESTServiceBoC.BoCProcessor(sBoCAsJson, authToken, type);
        RESTServiceBoC.Response bocResponse = bBoCProcessor.process();

        return bocResponse;
    }

    global class BoCProcessor {

        //private String DEBUG_HEADER_INNER = 'OrderProcessor.';

        private String sBoCJson;

        private String sAuthToken;

        private String sType;

        private Map<String, Object> mBoCRequestMap = new Map<String, Object>();

        private Map<String, Object> mResponseMap = new Map<String, Object>();

        private Map<String, Object> mErrorMap = new Map<String, Object>();

        private RESTServiceBoC.Response bocResponse = new RESTServiceBoC.Response();

        public BoCProcessor(String requestString, String authToken, String type) {
            this.sBoCJson = requestString;
            this.sAuthToken = authToken;
            this.sType = type;
        }

        public RESTServiceBoC.Response process() {

                try {
                    if (AUTH_TOKEN == this.sAuthToken) {
                        if (this.sBoCJson.length() == 0) {
                            this.bocResponse.setError('Empty request', 'EMPTY_REQUEST', 400);
                        } else {
                            this.mBoCRequestMap = (Map<String, Object>) JSON.deserializeUntyped(this.sBoCJson);
                            if (this.sType == 'customer' || (this.sType == '' || this.sType == null)) {
                                this.mResponseMap = BoCEndpoint.checkAndCreateCustomer(this.mBoCRequestMap, this.sBoCJson);
                            } else if (this.sType == 'offer') {
                                this.mResponseMap = BoCEndpoint.createOffer(this.mBoCRequestMap, this.sBoCJson);
                            } /*else if (this.sType == 'sold?') {
                                // update Opp/Quote
                            }*/
                            if ((SObject)mResponseMap.get('Contact') != null) {
                                this.bocResponse.addObject('Contact', (SObject)mResponseMap.get('Contact'));
                            }
                            if ((SObject)mResponseMap.get('Account') != null) {
                                this.bocResponse.addObject('Account', (SObject)mResponseMap.get('Account'));
                            }
                            if ((SObject)mResponseMap.get('Opportunity') != null) {
                                this.bocResponse.addObject('Opportunity', (SObject)mResponseMap.get('Opportunity'));
                            }
                            if ((Map<String, Object>)mResponseMap.get('Error') != null) {
                                this.mErrorMap = (Map<String, Object>)mResponseMap.get('Error');
                                this.bocResponse.setError((String)mErrorMap.get('errorMessage'), (String)mErrorMap.get('code'), (Integer)mErrorMap.get('httpStatusCode'));
                            }
                            if ((String) mResponseMap.get('Debug') != null) {
                                this.bocResponse.addDebug((String) mResponseMap.get('Debug'));
                            }
                        }
                    } else {
                        this.bocResponse.setError('Wrong or no authentication token', 'UNAUTHORIZED', 401);
                    }

                } catch(Exception e) {
                        this.bocResponse.setError('Bad Request - See Debug', 'BAD_REQUEST', 400);
                        this.bocResponse.addDebug(e.getTypeName() + ': ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
            }
            system.debug('this.bocResponse '+this.bocResponse);
            return this.bocResponse;
        }
    }
    global class Response {

            public Map<String,String> error = new Map<String,String>();
            public List<String> debug = new List<String>();
            public Map<String,List<SObject>> objects = new Map<String,List<SObject>>();

            /**
             * Add a list of SObjects
             *
             * @param name
             * @param listSObjects
             */
            public void addObjects(String name, List<SObject> listSObjects) {

                if (!this.objects.containsKey(name)) {
                    this.objects.put(name, new List<SObject>());
                }

                this.objects.get(name).addAll(listSObjects);
            }

            /**
             * Add an SObject
             *
             * @param name
             * @param oSObject
             */
            public void addObject(String name, SObject oSObject) {
                this.addObjects(name, new List<SObject>{oSObject});
            }

            /**
             * Set the error with additional status code
             *
             * @param error
             * @param code
             * @param httpStatusCode
             */
            public void setError(String error, String code, Integer httpStatusCode) {
                this.error.put('message', error);
                this.error.put('code', code);
                if (this.error.containsKey('field')) {
                    this.error.remove('field');
                }
                RestContext.response.statusCode = httpStatusCode;
            }

            /**
             * Add a debug information
             *
             * @param debugMessage
             */

            public void addDebug(String debugMessage) {
                this.debug.add(System.now().format('yyyy-MM-dd HH:mm:ss') + '.' + System.now().millisecond() + ' - ' + debugMessage);
                //if (!suppressDebug) System.debug('RESTServiceOrder.Response - ' + debugMessage);
            }
        }
}