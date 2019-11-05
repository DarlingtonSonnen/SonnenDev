@isTest
public class Test_CustomerVerifyTokenService {   
    
    private static Id personAccRecType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Private' and SObjectType = 'Account'].Id;
    
    private static final String NEW_EMAIL = 'tester@sonnentest.com';

    @testSetup
    public static void setup() {
        insert new Customer_Portal_Settings__c(
                Portal_Profile_Name__c = 'Customer Community User',
                Token_Key__c = 'edf3fc1c1037828df6ef1037828df6ef'
        );
        
        String email = 'example@test.de';
        Account acc = new Account(
                LastName = 'Tester',
                RecordTypeId = personAccRecType,
                PersonEmail = email
        );
        insert acc;
        
        Contact con = [SELECT Id FROM Contact];
        con.UnconfirmedEmailAddress__c = NEW_EMAIL;
        update con;
    }

    @isTest
    public static void canHandleEmptyToken() {
        CustomerVerifyTokenService.TokenResult result = verifyToken('', CustomerVerifyTokenService.TOKEN_TYPE_INVITATION);

        System.assert(!result.valid);
    }

    @isTest
    public static void canHandleExpiredToken() {
        CustomerToken token = new CustomerToken(DateTime.now().addDays(-1), UserInfo.getUserId());
        String tokenString = token.encodeToken();
        update new User(
                Id = UserInfo.getUserId(),
                Invitation_Token__c = tokenString
        );

        CustomerVerifyTokenService.TokenResult result = verifyToken(tokenString, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION);

        System.assert(!result.valid);
        System.assertEquals(UserInfo.getUserId(), result.user_id);
        System.assertEquals(null, [SELECT Invitation_Token__c FROM User WHERE Id = :UserInfo.getUserId()].Invitation_Token__c);
    }

    @isTest
    public static void canVerifyInvitationToken() {
        CustomerToken token = new CustomerToken(DateTime.now().addDays(1), UserInfo.getUserId());
        String tokenString = token.encodeToken();
        update new User(
            Id = UserInfo.getUserId(),
            Invitation_Token__c = tokenString
        );

        CustomerVerifyTokenService.TokenResult result = verifyToken(tokenString, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION);

        System.assert(result.valid);
        System.assertEquals(UserInfo.getUserId(), result.user_id);
        System.assertEquals(null, [SELECT Invitation_Token__c FROM User WHERE Id = :UserInfo.getUserId()].Invitation_Token__c);
    }

    @isTest
    public static void canVerifyPasswordToken() {
        CustomerToken token = new CustomerToken(DateTime.now().addDays(1), UserInfo.getUserId());
        String tokenString = token.encodeToken();
        update new User(
                Id = UserInfo.getUserId(),
                Reset_Password_Token__c = tokenString
        );

        CustomerVerifyTokenService.TokenResult result = verifyToken(tokenString, CustomerVerifyTokenService.TOKEN_TYPE_RESET_PW);

        System.assert(result.valid);
        System.assertEquals(UserInfo.getUserId(), result.user_id);
        System.assertEquals(null, [SELECT Reset_Password_Token__c FROM User WHERE Id = :UserInfo.getUserId()].Reset_Password_Token__c);
    }

    @isTest
    public static void canVerifyEmailToken() {
        CustomerToken token = new CustomerToken(DateTime.now().addDays(1), UserInfo.getUserId());
        String tokenString = token.encodeToken();
        
        Contact con = [SELECT Id FROM Contact];
        User testUsr = CustomerCommunityControlsCtr.createCommunityUser(con.Id, false);
		testUsr.Email_Confirmation_Token__c = tokenString;
        update testUsr;

        CustomerVerifyTokenService.TokenResult result = verifyToken(tokenString, CustomerVerifyTokenService.TOKEN_TYPE_EMAIL);

        System.assert(result.valid);
        System.assertEquals(UserInfo.getUserId(), result.user_id);
        
        testUsr = [SELECT Email, Username, Email_Confirmation_Token__c FROM User WHERE Id = :testUsr.Id];
        System.assertEquals(NEW_EMAIL, testUsr.Email);
        System.assertEquals(NEW_EMAIL + '.sonnen', testUsr.Username);        
        System.assertEquals(null, testUsr.Email_Confirmation_Token__c);
    }

    private static CustomerVerifyTokenService.TokenResult verifyToken(String token, String tokenType) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = 'https://test.com/' + tokenType;
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        CustomerVerifyTokenService.TokenResult result = CustomerVerifyTokenService.verifyToken(token, true);

        System.debug(result);

        return result;
    }

}