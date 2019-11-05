/**
 * Common RESTClient
 * 
 * v1.0.0   2019-09-08  Marko Schmalenbach          Initial
 * v1.1.0   2019-03-05  Marko Schmalenbach          Added predefinedCalloutMock
 */
public with sharing virtual class RESTClient {

    public class RESTClientException extends Exception {}

    /*
     * class variable creation - DO NOT EDIT
     */
    public Map<String,String> headers;
    public String url;
    public String method;
    public String body;
    public HttpRequest request;
    public HttpResponse response;
    public String responseBody;
    public String lastDebugMessage;
    public Http h;

    private static final String DEBUG_HEADER = 'RESTClient.';

    /**
     * Predefined Mock taken for all upcoming requests in UnitTests
     */
    @TestVisible
    private static PredefinedCalloutMock predefinedCalloutMock;

    /**
     * A list of Predefined Mocks processed for all upcoming requests in UnitTests
     * Once a Mock was used it will be removed
     */
    @TestVisible
    private static List<PredefinedCalloutMock> listPredefinedCalloutMockQueue = new List<RESTClient.PredefinedCalloutMock>();

    /*
     * Constants - Edit to your satisfaction
     */
    public static Integer TIMEOUT = 60000; // Default HTTP Timeout
    public Boolean DEBUG = true; // should we print debug statements?

    /*
     * Constructors:
     */
    public RESTClient() {} //Prevent empty objects.

    //master constructor with everything required.
    public RESTClient(String url, String method, Map<String,String> headers, String body) {

        try {
            this.h = new Http();
            this.request = buildRequest(headers, url, method.toUpperCase(), body);
            this.response = makeRequest(this.h, this.request);
            this.responseBody = handleResponse(this.response);
        }
        catch (Exception e) {
            //log the error, but set as much as we can with the input given
            log('Failed to execute callout. SFDC Reports: ',e, e.getMessage());
            if (headers != null) this.headers = headers;
            this.body = body;
            this.url = url;
            this.method = method.toUpperCase();
            throw e;
        }
    }

    public RESTClient(String url, String method, String body) {
        this(url, method, null, body);
    }

    public RESTClient(String url, String method, Map<String,String> headers) {
        this(url, method, headers, null);
    }

    public RESTClient(String url, String method) {
        this(url, method, new Map<String,String>(), null);
    }

    /*
     * Helper Methods - These do the actual work.
     */

    public static HttpRequest buildRequest(Map<String,String> headers, String url, String method, String body) {

        HttpRequest request = new HttpRequest();

        request.setTimeout(TIMEOUT); // timeout in milliseconds

        if (headers != null) {
            for(String hkey : headers.keySet()){
                request.setHeader(hkey, headers.get(hkey));
            }
        }

        request.setEndpoint(url);
        request.setMethod(method);

        if (body != null && body.length() > 0) {
            request.setBody(body);
        }

        return request;
    }

    /**
     * Return a HttpResponse from the given Request
     *
     * @param h
     * @param request
     *
     * @return
     */
    public static HttpResponse makeRequest(Http h, HttpRequest request) {

        final String DEBUG_HERE = DEBUG_HEADER + 'makeRequest() - ';

        HttpResponse oResponse;

        if (Test.isRunningTest() &&
            (predefinedCalloutMock != null || !listPredefinedCalloutMockQueue.isEmpty())) {

            if (predefinedCalloutMock != null) {
                System.debug(DEBUG_HERE + 'Use predefinedCalloutMock: ' + predefinedCalloutMock);
                oResponse = predefinedCalloutMock.respond(request);
            }
            else {
                // Get the next predefined mock from the queue and remove it then
                PredefinedCalloutMock oPredefinedCalloutMock = listPredefinedCalloutMockQueue.get(0);

                System.debug(DEBUG_HERE + 'Use predefinedCalloutMock from Queue: ' + oPredefinedCalloutMock);

                oResponse = oPredefinedCalloutMock.respond(request);
                listPredefinedCalloutMockQueue.remove(0);
            }
        }
        else {
            System.debug(DEBUG_HERE + 'Make request: ' + request);
            oResponse = h.send(request);
        }

        return oResponse;
    }

    public String handleResponse(HttpResponse response){
        log('Response', response, response.getBody());
        return response.getBody();
    }


    /**
    * GET convenience methods
    **/
    // RESTClient.get('http://www.google.com/?q=convenance')
    public String get(String url) {
        RESTClient x = new RESTClient(url, 'get', null, null);
        log(url, x, null);
        return x.responseBody;
    }

    // RESTClient.get('http://www.google.com/', HeaderMap{'q', 'convenance'})
    public String get(String url, Map<String,String> headers) {
        RESTClient x = new RESTClient(url, 'get', headers, null);
        System.debug(x.responseBody);
        return x.responseBody;
    }

    // RESTClient.get('http://www.google.com/', HeaderMap{'q', 'convenance'}, 'some body of text for unknown reason.')
    public String get(String url, Map<String,String> headers, String body) {
        RESTClient x = new RESTClient(url, 'get', headers, body);
        return x.responseBody;
    }

    public HttpResponse post(String url, Map<String,String> headers, String Body) {
        RESTClient x = new RESTClient(url, 'POST', headers, body);
        return x.response;
    }

    public String request(String url, String method, Map<String,String> headers){
        RESTClient x = new RESTClient(url, method, headers);
        return x.responseBody;
    }

    public String request(String url, String method, String body){
        RESTClient x = new RESTClient(url, method, body);
        return x.responseBody;
    }

    public String request(String url, String method){
        RESTClient x = new RESTClient(url, method);
        return x.responseBody;
    }

    /*
     * Private helper methods: Only this class should use them.
     */
    public void log(String header, Object obj, String msg) {

        String startStop = '\n===============================================================================';
        String logOutput = startStop;
        logOutput += (header != null) ? '\n== Header: ' + header : 'Header: No Header Set';
        logOutput += (obj != null) ? '\n== Obj String Rep: ' + obj : '\n No Obj set';
        logOutput += (msg != null) ? '\n== ' + msg : '';
        logOutput += startStop;

        if (DEBUG){
            lastDebugMessage = logOutput;
            System.debug(logOutput);
        }

    }

    /**
     *
     *
     * @param predefinedCalloutMock
     */
    public static void setPredefinedCalloutMock(PredefinedCalloutMock mock) {
        predefinedCalloutMock = mock;
    }

    /**
     *
     *
     * @param predefinedCalloutMocks
     */
    public static void setPredefinedCalloutMockQueue(List<PredefinedCalloutMock> mocks) {
        listPredefinedCalloutMockQueue = mocks;
    }

    /**
     * SingleRequestMock
     */
    public class PredefinedCalloutMock implements HttpCalloutMock {

        protected Integer code;
        protected String status;
        protected String bodyAsString;
        protected Blob bodyAsBlob;
        protected Map<String, String> responseHeaders;

        /**
         * SingleRequestMock constructor with string body
         *
         * @param code
         * @param status
         * @param body
         * @param responseHeaders
         */
        public PredefinedCalloutMock(Integer code, String status, String body, Map<String, String> responseHeaders) {
            this.bodyAsString = body;
            this.setResponseValues(code, status, responseHeaders);
        }

        /**
         * SingleRequestMock constructor with blob body
         *
         * @param code
         * @param status
         * @param body
         * @param responseHeaders
         */
        public PredefinedCalloutMock(Integer code, String status, Blob body, Map<String, String> responseHeaders) {
            this.bodyAsBlob = body;
            this.setResponseValues(code, status, responseHeaders);
        }

        /**
         * Set main response values
         *
         * @param code
         * @param status
         * @param responseHeaders
         */
        private void setResponseValues(Integer code, String status, Map<String, String> responseHeaders) {
            this.code            = code;
            this.status          = status;
            this.responseHeaders = responseHeaders;
        }

        /**
         * Respond
         *
         * @param request
         *
         * @return
         */
        public HttpResponse respond(HttpRequest request) {

            HttpResponse oResponse = new HttpResponse();

            oResponse.setStatusCode(code);
            oResponse.setStatus(status);

            if (bodyAsBlob != null) {
                oResponse.setBodyAsBlob(bodyAsBlob);
            }
            else {
                oResponse.setBody(bodyAsString);
            }

            if (responseHeaders != null) {
                for (String key : responseHeaders.keySet()) {
                    oResponse.setHeader(key, responseHeaders.get(key));
                }
            }
            return oResponse;
        }
    }
}