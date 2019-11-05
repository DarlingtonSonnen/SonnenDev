/**
 * Provides webservices to send provisioning emails to a sonnen customer portal user.
 *
 * Configuration can be found in the custom setting:
 * Customer_Portal_Settings__c
 *
 */
@RestResource(urlMapping='/customeremail/*')
global class CustmerEmailService {

    public static final String ENERGY_CONTRACT_REC_NAME = 'sonnenStrom';

    static webService String sendEmailSoap(String accountId, String emailType) {
        if(String.isEmpty(accountId)) {
            return 'Account Id must not be empty';
        }

        List<Contact> cons = [SELECT Id FROM Contact WHERE AccountId = :accountId LIMIT 1];

        if(cons.isEmpty()) {
            return 'Account has no contact';
        }

        return sendEmail(cons.get(0).Id, emailType);
    }

    @HttpPost
    global static String sendEmailRest(String contact_id) {
        RestRequest req = RestContext.request;
        String emailType = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);

        RestResponse res = RestContext.response;

        String response = sendEmail(contact_id, emailType);

        if (String.isNotEmpty(response)) {
            res.statusCode = 400;
        }

        return response;
    }

    static webService String sendEmail(String contactId, String emailType) {
        if (String.isEmpty(contactId)) {
            return 'Contact Id must not be empty';
        }

        List<User> users = findUsers(contactId);

        if (users.isEmpty()) {
            return 'No user found for Contact Id';
        }

        Contact con = [SELECT Email, Language__c FROM Contact WHERE Id = :contactId];
        String language = con.Language__c;
        String country = [
            SELECT BillingCountryCode 
              FROM Account 
             WHERE Id in (SELECT AccountId FROM Contact WHERE Id = :contactId)
        ].BillingCountryCode;

        User usr = users.get(0);

        String invitationToken = '';
        String resetPwToken = '';
        String emailConfigToken = '';
        
        String servicesEmailId = CustomerSettingsHelper.welcomeEmailAddressId();
        String sonnenEmailId = CustomerSettingsHelper.portalEmailAddressId();

        Messaging.SingleEmailMessage mail;
        if (emailType == CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_WELCOME) {
            invitationToken = getToken(usr.Id, CustomerSettingsHelper.expireDateInvitation());
            con.Invitation_Token_Url__c = CustomerSettingsHelper.urlInvitation() + invitationToken;
            Contract energyContract = getLatestEnergyContract(con);
            Id emailTemplate = notNullOr(
                CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_WELCOME),
                CustomerSettingsHelper.welcomeEmailTemplate()
            );
            mail = createEmail(con, energyContract.Id, emailTemplate, servicesEmailId);
            
        } else if (emailType == CustomerVerifyTokenService.TOKEN_TYPE_INVITATION || emailType == CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_SERVICE) {
            invitationToken = getToken(usr.Id, CustomerSettingsHelper.expireDateInvitation());
            
            Id emailTemplate;
            if(emailType.contains('service')) {
                con.Invitation_Token_Url__c = CustomerSettingsHelper.urlInvitationService() + invitationToken + '&email=' + EncodingUtil.urlEncode(EncodingUtil.urlEncode(con.Email, 'UTF-8'), 'UTF-8');
                con.ServicePortal__c = true;
                emailTemplate = notNullOr(
                    CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_SERVICE),
                    CustomerSettingsHelper.invitationServiceEmailTemplate()
                );
            } else {
                con.Invitation_Token_Url__c = CustomerSettingsHelper.urlInvitation() + invitationToken;
                emailTemplate = notNullOr(
                    CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION),
                    CustomerSettingsHelper.invitationEmailTemplate()
                );
            }
            System.debug(emailTemplate);
            System.debug(emailType);
            mail = createEmail(con, null, emailTemplate, sonnenEmailId);
            
        } else if (emailType == CustomerVerifyTokenService.TOKEN_TYPE_RESET_PW || emailType == CustomerVerifyTokenService.TOKEN_TYPE_RESET_PW_SERVICE) {
            resetPwToken = getToken(usr.Id, CustomerSettingsHelper.expireDateResetPw());
            
            Id emailTemplate;
            if(emailType.contains('service')) {
                con.Reset_Password_Token_Url__c = CustomerSettingsHelper.urlResetPwService() + resetPwToken;
                emailTemplate = notNullOr(
                    CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_RESET_PW_SERVICE),
                    CustomerSettingsHelper.resetPwServiceEmailTemplate()
                );
            } else {
                con.Reset_Password_Token_Url__c = CustomerSettingsHelper.urlResetPw() + resetPwToken;
                emailTemplate = notNullOr(
                    CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_RESET_PW),
                    CustomerSettingsHelper.resetPwEmailTemplate()
                );
            }
			mail = createEmail(con, null, emailTemplate, sonnenEmailId);
            
        } else if (emailType == CustomerVerifyTokenService.TOKEN_TYPE_EMAIL) {
            emailConfigToken = getToken(usr.Id, CustomerSettingsHelper.expireDateConfirmEmail());
            con.Email_Confirmation_Token_Url__c = CustomerSettingsHelper.urlConfirmEmail() + emailConfigToken;
            Id emailTemplate = notNullOr(
                CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_EMAIL),
                CustomerSettingsHelper.confirmationEmailTemplate()
            );
            mail = createEmail(con, null, emailTemplate, sonnenEmailId);
            
        } else if (emailType == CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_CHARGER) {
            invitationToken = getToken(usr.Id, CustomerSettingsHelper.expireDateInvitation());
            con.Invitation_Token_Url__c = CustomerSettingsHelper.urlInvitationCharger() + invitationToken;
            Id emailTemplate = notNullOr(
                CustomerEmailTemplateHelper.findEmailTemplate(language, country, CustomerVerifyTokenService.TOKEN_TYPE_INVITATION_CHARGER),
                CustomerSettingsHelper.invitationChargerEmailTemplate()
            );
            mail = createEmail(con, null, emailTemplate, sonnenEmailId);
        } else {
            return 'Unknown email type: ' + emailType;
        }
    
        update con;
        updateUser(usr.Id, invitationToken, resetPwToken, emailConfigToken);

        if(!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{
                    mail
            });
        }

        return '';
    }

    /**
     *
     * This has to be done in a future, since we can't update a user and contact in the same transaction
     */
    @future
    private static void updateUser(Id userId, String invitationToken, String resetPwToken, String emailConfigToken) {
        User usr = new User(
                Id = userId
        );

        if(String.isNotEmpty(invitationToken)) {
            usr.Invitation_Token__c =  invitationToken;
        }

        if(String.isNotEmpty(resetPwToken)) {
            usr.Reset_Password_Token__c =  resetPwToken;
        }

        if(String.isNotEmpty(emailConfigToken)) {
            usr.Email_Confirmation_Token__c =  emailConfigToken;
        }

        update usr;
    }

    private static List<User> findUsers(Id contactId) {
        if(Test.isRunningTest()) {
            return new List<User>{new User(Id = UserInfo.getUserId())};
        } else {
            return [SELECT Email FROM User WHERE ContactId = :contactId];
        }
    }

    private static String getToken(Id userId, DateTime expireDate) {
        CustomerToken token = new CustomerToken(
                expireDate,
                userId
        );
        return token.encodeToken();
    }

    private static Contract getLatestEnergyContract(Contact con) {
        Id accountId = [SELECT AccountId FROM Contact WHERE Id = :con.Id].AccountId;
        return [
                SELECT Id
                FROM Contract
                WHERE AccountId = :accountId
                AND RecordType.Name = :CustomerSettingsHelper.contractRecTypeName()
                ORDER BY CreatedDate DESC
                LIMIT 1
        ];
    }

    private static Messaging.SingleEmailMessage createEmail(Contact con, Id whatId, String emailTemplate, String emailAddressId) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setTargetObjectId(con.Id);
        mail.setTemplateId(emailTemplate);
        mail.setWhatId(whatId);
        mail.setOrgWideEmailAddressId(emailAddressId);

        return mail;
    }
    
    private static Id notNullOr(Id value, Id fallback) {
        return value == null ? fallback : value;
    }

}