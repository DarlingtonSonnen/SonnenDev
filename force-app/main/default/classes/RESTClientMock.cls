public class RESTClientMock implements HttpCalloutMock {

	public static String REPONSE_STRING = 'Do the Bogus Boogie Woogie!';
    
    public HTTPResponse respond(HTTPRequest req) {            
        HTTPResponse response = new HTTPResponse();
        response.setBody(REPONSE_STRING);
        response.setStatusCode(200);            
        return response;
    }    
}