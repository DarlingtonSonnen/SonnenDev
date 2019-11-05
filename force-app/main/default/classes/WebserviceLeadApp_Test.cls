@isTest
private class WebserviceLeadApp_Test {
	
    @testSetup
    static void LeadAppTestSetup() {
    
        Campaign c = new Campaign();
        c.name = 'ScopeCamp';
        c.type = 'Retail';
        c.isActive = true;
        insert c;
        
        Campaign c2 = new Campaign();
        c2.name = 'OutofScopeCamp';
        c2.type = 'Other';
        insert c2;
        
        TeamMember__c tm = new TeamMember__c();
        tm.FirstName__c = 'Voidbert';
        tm.LastName__c = 'Inscope';
        insert tm;
        
        TeamMember__c tm2 = new TeamMember__c();
        tm2.FirstName__c = 'Bertvoid';
        tm2.LastName__c = 'Outofscoe';
        insert tm2;
        
        CampaignTeam__c ct = new CampaignTeam__c();
        ct.Campaign__c = c.id;
        ct.TeamMember__c = tm.id;
        insert ct;
        
        CampaignTeam__c ct2 = new CampaignTeam__c();
        ct2.Campaign__c = c2.id;
        ct2.TeamMember__c = tm2.id;
        insert ct2;
    }
    
    
    @isTest
    static void TestUnauthorized() {

        Test.startTest();
        
        RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();

		req.requestURI = '/services/apexrest/leadapp';  //Request URL
		req.httpMethod = 'GET';//HTTP Request Type
		req.requestBody = Blob.valueof('');
        RestContext.request = req;
		RestContext.response= res;
        
        WebserviceLeadAppIndex.CampaignResponse resp1 = WebserviceLeadAppIndex.getRunningCampaignsAndStaff();

        Test.stopTest();
    
    }
    
    @isTest
    static void TestGetCampaignAndTeam() {

        Test.startTest();
        
        RestRequest req = new RestRequest();
        req.addHeader('AuthToken','YXBwOnBhc3N3b3Jk');
		RestResponse res = new RestResponse();

		req.requestURI = '/services/apexrest/leadapp';  //Request URL
		req.httpMethod = 'GET';//HTTP Request Type
		req.requestBody = Blob.valueof('');
        RestContext.request = req;
		RestContext.response= res;
        
        WebserviceLeadAppIndex.CampaignResponse resp1 = WebserviceLeadAppIndex.getRunningCampaignsAndStaff();

        Test.stopTest();
    
    }
    
    @isTest
    static void TestPutLeads() {

        Test.startTest();
        
        RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();
        req.addHeader('AuthToken','YXBwOnBhc3N3b3Jk');
		
        Map<String, String> mReqBody = new Map<String, String>{
        'FirstName' =>  'Heinz',
        'LastName' => 'Bogus',
        'Company' => 'Fred',
        'ExtId__c' => 'UUID123456'
        };
        
        

		req.requestURI = '/services/apexrest/leadapp';  //Request URL
		req.httpMethod = 'POST';//HTTP Request Type
		req.requestBody = Blob.valueof(JSON.serialize(mReqBody));
        RestContext.request = req;
		RestContext.response= res;
        
        WebserviceLeadAppIndex.LeadResponse resp1 = WebserviceLeadAppIndex.saveCampaignLeads();

        Test.stopTest();
    
    }
    
        @isTest
    static void TestUnauthorizedPutLeads() {

        Test.startTest();
        
        RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();
        		
        Map<String, String> mReqBody = new Map<String, String>{
        'FirstName' =>  'Heinz',
        'LastName' => 'Bogus',
        'Company' => 'Fred',
        'ExtId__c' => 'UUID123456'
        };
        
        

		req.requestURI = '/services/apexrest/leadapp';  //Request URL
		req.httpMethod = 'POST';//HTTP Request Type
		req.requestBody = Blob.valueof(JSON.serialize(mReqBody));
        RestContext.request = req;
		RestContext.response= res;
        
        WebserviceLeadAppIndex.LeadResponse resp1 = WebserviceLeadAppIndex.saveCampaignLeads();

        Test.stopTest();
    
    }

}