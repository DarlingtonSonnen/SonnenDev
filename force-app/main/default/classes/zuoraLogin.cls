/*
    Zuora login class
 */

public class zuoraLogin {

    public static HttpResponse loginZuora(zuoraSetting__mdt settings) {
        
        String body = 'client_id='+settings.client_id__c+'&client_secret='+settings.client_secret__c+'&grant_type=client_credentials';
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.url__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        HttpResponse res = new HttpResponse();
        if (!Test.isRunningTest()) {
            res = h.send(req);
        } else {
            String testbody = '{ "access_token": "3e0ed11c851543ce823e645af68ec787", "token_type": "bearer", "expires_in": 3598, "scope": "entity.8adc8f99-5f6b-4342-015f-6ecadc321ab5 platform.write service.usage.delete service.usage.update service.usage.write tenant.2000125 user.8adce42161c1652f0161e24e376a56f6", "jti": "3e0ed11c851543ce823e645af68ec787" }';
            SingleRequestMock mockResponse = new SingleRequestMock(200, 'Completed', testbody, null);
            res = mockResponse.respond(req);
        }
        return res;
    }

    public static HttpResponse loginZuora() {
        // overloaded method without zuoraSetting custom metadata - calls another method to get them before calling actual login method

        zuoraSetting__mdt settings = ZuoraSettings.getZuoraSetting();
        HttpResponse res = loginZuora(settings);
        return res;
    }
}