@isTest
private class WebserviceSbcList_Test {
	
	@isTest static void TestSbcListing() {

        Account acc = new Account(
          	  Name = 'Bogus Company',
              BillingStreet = 'Teststreet',
              BillingPostalCode = '12345',
              BillingCity = 'Voidbeeg',
              BillingCountryCode =  'DE'
        );
            
        insert acc;
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();

		req.requestURI = '/services/apexrest/sbc';  //Request URL
		req.httpMethod = 'GET';//HTTP Request Type
		req.requestBody = Blob.valueof('');
        RestContext.request = req;
		RestContext.response= res;
        
        WebserviceSbcListing.Response resp1 = WebserviceSbcListing.buildSbcList();

        Account acc2 = new Account(
          	  Name = 'Bogus Company',
              RecordTypeId = SonnenbatterieConstants.ACC_RT_SBC,
              BillingStreet = 'Teststreet',
              BillingPostalCode = '12345',
              BillingCity = 'Voidbeeg',
              BillingCountryCode =  'DE'
        );
            
        insert acc2;
       	req = new RestRequest();
		res = new RestResponse();

		req.requestURI = '/services/apexrest/sbc';  //Request URL
		req.httpMethod = 'GET';//HTTP Request Type
		req.requestBody = Blob.valueof('');
        RestContext.request = req;
		RestContext.response= res;
        
        WebserviceSbcListing.Response resp2 = WebserviceSbcListing.buildSbcList();

       	Test.stopTest();
    
    }
	
}