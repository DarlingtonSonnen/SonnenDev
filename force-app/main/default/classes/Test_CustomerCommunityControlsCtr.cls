@isTest
public with sharing class Test_CustomerCommunityControlsCtr {

    private static Id personAccRecType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Private' and SObjectType = 'Account'].Id;

    @testSetup
    public static void setup() {
        insert new Customer_Portal_Settings__c(
                Portal_Profile_Name__c = 'Customer Community User',
            	Admin_Login_Url__c = 'https://example.com',
            	Admin_Login_Service_Url__c = 'https://example.com',
            	Expire_Token_Invitation__c = 10,
                Token_Key__c = 'edf3fc1c1037828df6ef1037828df6ef'
        );

        String email = 'example@test.de';
        Account acc = new Account(
                LastName = 'Tester',
                RecordTypeId = personAccRecType,
                PersonEmail = email
        );
        insert acc;
    }

    @isTest
    public static void canCreateCommunityUser() {
        Contact con = [SELECT Id FROM Contact];

        CustomerCommunityControlsCtr.Result result = CustomerCommunityControlsCtr.createCommunityUserService(con.Id, true);
        System.assertNotEquals(null, result.user);
        System.assertEquals(null, result.error);

        User usr = CustomerCommunityControlsCtr.getCommunityUser(con.Id);
        System.assertNotEquals(null, usr);
		System.assert([SELECT ServicePortal__c FROM Contact].ServicePortal__c);
    }
    
    @isTest
    public static void cantUpdatePasswordForNonPortalUser() {
        CustomerCommunityControlsCtr.Result res = CustomerCommunityControlsCtr.setUserPassword(UserInfo.getUserId(), '123TestPW!');        
        System.assertNotEquals(null, res.error);        
    }
    
    @isTest
    public static void cantUpdatePasswordIfPasswordIsToShort() {
        Contact con = [SELECT Id FROM Contact];

        CustomerCommunityControlsCtr.Result result = CustomerCommunityControlsCtr.createCommunityUserService(con.Id, false);
        CustomerCommunityControlsCtr.Result res = CustomerCommunityControlsCtr.setUserPassword(result.user.Id, '123');        
        System.assertNotEquals(null, res.error);        
    }
    
    @isTest
    public static void canUpdatePassword() {
        Contact con = [SELECT Id FROM Contact];

        CustomerCommunityControlsCtr.Result result = CustomerCommunityControlsCtr.createCommunityUserService(con.Id, false);
        
        Test.startTest();
        CustomerCommunityControlsCtr.Result res = CustomerCommunityControlsCtr.setUserPassword(result.user.Id, '123TestPW!');      
        Test.stopTest();
        System.assertEquals(null, res.error);        
    }
    
    @isTest
    public static void canSendMail() {
        Contact con = [SELECT Id FROM Contact];
        
        Test.startTest();
        CustomerCommunityControlsCtr.sendEmail(con.Id, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION);     
        Test.stopTest();        
    }
    
    @isTest
    public static void canGetSettingValues() {
        Test.startTest();
        System.assertNotEquals(null, CustomerCommunityControlsCtr.getAdminLoginUrl());     
        System.assertNotEquals(null, CustomerCommunityControlsCtr.getAdminLoginServiceUrl());     
        System.assertNotEquals(null, CustomerCommunityControlsCtr.getCurrentUser());     
        Test.stopTest();        
    }

}