@isTest
private class WebhookListenerTests {
    
  @isTest static void TestWebhookListenerCharges() {

    Test.startTest();
        
        String JsonMsg = StripeEventTests.testData_ChargeSucceeded;
        
	    RestRequest req = new RestRequest();
	    RestResponse res = new RestResponse();

	    req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	    req.httpMethod = 'POST';//HTTP Request Type
	    req.requestBody = Blob.valueof(JsonMsg);
	    RestContext.request = req;
	    RestContext.response= res;
	        
        try {
          WebhookListener.doPost();
        }
        catch (Exception e) {
          System.debug(e);
        }


        JsonMsg = StripeEventTests.testData_ChargeFailed;
        
	    req = new RestRequest();
	    res = new RestResponse();

	    req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	    req.httpMethod = 'POST';//HTTP Request Type
	    req.requestBody = Blob.valueof(JsonMsg);
	    RestContext.request = req;
	    RestContext.response= res;
	        
        try {
          WebhookListener.doPost();
        }
        catch (Exception e) {
          System.debug(e);
        }
        
        JsonMsg = StripeEventTests.testData_ChargeRefunded;
        
	    req = new RestRequest();
	    res = new RestResponse();

	    req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	    req.httpMethod = 'POST';//HTTP Request Type
	    req.requestBody = Blob.valueof(JsonMsg);
	    RestContext.request = req;
	    RestContext.response= res;
	        
        try {
          WebhookListener.doPost();
        }
        catch (Exception e) {
          System.debug(e);
        }
        
        
        Test.stopTest();
    }
  
  @isTest static void TestWebhookListenerCustomer() {
  	
  	Test.startTest();

  	String JsonMsg = StripeEventTests.testData_CustomerCardCreated;
        
	RestRequest req = new RestRequest();
	RestResponse res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }

    JsonMsg = StripeEventTests.testData_CustomerCardCreated;
        
	req = new RestRequest();
	res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }
    
    JsonMsg = StripeEventTests.testData_CustomerSubscriptionDeleted;
        
	req = new RestRequest();
	res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }
    Test.stopTest();

  }

  @isTest static void TestWebhookListenerInvoice() {
  	
  	Test.startTest();

  	String JsonMsg = StripeEventTests.testData_InvoicePaymentSucceeded;
        
	RestRequest req = new RestRequest();
	RestResponse res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }

    JsonMsg = StripeEventTests.testData_InvoiceCreated;
        
	req = new RestRequest();
	res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }

    JsonMsg = StripeEventTests.testData_InvoicePaymentFailed;
        
	req = new RestRequest();
	res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }
    Test.stopTest();
  }

  @isTest static void TestWebhookListener() {
  	
  	Opportunity o = New Opportunity();
  	o.Pricebook2Id = Test.getStandardPricebookId();
  	o.name = 'TestOpp1';
  	o.CloseDate = Date.today() + 14;
  	o.StripeCharge__c = 'ch_sHBUQHlTQzx5S8';
  	o.StageName = 'Prospecting';
  	insert o;

  	Test.startTest();

  	String JsonMsg = StripeEventTests.testData_CustomerCreated;
        
	RestRequest req = new RestRequest();
	RestResponse res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }

    // 
    Account [] accs = [SELECT Id FROM Account];
    System.assertEquals(1, accs.size() );

    Account a = accs[0];
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    opp.AccountId = a.Id;

    //  shpuld run into updating the previously created account
    JsonMsg = StripeEventTests.testData_CustomerCreated;
        
	req = new RestRequest();
	res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }


    
  	Quote q = new Quote();
  	//q.AccountId = a.Id;
  	q.OpportunityId = opp.Id;
  	q.Name = 'TestQuote';
  	q.StripeCharge__c = o.StripeCharge__c = 'ch_sHBUQHlTQzx5S8';

    JsonMsg = StripeEventTests.testData_ChargeSucceeded;
        
	req = new RestRequest();
	res = new RestResponse();

	req.requestURI = '/stripe/webhooks/v1/';  //Request URL
	req.httpMethod = 'POST';//HTTP Request Type
	req.requestBody = Blob.valueof(JsonMsg);
	RestContext.request = req;
	RestContext.response= res;
	        
    try {
    	WebhookListener.doPost();
    }
    
    catch (Exception e) {
    	System.debug(e);
    }

    Test.stopTest();
  }
}