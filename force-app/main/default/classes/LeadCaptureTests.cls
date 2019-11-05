@isTest
private class LeadCaptureTests {

	@isTest static void TestLeadCapture() {

		Lead lead = new Lead();
        lead.company	  	= 'Firma';
        lead.firstname 	  	= 'Vorname';
		lead.lastname 	  	= 'Nachname';
        lead.salutation 	= '0';
        lead.email 		  	= 'max@mustermann.de';
        lead.street 	  	= 'Strasse 12';
        lead.postalcode 	= '12345';
        lead.city 		  	= 'Stadt';
        lead.phone		  	= '01234/56789';
        lead.fax		  	= '01234/56788';
        lead.MobilePhone 	= '01234/56787';
       	lead.website 		= 'www.sonnenbatterie.com';

		Test.startTest();

        String JsonMsg = JSON.serialize(lead);

        RestRequest oRestRequest = new RestRequest();
		RestResponse oRestResponse = new RestResponse();

		oRestRequest.requestURI = '/services/apexrest/lead';  //Request URL
		oRestRequest.httpMethod = 'POST';//HTTP Request Type
		oRestRequest.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = oRestRequest;
		RestContext.response= oRestResponse;

        LeadCapture.Response resp1 = new LeadCapture.Response();
       	resp1 = LeadCapture.createLead();

       	//
        lead.lastname = NULL;

        JsonMsg = JSON.serialize(lead);

        oRestRequest = new RestRequest();
		oRestResponse = new RestResponse();

		oRestRequest.requestURI = '/services/apexrest/lead';  //Request URL
		oRestRequest.httpMethod = 'POST';//HTTP Request Type
		oRestRequest.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = oRestRequest;
		RestContext.response= oRestResponse;

        Leadcapture.Response resp2 = new LeadCapture.Response();
       	resp2 = LeadCapture.createLead();

        System.assertEquals(500, RestContext.response.statusCode);

		//--------------------------
		// Test preventPersistence
		//--------------------------
        lead.LastName = 'Lalala';
		JsonMsg = JSON.serialize(lead);

		oRestRequest = new RestRequest();
		oRestResponse = new RestResponse();

		oRestRequest.requestURI = '/services/apexrest/lead';  //Request URL
		oRestRequest.httpMethod = 'POST';//HTTP Request Type
		oRestRequest.params.put('preventPersistence', '1');
		oRestRequest.requestBody = Blob.valueof(JsonMsg);
		RestContext.request = oRestRequest;
		RestContext.response= oRestResponse;

		LeadCapture.Response oResponsePreventPersistence = new LeadCapture.Response();
		oResponsePreventPersistence = LeadCapture.createLead();

       	Test.stopTest();
       	//Assertions

       	// number of leads should be exactly one

       	Map<Id, Lead> resultMap = new Map<Id, Lead>(
       		[SELECT Id, FirstName, LastName FROM Lead]
       		);

       	System.assertEquals(1, resultMap.values().size());
       	System.assertEquals(true, resultMap.containsKey(resp1.leadid));
       	System.assert(resp1.leadObject != null);
       	System.assertEquals('Failure', resp2.status);
       	System.assertEquals('Success', oResponsePreventPersistence.status);
	}

}