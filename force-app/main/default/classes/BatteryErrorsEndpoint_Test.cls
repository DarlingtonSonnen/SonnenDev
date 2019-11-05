@isTest
public class BatteryErrorsEndpoint_Test {
	    
	@testSetup 
	static void testData() {
		
		// create account
		Account acc = new Account();
		acc.Name = 'Test Account';
		insert acc;
		
		// create asset, fill in Id, INClientLanguage__c, SerialNumber
		Asset a = new Asset();
		a.AccountId = acc.Id;
		a.Name = '#12345 testname Customername';
		a.SerialNumber = '12345';
		a.Status = 'Installed';
		a.INClientSalutation__c = 'Mr.';
		a.InClientPhoneNumber__c = '234325';
		a.INClientEmail__c = 'test@gmail.com';
		a.INClientLanguage__c = 'DE';
		a.AccountId = acc.Id;
		
		insert a;
		
    }
	
	@isTest
	static void testMethod1() {
		
		Asset a = [SELECT Id FROM Asset WHERE Name = '#12345 testname Customername' LIMIT 1];
		// test post method
		String reqBody = '{ "ticket":"12345", "code":"1040", "alert_id":"131", "recipient":"Client", "resolved":false, "alert_creation": "2018-06-15 07:22:23", "data":{ "last_contact":"2018-06-07 09:56:33" } }';
        
		RestRequest req = new RestRequest();
    	RestResponse res = new RestResponse();
    	
    	req.RequestBody = Blob.valueOf(reqBody);
    	req.httpMethod = 'POST';
  		req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/BatteryErrors/v1';
    	
    	System.debug(req.requestURI);
  		
  		RestContext.request = req;
  		RestContext.response = res;
  		
  		Test.startTest();
  		BatteryErrorsEndpoint.CreateErrorMessage();
  		Test.stopTest();
  		System.assertEquals(1, [SELECT Id FROM DeviceError__c WHERE Asset__c = :a.Id].size());
  		
        // test creating the duplicate error message
  		BatteryErrorsEndpoint.CreateErrorMessage();
  		System.assertEquals(400, res.statusCode);
	}
  	
  	@isTest
  	static void testMethod2() {
		  		
  		Asset a = [SELECT Id FROM Asset WHERE Name = '#12345 testname Customername' LIMIT 1];
		// test post method
		String reqBody = '{ "ticket":"12345", "code":"1040", "alert_id":"131", "recipient":"Client", "resolved":false, "alert_creation": "2018-06-15 07:22:23", "data":{ "last_contact":"2018-06-07 09:56:33" } }';
		
		RestRequest req = new RestRequest();
    	RestResponse res = new RestResponse();
    	
    	req.RequestBody = Blob.valueOf(reqBody);
    	req.httpMethod = 'POST';
  		req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/BatteryErrors/v1';
    	
    	System.debug(req.requestURI);
  		
  		RestContext.request = req;
  		RestContext.response = res;
  		
  		BatteryErrorsEndpoint.CreateErrorMessage();
  		
  		// test patch method
  		String reqBody2 = '{ "resolved": true }';
  		
  		RestRequest req2 = new RestRequest();
    	RestResponse res2 = new RestResponse();
    	
    	req2.RequestBody = Blob.valueOf(reqBody2);
    	req2.httpMethod = 'PATCH';
  		req2.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/BatteryErrors/v1/131';
    	
    	System.debug(req2.requestURI);
  		
  		RestContext.request = req2;
  		RestContext.response = res2;
  		
  		Test.startTest();
  		BatteryErrorsEndpoint.AlertResolved();
  		Test.stopTest();
  		System.debug(res2);
  		
  		System.assertEquals(204, res2.statusCode);
  		System.assertEquals(true, [SELECT Resolved__c FROM DeviceError__c WHERE AlertId__c = '131'].Resolved__c);
  	}	

    @isTest
    static void testMethod4() {
        //send request without code parameter
        Asset a = [SELECT Id FROM Asset WHERE Name = '#12345 testname Customername' LIMIT 1];
		// test post method
		String reqBody = '{ "ticket": "12345", "alert_id": "131", "recipient": "Installer", "resolved": false, "data": { "last_seen": "2018-05-23 04:27:03" } }';
		
		RestRequest req = new RestRequest();
    	RestResponse res = new RestResponse();
    	
    	req.RequestBody = Blob.valueOf(reqBody);
    	req.httpMethod = 'POST';
  		req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/BatteryErrors/v1';
    	
    	System.debug(req.requestURI);
  		
  		RestContext.request = req;
  		RestContext.response = res;
  		
        Test.startTest();
  		BatteryErrorsEndpoint.CreateErrorMessage();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode);    
    }
    @isTest
    static void testMethod5() {
        // send patch request for non existing alert id
        String reqBody2 = '{"resolved": true }';
  		
  		RestRequest req = new RestRequest();
    	RestResponse res = new RestResponse();
    	
    	req.RequestBody = Blob.valueOf(reqBody2);
    	req.httpMethod = 'PATCH';
  		req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/BatteryErrors/v1/131000';
    	
    	System.debug(req.requestURI);
  		
  		RestContext.request = req;
  		RestContext.response = res;
  		
  		Test.startTest();
  		BatteryErrorsEndpoint.AlertResolved();
  		Test.stopTest();
  		System.debug(res);
  		
  		System.assertEquals(400, res.statusCode);
    }
	@isTest
	static void testMethod6() {
		// test scenario when no asset was found in Salesforce by the ticket/serial number
		String reqBody = '{ "ticket":"22345", "code":"1040", "alert_id":"131", "recipient":"Client", "resolved":false, "alert_creation": "2018-06-15 07:22:23", "data":{ "last_contact":"2018-06-07 09:56:33" } }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.RequestBody = Blob.valueOf(reqBody);
        req.httpMethod = 'POST';
        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/BatteryErrors/v1';

        RestContext.request = req;
        RestContext.response = res;

        BatteryErrorsEndpoint.CreateErrorMessage();

        System.assertEquals(400, res.statusCode);

	}
}