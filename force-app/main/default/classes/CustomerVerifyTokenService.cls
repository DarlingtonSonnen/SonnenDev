@RestResource(urlMapping='/verifytoken/*')
global class CustomerVerifyTokenService {

    public static final String TOKEN_TYPE_INVITATION_WELCOME = 'welcome';
    public static final String TOKEN_TYPE_INVITATION = 'invitation';
    public static final String TOKEN_TYPE_INVITATION_SERVICE = 'invitation_serviceportal';
    public static final String TOKEN_TYPE_INVITATION_CHARGER = 'invitationcharger';
    public static final String TOKEN_TYPE_RESET_PW = 'resetpassword';
    public static final String TOKEN_TYPE_RESET_PW_SERVICE = 'resetpassword_serviceportal';
    public static final String TOKEN_TYPE_EMAIL = 'emailconfirmation';

    @HttpPost
    global static TokenResult verifyToken(String token, Boolean revoke_token) {
        RestRequest req = RestContext.request;
        String tokenType = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);

        TokenResult result = new TokenResult();

        RestResponse res = RestContext.response;
        try {
            if (String.isBlank(token)) {
                res.statusCode = 400;
                result.errors = 'Token must not be empty';
            }

            List<User> tokenUsers;
            if (tokenType == TOKEN_TYPE_INVITATION || tokenType == TOKEN_TYPE_INVITATION_CHARGER) {
                tokenUsers = [SELECT Id FROM User WHERE Invitation_Token__c = :token];
            } else if (tokenType == TOKEN_TYPE_RESET_PW) {
                tokenUsers = [SELECT Id FROM User WHERE Reset_Password_Token__c = :token];
            } else if (tokenType == TOKEN_TYPE_EMAIL) {
                tokenUsers = [SELECT Contact.UnconfirmedEmailAddress__c FROM User WHERE Email_Confirmation_Token__c = :token];
            } else {
                res.statusCode = 400;
                result.errors = 'Invalid token type: ' + tokenType;
            }

            if (tokenUsers != null && tokenUsers.size() == 1) {
                User tokenUser = tokenUsers.get(0);
                result = validateToken(tokenType, token, tokenUser);
                if(revoke_token || tokenType == TOKEN_TYPE_EMAIL) {
                    update tokenUser;
                }
            }

        } catch (Exception e) {
            res.statusCode = 400;
            result.errors = 'Failed to verify token, reason: ' + e.getMessage();
            System.debug(e);
        }

        return result;
    }

    private static TokenResult validateToken(String tokenType, String tokenString, User usr) {
        TokenResult result = new TokenResult();

        if (tokenType == TOKEN_TYPE_INVITATION || tokenType == TOKEN_TYPE_INVITATION_CHARGER) {
            usr.Invitation_Token__c = null;
        } else if (tokenType == TOKEN_TYPE_RESET_PW) {
            usr.Reset_Password_Token__c = null;
        } else if (tokenType == TOKEN_TYPE_EMAIL) {
            usr.Email_Confirmation_Token__c = null;
            usr.Email = usr.Contact.UnconfirmedEmailAddress__c;
            usr.Username = usr.Contact.UnconfirmedEmailAddress__c + '.sonnen';
        }

        CustomerToken token = CustomerToken.decodeToken(tokenString);
        result.user_id = token.userId;

        if(!token.isExpired()) {
            result.valid = true;
        }

        return result;
    }

    global class TokenResult {
        public Boolean valid = false;
        public String user_id;
        public String errors;
    }
}