/**
 * Created by m.muchow on 29.07.2019.
 */

@IsTest
private class RESTServiceBoCTest {
    @TestSetup
    static void testSetup() {
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();
        Id aCustomerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Id conInstallerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId();
        Id pPartnerCommunityId = [SELECT Id FROM Profile WHERE Name ='* Partner Portal User'].Id;

        List<Account> insertAccounts = new List<Account>();
        List<Contact> insertContacts = new List<Contact>();
        List<User> insertUsers = new List<User>();

        Account aPartner = new Account(Name = 'Test Partner', RecordTypeId = aPartnerRecordTypeId);
        insertAccounts.add(aPartner);

        Account aPartner2 = new Account(Name = 'Test Partner 2', RecordTypeId = aPartnerRecordTypeId);
        insertAccounts.add(aPartner2);

        Account aCustomer = new Account(FirstName = 'FirstName', LastName = 'LastName', RecordTypeId = aCustomerRecordTypeId, BillingStreet = 'Zossener Str. 56', BillingCity = 'Berlin', BillingCountryCode = 'DE', BillingPostalCode = '10961', PersonMailingStreet = 'Zossener Str. 56', PersonMailingCity = 'Berlin', PersonMailingCountryCode = 'DE', PersonMailingPostalCode = '10961', PersonEmail = 'm.muchow@sonnen.de');
        insertAccounts.add(aCustomer);

        insert insertAccounts;

        Contact cInstaller1 = new Contact(FirstName = 'Test', LastName = 'Installer', AccountId = aPartner.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insertContacts.add(cInstaller1);

        Contact cInstaller2 = new Contact(FirstName = 'Test', LastName = 'Installer2', AccountId = aPartner.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insertContacts.add(cInstaller2);

        Contact cInstaller3 = new Contact(FirstName = 'Test', LastName = 'Installer3', AccountId = aPartner2.Id, TopMCertificationId__c = '123456', RecordTypeId = conInstallerRecordTypeId);
        insertContacts.add(cInstaller3);

        insert insertContacts;

        User uPartnerUser1 = new User(Alias = 'tInsta', Email = 'tInsta@tInsta.test', EmailEncodingKey = 'UTF-8', LastName = insertContacts[0].LastName, FirstName = insertContacts[0].FirstName, IsActive = true, ContactId = insertContacts[0].Id, Username = 'tInsta@tInsta.test', ProfileId = pPartnerCommunityId, TimeZoneSidKey = 'Europe/Berlin', LocaleSidKey = 'de_DE', LanguageLocaleKey = 'de');
        insertUsers.add(uPartnerUser1);

        User uPartnerUser2 = new User(Alias = 'tInsta3', Email = 'tInsta@tInsta.test', EmailEncodingKey = 'UTF-8', LastName = insertContacts[2].LastName, FirstName = insertContacts[2].FirstName, IsActive = true, ContactId = insertContacts[2].Id, Username = 'tInsta@tInsta2.test', ProfileId = pPartnerCommunityId, TimeZoneSidKey = 'Europe/Berlin', LocaleSidKey = 'de_DE', LanguageLocaleKey = 'de');
        insertUsers.add(uPartnerUser2);

        insert insertUsers;

    }

    static testMethod String getJSONNewCustomer() {
        Id aPartnerId = [SELECT Id FROM Account WHERE Name = 'Test Partner'].Id;
        Id uPartnerUserId = [SELECT Id FROM User WHERE Alias = 'tInsta'].Id;
        String bodyJson = '{"opportunity": {"user_id":"'+uPartnerUserId+'","partner_id": "'+aPartnerId+'","accepted_by_partner": true},"account": {"delivery_address": {"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"invoice_address":{"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "Max", "last_name": "Power", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONNoPartnerId() {
        Id uPartnerUserId = [SELECT Id FROM User WHERE Alias = 'tInsta'].Id;
        String bodyJson = '{"opportunity": {"user_id":"'+uPartnerUserId+'", "partner_id": "","accepted_by_partner": true},"account": {"delivery_address": {"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"invoice_address":{"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "Max", "last_name": "Power", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONNoPartner() {
        Id uPartnerUserId = [SELECT Id FROM User WHERE Alias = 'tInsta'].Id;
        String bodyJson = '{"opportunity": {"user_id":"'+uPartnerUserId+'", "partner_id": "123456","accepted_by_partner": true},"account": {"delivery_address": {"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"invoice_address":{"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "Max", "last_name": "Power", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONNoOwnerId() {
        Id aPartnerId = [SELECT Id FROM Account WHERE Name = 'Test Partner'].Id;
        String bodyJson = '{"opportunity": {"user_id":"","partner_id": "'+aPartnerId+'","accepted_by_partner": true},"account": {"delivery_address": {"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"invoice_address":{"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "Max", "last_name": "Power", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONOwnerNotRelated() {
        Id aPartnerId = [SELECT Id FROM Account WHERE Name = 'Test Partner'].Id;
        Id uPartnerUserId = [SELECT Id FROM User WHERE Alias = 'tInsta3'].Id;
        String bodyJson = '{"opportunity": {"user_id":"'+uPartnerUserId+'","partner_id": "'+aPartnerId+'","accepted_by_partner": true},"account": {"delivery_address": {"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"invoice_address":{"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "Max", "last_name": "Power", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONOldCustomer() {
        Id aPartnerId = [SELECT Id FROM Account WHERE Name = 'Test Partner'].Id;
        Id uPartnerUserId = [SELECT Id FROM User WHERE Alias = 'tInsta'].Id;
        String bodyJson = '{"opportunity": {"user_id":"'+uPartnerUserId+'","partner_id": "'+aPartnerId+'","accepted_by_partner": true},"account": {"delivery_address": {"street": "Zossener Str. 56", "zip_code": "10961", "city": "Berlin", "state": "", "country": "DE"},"invoice_address":{"street": "Zossener Str. 56", "zip_code": "10961", "city": "Berlin", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "FirstName", "last_name": "LastName", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONPresCustomerDifPartner() {
        Id aPartnerId = [SELECT Id FROM Account WHERE Name = 'Test Partner 2'].Id;
        Id uPartnerUserId = [SELECT Id FROM User WHERE Alias = 'tInsta3'].Id;
        String bodyJson = '{"opportunity": {"user_id":"'+uPartnerUserId+'","partner_id": "'+aPartnerId+'","accepted_by_partner": true},"account": {"delivery_address": {"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"invoice_address":{"street": "Am Riedbach 1", "zip_code": "87499", "city": "Wildpoldsried", "state": "", "country": "DE"},"phone": "0800 9293340", "mobile_phone": "0800 9293340", "lead_source": "Partner Portal", "first_name": "Max", "last_name": "Power", "salutation": "Mr.", "title": "title", "is_business": false, "agreed_to_gdpr": true, "email": "m.muchow@sonnen.de", "company": ""}}';
        return bodyJson;
    }

    static testMethod String getJSONOffer() {
        String bodyJson = '{"opportunity_id":"", "customer_guidance_url":"Customer_Guidance_Test_URL", "configuration_url":"Configuration_Test_URL"}';
        return bodyJson;
    }

    @IsTest
    static void testWrongToken() {
        Test.startTest();

        // set Wrong/No Token
        String AUTH_TOKEN = '';

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNewCustomer());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();

        System.assertEquals(401, response.statusCode, 'Expect status code 401');
        System.assertEquals('UNAUTHORIZED', bocResponse.error.get('code'));
    }

    @IsTest
    static void testEmptyRequest() {
        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('');

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();

        System.assertEquals(400, response.statusCode, 'Expect status code 400');
        System.assertEquals('EMPTY_REQUEST', bocResponse.error.get('code'));
    }

    @IsTest
    static void testNoPartnerId() {

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNoPartnerId());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();
        System.assertEquals(401, response.statusCode, 'Expect status code 401');
        System.assertEquals('MISSING_PARTNER_ID', bocResponse.error.get('code'));
    }

    @IsTest
    static void testNoPartner() {

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNoPartner());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();
        System.assertEquals(401, response.statusCode, 'Expect status code 401');
        System.assertEquals('NO_PARTNER', bocResponse.error.get('code'));
    }

    @IsTest
    static void testNoOwnerId() {

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNoOwnerId());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();
        System.assertEquals(401, response.statusCode, 'Expect status code 401');
        System.assertEquals('MISSING_USER_OR_CONTACT_ID', bocResponse.error.get('code'));
    }

    @IsTest
    static void testNoRelatedContactUser() {

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONOwnerNotRelated());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();
        System.assertEquals(401, response.statusCode, 'Expect status code 401');
        System.assertEquals('CONTACT_NOT_RELATED', bocResponse.error.get('code'));
    }

    @IsTest
    static void testNotActiveUser() {
        User uPartnerUser = [SELECT Id, IsActive FROM User WHERE Alias = 'tInsta'];
        uPartnerUser.IsActive = false;

        update uPartnerUser;

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNewCustomer());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();
        System.assertEquals(401, response.statusCode, 'Expect status code 401');
        System.assertEquals('NO_ACTIVE_USER', bocResponse.error.get('code'));
    }

    @IsTest
    static void testNewAccount() {

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONNewCustomer());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();

        Id aCustomerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();

        List<Account> aCustomerList = [SELECT Id FROM Account WHERE RecordTypeId =: aCustomerRecordTypeId];

        System.assertEquals(200, response.statusCode, 'Expect status code 200');
        System.assertEquals(2, aCustomerList.size());
    }

    @IsTest
    static void testAccountPresent() {
        Account pAccount = [SELECT Id, PrimaryContact__c FROM Account WHERE Name = 'Test Partner' LIMIT 1];
        Contact pContact = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Installer' LIMIT 1];

        pAccount.PrimaryContact__c = pContact.Id;
        update pAccount;

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONOldCustomer());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();

        Id aCustomerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();

        List<Account> aCustomerList = [SELECT Id FROM Account WHERE RecordTypeId =: aCustomerRecordTypeId];

        System.assertEquals(200, response.statusCode, 'Expect status code 200');
        System.assertEquals(1, aCustomerList.size());
    }

    @IsTest
    static void testOpportunityPresent() {
        Id oRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('SalesSolutionPartnerPortal').getRecordTypeId();

        Account cAccount = [SELECT Id FROM Account WHERE FirstName = 'FirstName' AND LastName = 'LastName' LIMIT 1];

        Account pAccount = [SELECT Id, PrimaryContact__c FROM Account WHERE Name = 'Test Partner' LIMIT 1];
        Contact pContact = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Installer' LIMIT 1];

        pAccount.PrimaryContact__c = pContact.Id;
        update pAccount;

        Opportunity oPresent = new Opportunity(Name = 'Opp Present', StageName = 'Open', CloseDate = System.today()+1, AccountId = cAccount.Id, ProposedSBC__c = pAccount.Id, RecordTypeId = oRecordTypeId);
        insert oPresent;

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'customer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(getJSONOldCustomer());

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        Test.stopTest();

        System.assertEquals(400, response.statusCode, 'Expect status code 400');
        System.assertEquals('OPPORTUNITY_PRESENT', bocResponse.error.get('code'));
    }

    @IsTest
    static void testOppFromOtherPartner() {

        Test.startTest();

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request1 = new RestRequest();
        RestResponse response1 = new RestResponse();

        request1.requestURI = '/bocEndpoint/';
        request1.addParameter('token', AUTH_TOKEN);
        request1.addParameter('type', 'customer');
        request1.httpMethod = 'POST';
        request1.requestBody = Blob.valueOf(getJSONNewCustomer());

        RestContext.request = request1;
        RestContext.response = response1;

        RESTServiceBoC.Response bocResponse1 = RESTServiceBoC.handlePost();

        RestRequest request2 = new RestRequest();
        RestResponse response2 = new RestResponse();

        // new Partner sames Customer
        request2.requestURI = '/bocEndpoint/';
        request2.addParameter('token', AUTH_TOKEN);
        request2.addParameter('type', 'customer');
        request2.httpMethod = 'POST';
        request2.requestBody = Blob.valueOf(getJSONPresCustomerDifPartner());

        RestContext.request = request2;
        RestContext.response = response2;

        RESTServiceBoC.Response bocResponse2 = RESTServiceBoC.handlePost();

        Test.stopTest();

        Id aCustomerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();

        List<Account> aCustomerList = [SELECT Id FROM Account WHERE RecordTypeId =: aCustomerRecordTypeId];
        List<Opportunity> oppList = [SELECT Id, ProposedSBC__c FROM Opportunity];

        System.assertEquals(200, response1.statusCode, 'Expect status code 200');
        System.assertEquals(200, response2.statusCode, 'Expect status code 200');
        System.assertEquals(2, aCustomerList.size());
        System.assertEquals(2, oppList.size());
        System.assertNotEquals(oppList[0].ProposedSBC__c, oppList[1].ProposedSBC__c);
    }

    @IsTest
    static void testOfferProcess() {

        // call testMethod to create Account and Opportunity
        testNewAccount();

        // get created Opportunity Id
        Id oppId = [SELECT Id FROM Opportunity].Id;

        // get String of Offer JSON
        String offerString = getJSONOffer();

        // add Opportunity Id to JSON String
        Map<String, Object> offerMap = (Map<String, Object>) JSON.deserializeUntyped(offerString);
        offerMap.put('opportunity_id', String.valueOf(oppId));

        offerString = JSON.serialize(offerMap);

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'offer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(offerString);

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        List<Opportunity> oppList = [SELECT Id, SendOfferEmail__c, StageName, ConfigurationURL__c, CustomerGuidanceURL__c FROM Opportunity WHERE Id =: oppId];

        System.assertEquals(200, response.statusCode, 'Expect status code 200');
        System.assertEquals('Offer Sent', oppList[0].StageName);
        System.assertEquals(true, oppList[0].SendOfferEmail__c);
        System.assertEquals(offerMap.get('configuration_url'), oppList[0].ConfigurationURL__c);
        System.assertEquals(offerMap.get('customer_guidance_url'), oppList[0].CustomerGuidanceURL__c);
    }

    @IsTest
    static void testOfferNoOpp() {
        // call testMethod to create Account and Opportunity
        testNewAccount();

        // get created Opportunity Id
        Id oppId = [SELECT Id FROM Opportunity].Id;

        // get String of Offer JSON
        String offerString = getJSONOffer();

        // add Opportunity Id to JSON String
        Map<String, Object> offerMap = (Map<String, Object>) JSON.deserializeUntyped(offerString);
        offerMap.put('opportunity_id', '123456789');

        offerString = JSON.serialize(offerMap);

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'offer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(offerString);

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        List<Opportunity> oppList = [SELECT Id, SendOfferEmail__c, StageName, ConfigurationURL__c, CustomerGuidanceURL__c FROM Opportunity WHERE Id =: oppId];

        System.assertEquals(400, response.statusCode, 'Expect status code 400');
        System.assertEquals('NO_OPEN_OPPORTUNITY', bocResponse.error.get('code'));
        System.assertEquals('Open', oppList[0].StageName);
        System.assertEquals(false, oppList[0].SendOfferEmail__c);
        System.assertEquals(null, oppList[0].ConfigurationURL__c);
        System.assertEquals(null, oppList[0].CustomerGuidanceURL__c);
    }

    @IsTest
    static void testOfferNoOpenOpp() {
        // call testMethod to create Account and Opportunity
        testNewAccount();

        // get created Opportunity Id
        Opportunity opp = [SELECT Id,StageName FROM Opportunity LIMIT 1];

        // get String of Offer JSON
        String offerString = getJSONOffer();

        // add Opportunity Id to JSON String
        Map<String, Object> offerMap = (Map<String, Object>) JSON.deserializeUntyped(offerString);
        offerMap.put('opportunity_id', String.valueOf(opp.Id));

        offerString = JSON.serialize(offerMap);

        // change Stage of Opportunity
        opp.StageName = 'Closed - Dead';
        update opp;

        // get Token from Custom Metadata
        String AUTH_TOKEN = [SELECT AuthenticationToken__c FROM RESTBoCEndpoint__mdt WHERE Label = 'API'].AuthenticationToken__c;

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/bocEndpoint/';
        request.addParameter('token', AUTH_TOKEN);
        request.addParameter('type', 'offer');
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(offerString);

        RestContext.request = request;
        RestContext.response = response;

        RESTServiceBoC.Response bocResponse = RESTServiceBoC.handlePost();

        List<Opportunity> oppList = [SELECT Id, SendOfferEmail__c, StageName, ConfigurationURL__c, CustomerGuidanceURL__c FROM Opportunity WHERE Id =: opp.Id];

        System.assertEquals(400, response.statusCode, 'Expect status code 400');
        System.assertEquals('NO_OPEN_OPPORTUNITY', bocResponse.error.get('code'));
        System.assertEquals('Closed - Dead', oppList[0].StageName);
        System.assertEquals(false, oppList[0].SendOfferEmail__c);
        System.assertEquals(null, oppList[0].ConfigurationURL__c);
        System.assertEquals(null, oppList[0].CustomerGuidanceURL__c);
    }
}