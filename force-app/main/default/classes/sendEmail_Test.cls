@isTest
private class sendEmail_Test {

	@testSetup static void createObjects() {

		Account a = new Account(Name = 'Test Enterprise');
		insert a;

		Contact c = new Contact(Email = 'test@duck.com', LastName = 'Tester1',  AccountId = a.Id);
		insert c;
	}
	
	@isTest static void test_method_one() {
		List<sendEmail.sendEmailActionRequest> reqList = new List<sendEmail.sendEmailActionRequest>();
		sendEmail.sendEmailActionRequest req = new sendEmail.sendEmailActionRequest();

		EmailTemplate tmpl = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1];
		OrgWideEmailAddress fromEmail = [SELECT Id, IsAllowAllProfiles, Address FROM OrgWideEmailAddress LIMIT 1];
		fromEmail.IsAllowAllProfiles = true;
		
		Id accId = [SELECT Id FROM Account WHERE Name = 'Test Enterprise'].Id;
		Id ctId = [SELECT Id FROM Contact WHERE LastName = 'Tester1' ].Id;
				
		req.orgWideFromEmail = fromEmail.Address; 
		req.toAddress = 'b.jarmolinski@sonnen.de';
		req.targetObjectId = ctId;
		req.apitemplateName = tmpl.DeveloperName;
		req.whatId = accId;
		req.saveAsActivity = true;
		reqList.add(req);

		Test.startTest();
		List<sendEmail.sendEmailActionResult> res = sendEmail.sendEmails(reqList);
		Test.stopTest();

		System.debug(res[0].sent);
		System.assertEquals(true, res[0].sent);
	}
    
    @isTest static void test_method_two() {

		List<sendEmail.sendEmailActionRequest> reqList = new List<sendEmail.sendEmailActionRequest>();
		
        Id accId = [SELECT Id FROM Account WHERE Name = 'Test Enterprise'].Id;
        Id ctId = [SELECT Id FROM Contact WHERE LastName = 'Tester1' ].Id;
     
        EmailTemplate tmpl = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1];
        OrgWideEmailAddress fromEmail = [SELECT Id, IsAllowAllProfiles, Address FROM OrgWideEmailAddress LIMIT 1];
        fromEmail.IsAllowAllProfiles = true;
        
        for (Integer i=0; i< 200; i++) {
        	sendEmail.sendEmailActionRequest req = new sendEmail.sendEmailActionRequest();

            req.orgWideFromEmail = fromEmail.Address; 
            req.toAddress = 'b.jarmolinski@sonnen.de';
            req.targetObjectId = ctId;
            req.apitemplateName = tmpl.DeveloperName;
            req.whatId = accId;
            req.saveAsActivity = true;
            reqList.add(req);

        }
        Test.startTest();
		List<sendEmail.sendEmailActionResult> res = sendEmail.sendEmails(reqList);
        Test.stopTest();
        
        System.debug(res[0].sent);
       	System.assertEquals(true, res[0].sent);
        
	}
	@isTest static void test_method_three() {

		Id accId = [SELECT Id FROM Account WHERE Name = 'Test Enterprise'].Id;
		Id ctId = [SELECT Id FROM Contact WHERE LastName = 'Tester1' ].Id;

		List<sendEmail.sendEmailActionRequest> reqList = new List<sendEmail.sendEmailActionRequest>();
		sendEmail.sendEmailActionRequest req = new sendEmail.sendEmailActionRequest();

		OrgWideEmailAddress fromEmail = [SELECT Id, IsAllowAllProfiles, Address FROM OrgWideEmailAddress LIMIT 1];
		fromEmail.IsAllowAllProfiles = true;


		req.orgWideFromEmail = fromEmail.Address;
		req.toAddress = 'b.jarmolinski@sonnen.de';
		req.targetObjectId = ctId;
		req.Subject = 'Test email';
		req.htmlBody = '<html><p>new email<p><html>';
		req.whatId = accId;
		req.saveAsActivity = true;
		reqList.add(req);

		Test.startTest();
		List<sendEmail.sendEmailActionResult> res = sendEmail.sendEmails(reqList);
		Test.stopTest();

		System.debug(res[0].sent);
		System.assertEquals(true, res[0].sent);

	}
}