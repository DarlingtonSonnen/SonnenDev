@isTest
private class RESTClientTest {    
    
	@isTest static void testClient() { 
        
        String url = 'http://bla.blub';
        String body = 'parameter=dingdangdoodle';
        
        Map<String,String> headers = new Map<String,String>{
            'Accept' => 'Visa'
        };
                        
		Test.setMock(HttpCalloutMock.class, new RESTClientMock());
            
        RESTClient client = new RESTClient();
        client = new RESTClient(url, 'GET', headers, body);
        client = new RESTClient(url, 'POST', body);
        client = new RESTClient(url, 'GET', headers);
        client = new RESTClient(url, 'GET');  
        
        client.get(url); 
        client.get(url, headers);
        client.get(url, headers, body);
        client.post(url, headers, body);
        client.request(url, 'GET', headers);
        client.request(url, 'GET', body);
        client.request(url, 'GET');
        
        // No assertions made :P
    }
}