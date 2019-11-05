/**
 * Mock Dispatcher for Awattar API Calls
 *
 * Changelog
 * ---------
 *
 * v1.1.0-2017-10-09
 * - Added route for "initContractMail" (SOBCRM-1034)
 *
 * v1.0.0-2017-08-10
 * - initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.0.0-2017-08-10
 */
public class AwattarRestApiMockDispatcher implements HttpCalloutMock {

    private static final String DEBUG_HEADER = 'AwattarRestApiMockDispatcher';
    public static String CONTRACT_ID = '987654321';

    private static String nextRouteBody;
    private static Integer nextRouteStatusCode;

    // Methods and routes
    private Map<String,String> routes = new Map<String,String>{
        'contractCreate'                => 'POST:/v1/contracts',
        'contractUpdate'                => 'POST:/v1/contracts/[^/]+',
        'initContractMail'              => 'POST:/v1/contracts/[^/]+/mail'
    };

    private HttpRequest request;
    private HttpResponse response;
         
    /**
     * Implemented method from interface as route dispatcher
     */
    public HttpResponse respond(HttpRequest request) {

        this.response = new HttpResponse();
        this.request = request;
        this.response.setHeader('Content-Type', 'application/json');

        String path = this.getEndpointPath(request.getEndpoint());
        String method = request.getMethod().toUpperCase();

        Boolean routeFound = false;

        for (String routeMethod : routes.keySet()) {

            String routePattern = routes.get(routeMethod);
            String routeString = method + ':' + path;
            Boolean hasRoute = false;

            if (Pattern.compile(routePattern).matcher(routeString).matches()) {

                System.debug('AwattarRestApiMockDispatcher - Route method for path ' + routeString + ': ' + routeMethod);

                if (routeMethod == 'contractCreate') {
                    this.routeContractCreate();
                    routeFound = true;
                    break;
                }
                else if (routeMethod == 'contractUpdate') {
                    this.routeContractUpdate();
                    routeFound = true;
                    break;
                }
                else if (routeMethod == 'initContractMail') {
                    this.routeContractUpdate();
                    routeFound = true;
                    break;
                }

                throw new AwattarRestApiMockDispatcherException('Unhandled route method "' + routeMethod + '"');
            }
        }

        if (routeFound == false) {
            throw new AwattarRestApiMockDispatcherException('Unhandled route "' + path + '" with method ' + method);
        }

        return this.response;
    }

    //============================================================================
    // ROUTE HANDLERS
    //============================================================================

	/**
	 * Set reponse for Contract CREATE
	 */
    private void routeContractCreate() {
        if (!this.setForcedResponseIfAvailable()) {

            String sNewId = 'AW123456';

            Map<String,Object> mapResponse = new Map<String,Object>{
                'object' => 'contract',
                'id' => sNewId,
                'data' => new Map<String,String>{
                    'key' => sNewId
                },
                'url' => 'http://resource.url',
                'form_url' => 'http://form.url'
            };

            this.response.setBody(JSON.serializePretty(mapResponse));
            this.response.setStatusCode(200);
        }
    }

    private void routeContractUpdate() {
        if (!this.setForcedResponseIfAvailable()) {
            Map<String,String> mapResponse = new Map<String,String>{
                'status' => 'success'
            };
            this.response.setBody(JSON.serialize(mapResponse));
            this.response.setStatusCode(200);
        }
    }

    private void routeInitContractMail() {
        Map<String,String> mapResponse = new Map<String,String>{
            'status' => 'success'
        };
        this.response.setStatusCode(200);
    }

    //============================================================================
    // HELPER
    //============================================================================
    /**
     * Force a result
     */
    public static void setResultBodyNextRoute(String body, Integer statusCode) {
        nextRouteBody = body;
        nextRouteStatusCode = statusCode;
    }

    /**
     * Set forced Response if available
     */
    private Boolean setForcedResponseIfAvailable() {

        if (nextRouteBody != NULL) {
            this.response.setBody(nextRouteBody);
            this.response.setStatusCode(nextRouteStatusCode);
            nextRouteBody = NULL;
            nextRouteStatusCode = NULL;
            return TRUE;
        }

        return FALSE;
    }

    /**
     * Extracts a path from an URL
     */
    private String getEndpointPath(String url) {

        Matcher matcher = Pattern.compile('^https?://[^/]+(.+)').matcher(url);
        String path = '';

        if (matcher.matches()) {
            path = matcher.group(1);
        }

        return path;
    }

    public class AwattarRestApiMockDispatcherException extends Exception {}
}