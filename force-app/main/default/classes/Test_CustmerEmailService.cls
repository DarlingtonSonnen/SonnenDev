@isTest
public class Test_CustmerEmailService {

    private static Id personAccRecType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Private' and SObjectType = 'Account'].Id;
    private static Id contractRecType = [SELECT Id FROM RecordType WHERE DeveloperName = 'sonnenStrom' AND SObjectType = 'Contract'].Id;

    @testSetup
    public static void setup() {
        insert new Customer_Portal_Settings__c(
                Token_Key__c = 'edf3fc1c1037828df6ef1037828df6ef',
                Expire_Token_Invitation__c = 1,
                Expire_Token_Reset_PW__c = 1,
                Expire_Token_Confirm_Email__c = 1,
                Contract_Rec_Type_Name__c = 'sonnenStrom'
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
    public static void canSendMailSoap() {
        Id accountId = [SELECT Id FROM Account].Id;
        Test.startTest();
        String response = CustmerEmailService.sendEmailSoap(accountId, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION);
        Test.stopTest();

        System.assertEquals('', response);

        Contact con = [SELECT Invitation_Token_Url__c FROM Contact];
        System.assertNotEquals(null, con.Invitation_Token_Url__c);
    }

    @isTest
    public static void canSendMailRest() {
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerVerifyTokenService.TOKEN_TYPE_EMAIL;
        RestContext.request = req;

        Id contactId = [SELECT Id FROM Contact].Id;
        String response = CustmerEmailService.sendEmailRest(contactId);

        System.assertEquals('', response);

        Contact con = [SELECT Email_Confirmation_Token_Url__c FROM Contact];
        System.assertNotEquals(null, con.Email_Confirmation_Token_Url__c);
    }

    @isTest
    public static void canSendPwResetRest() {
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerVerifyTokenService.TOKEN_TYPE_RESET_PW;
        RestContext.request = req;

        Id contactId = [SELECT Id FROM Contact].Id;
        String response = CustmerEmailService.sendEmailRest(contactId);

        System.assertEquals('', response);

        Contact con = [SELECT Reset_Password_Token_Url__c FROM Contact];
        System.assertNotEquals(null, con.Reset_Password_Token_Url__c);
    }

    @isTest
    public static void canSendMailWelcome() {
        RestRequest req = new RestRequest();
        req.requestURI = 'https://test.com/' +  CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_WELCOME;
        RestContext.request = req;

        Contact con = [SELECT Id, AccountId FROM Contact];
        insert new Contract(
                RecordTypeId = contractRecType,
                Status = 'Draft',
                StartDate = Date.today(),
                Type__c = 'Solar',
                AccountId = con.AccountId,
                TariffType__c = 'sonnenStrom'
        );
        String response = CustmerEmailService.sendEmailRest(con.Id);

        System.assertEquals('', response);

        Contact conAfterTest = [SELECT Invitation_Token_Url__c FROM Contact];
        System.assertNotEquals(null, conAfterTest.Invitation_Token_Url__c);
    }

    private static User createTestUser(Id contactId) {
        User myUser = [
                SELECT TimeZoneSidKey,
                        LocaleSidKey,
                        EmailEncodingKey,
                        LanguageLocaleKey,
                        ProfileId
                FROM User
                WHERE Id = :UserInfo.getUserId()
        ];

        myUser.Id = UserInfo.getUserId();
        myUser.UserRoleId = [SELECT Id FROM UserRole WHERE Name = 'CEO' LIMIT 1].Id;
        update myUser;

        User usr = new User(
                Username = 'test87362872@test.com',
                LastName = 'tester',
                Email = 'test87362872@test.com',
                Alias = 'tstr',
                TimeZoneSidKey = myUser.TimeZoneSidKey,
                LocaleSidKey = myUser.LocaleSidKey,
                EmailEncodingKey = myUser.EmailEncodingKey,
                ProfileId = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1].Id,
                LanguageLocaleKey = myUSer.LanguageLocaleKey,
                ContactId = contactId
        );
        insert usr;
        return usr;
    }

}