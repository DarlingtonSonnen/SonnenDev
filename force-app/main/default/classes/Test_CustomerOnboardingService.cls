@isTest
public class Test_CustomerOnboardingService {
    
    private static Id personAccRecType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Private' and SObjectType = 'Account'].Id;
    private static Id nonPersonAccRecType = [SELECT Id FROM RecordType WHERE DeveloperName != 'Private' and SObjectType = 'Account' LIMIT 1].Id;

    
    @testSetup
    public static void setup() {
        Account acc = new Account(
            Name = 'Tester',
            RecordTypeId = nonPersonAccRecType
        );
        insert acc;
        
        insert new Customer_Portal_Settings__c(
                Portal_Profile_Name__c = 'Customer Community User',
            	Battery_Placeholder_Account_Id__c = acc.Id,
            	Person_Rec_Type__c = personAccRecType
        );
    }

    @isTest
    public static void canMoveAssetToNewAccountNoContact() {
		Account acc = [SELECT Id FROM Account];
        
        String email = 'TestmanSonnenTester@example.de';
        
        String serialNumber = '1234556';
        Asset ast = new Asset(
        	AccountId = acc.Id,
            Name = serialNumber,
            SerialNumber = serialNumber
        );
        insert ast;
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            email,
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        ast = [SELECT AccountId FROM Asset];
        System.assertNotEquals(null, ast.AccountId);
        System.assertNotEquals(acc.Id, ast.AccountId);        
        
        System.assertEquals(ast.AccountId, res.account_id);
        System.assertNotEquals(null, res.contact_id);
        System.assertEquals(null, res.errors);
        
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :ast.AccountId].size());
    }

    @isTest
    public static void canLinkAssetToAccountWithContact() {
		Account acc = new Account(
            Name = 'Testerx',
            RecordTypeId = nonPersonAccRecType
        );
        insert acc;
        
        
        String email = 'TestmanSonnenTester@example.de';
        Contact con = new Contact(
        	LastName = 'tester',
            Email = email + '.cloud',
            AccountId = acc.Id
        );
        insert con;
        
        Contact con2 = new Contact(
        	LastName = 'tester',
            Email = email,
            AccountId = acc.Id
        );
        insert con2;
        
        String serialNumber = '1234556';
        Asset ast = new Asset(
        	AccountId = acc.Id,
            ContactId = con.Id,
            Name = serialNumber,
            SerialNumber = serialNumber
        );
        insert ast;
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            email,
            serialNumber,
            '',
            ''
        );
        System.debug(res);
        Test.stopTest();
        
        ast = [SELECT AccountId FROM Asset];
        System.assertEquals(acc.Id, ast.AccountId);        
        
        System.assertEquals(ast.AccountId, res.account_id);
        System.assertEquals(con.Id, res.contact_id);
        System.assertEquals(null, res.errors);
        
        System.assertEquals(1, [SELECT Id FROM User WHERE ContactId = :con.Id].size());
    }

    @isTest
    public static void canDealWithMissingAsset() {
        
        String serialNumber = '1234556';
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            'TestmanSonnenTester@example.de',
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        System.assertEquals(0, [SELECT Id FROM Asset].size());
        
        System.assertNotEquals(null, res.account_id);
        System.assertNotEquals(null, res.contact_id);
        System.assert(res.errors.contains(serialNumber));
    }

    @isTest
    public static void canConnectStockItemInsteadOfAsset() {
        
        String serialNumber = '1234556';
        
        StockItem__c item = new StockItem__c(
        	SerialNumber__c = serialNumber
        );
        insert item;
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            'TestmanSonnenTester@example.de',
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        System.assertEquals(0, [SELECT Id FROM Asset].size());
        System.assertEquals(1, [SELECT Id FROM StockItem__c WHERE Account__c = :res.account_id].size());
    }

    @isTest
    public static void canLinkToExistingAccount() {
        String email = 'TestmanSonnenTester@example.de';
		Account acc = new Account(
        	PersonEmail = email,
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = 'test',
            LastName = 'tester'
        );
        insert acc;
        
        String serialNumber = '1234556';
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            email,
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        System.assertEquals(acc.Id, res.account_id);
        
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :acc.Id].size());
    }

    @isTest
    public static void canLinkToExistingAccountWithDifferentEmail() {
        String email = 'TestmanSonnenTester@example.de';
		Account acc = new Account(
        	PersonEmail = email,
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = 'test',
            LastName = 'tester'
        );
        insert acc;
        
        String serialNumber = '1234556';
        Asset ast = new Asset(
        	AccountId = acc.Id,
        	ContactId = [SELECT Id FROM Contact].Id,
            Name = serialNumber,
            SerialNumber = serialNumber
        );
        insert ast;
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            'somemail@tester.sonnen',
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        ast = [SELECT AccountId, SerialNumber FROM Asset];
        System.assertEquals(acc.Id, ast.AccountId);
        
        System.assertEquals(acc.Id, res.account_id);
        
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :acc.Id].size());
    }

    @isTest
    public static void canLinkToExistingAccountWithDifferentEmailAssedContactNotLinked() {
        String email = 'TestmanSonnenTester@example.de';
		Account acc = new Account(
        	PersonEmail = email,
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = 'test',
            LastName = 'tester'
        );
        insert acc;
        
        String serialNumber = '1234556';
        Asset ast = new Asset(
        	AccountId = acc.Id,
            Name = serialNumber,
            SerialNumber = serialNumber
        );
        insert ast;
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            'somemail@tester.sonnen',
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        ast = [SELECT AccountId, SerialNumber FROM Asset];
        System.assertEquals(acc.Id, ast.AccountId);
        
        System.assertEquals(acc.Id, res.account_id);
        
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :acc.Id].size());
    }

    @isTest
    public static void canCreateUserForNonPersonAccount() {
		Account acc = new Account(
            Name = 'test company',
            RecordTypeId = nonPersonAccRecType
        );
        insert acc;
        
        String serialNumber = '1234556';
        Asset ast = new Asset(
        	AccountId = acc.Id,
            Name = serialNumber,
            SerialNumber = serialNumber
        );
        insert ast;
        
        Test.startTest();
        setBatterTypeRequest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	'Test',
            'Tester',
            'TestmanSonnenTester@example.de',
            serialNumber,
            '',
            ''
        );
        Test.stopTest();
        
        System.assertEquals(null, res.errors);
        
        ast = [SELECT AccountId FROM Asset];
        System.assertEquals(acc.Id, ast.AccountId);        
        System.assertEquals(acc.Id, res.account_id);
        
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :acc.Id].size());
    }
    
    @isTest
    public static void canDoEmailOnboarding() {
        String email = 'TestmanSonnenTester@example.de';
		Account acc = new Account(
        	PersonEmail = email,
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = 'test',
            LastName = 'tester'
        );
        insert acc;
        
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerOnboardingService.ONBOARDING_TYPE_EMAIL;
        RestContext.request = req;
        
        Test.startTest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	null,
            null,
            email,
            null,
            null,
            null
        );
        
        req.requestURI = 'https://test.com/' +  CustomerOnboardingService.ONBOARDING_TYPE_CREATE_USER;
        RestContext.request = req;
        res = CustomerOnboardingService.onboardingEntryPoint(
        	null,
            null,
            null,
            null,
            res.account_id,
            res.contact_id
        );
        Test.stopTest();
        
        System.debug(res);
        
        System.assertEquals(null, res.errors);
        System.assertNotEquals(null, res.contact_id);
        System.assertNotEquals(null, res.account_id);
        System.assertNotEquals(null, res.user_id);
    }
    
    @isTest
    public static void canDoBatteryOnboardingByContactId() {
        String email = 'TestmanSonnenTester@example.de';
		Account acc = new Account(
        	PersonEmail = email,
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = 'test',
            LastName = 'tester'
        );
        insert acc;
        
        Contact con = [SELECT Id FROM Contact WHERE AccountId = :acc.Id];
        
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerOnboardingService.ONBOARDING_TYPE_BATTERY;
        RestContext.request = req;
        
        Test.startTest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	null,
            null,
            email,
            '12345',
            null,
            con.Id
        );
        Test.stopTest();
        
        System.debug(res);
        
        System.assertNotEquals(null, res.contact_id);
        System.assertNotEquals(null, res.account_id);
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :acc.Id].size());
    }
    
    @isTest
    public static void canDoBatteryOnboardingWithPersonAcc() {
        String email = 'TestmanSonnenTester@example.de';
		Account acc = new Account(
        	PersonEmail = email,
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = 'test',
            LastName = 'tester'
        );
        insert acc;
        
        String serialNumber = '1234556';
        Asset ast = new Asset(
        	AccountId = acc.Id,
            Name = serialNumber,
            SerialNumber = serialNumber
        );
        insert ast;
                
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerOnboardingService.ONBOARDING_TYPE_BATTERY;
        RestContext.request = req;
        
        Test.startTest();
        CustomerOnboardingService.Result res = CustomerOnboardingService.onboardingEntryPoint(
        	null,
            'tester',
            email,
            serialNumber,
            null,
            null
        );
        Test.stopTest();
        
        System.debug(res);
        
        System.assertEquals(null, res.errors);
        System.assertNotEquals(null, res.contact_id);
        System.assertNotEquals(null, res.account_id);
        System.assertEquals(1, [SELECT Id FROM User WHERE AccountId = :acc.Id].size());
    }
    
    private static void setBatterTypeRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerOnboardingService.ONBOARDING_TYPE_BATTERY;
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
    }

}