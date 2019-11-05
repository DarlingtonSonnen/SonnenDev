public class CustomerSettingsHelper {
    
    private final static Customer_Portal_Settings__c settings = Customer_Portal_Settings__c.getOrgDefaults();

    public static Blob getTokenKey() {
        return EncodingUtil.convertFromHex(settings.Token_Key__c);
    }

    public static DateTime expireDateInvitation() {
        return DateTime.now().addMinutes(settings.Expire_Token_Invitation__c.intValue());
    }

    public static DateTime expireDateResetPw() {
        return DateTime.now().addMinutes(settings.Expire_Token_Reset_PW__c.intValue());
    }

    public static DateTime expireDateConfirmEmail() {
        return DateTime.now().addMinutes(settings.Expire_Token_Confirm_Email__c.intValue());
    }

    public static String urlInvitation() {
        return settings.Invitation_Url__c;
    }

    public static String urlInvitationCharger() {
        return settings.Invitation_Charger_Url__c;
    }

    public static String urlInvitationService() {
        return settings.Invitation_Service_Url__c;
    }

    public static String urlConfirmEmail() {
        return settings.Email_Confirmation_Url__c;
    }

    public static String urlResetPw() {
        return settings.Reset_Passwort_Url__c;
    }

    public static String urlResetPwService() {
        return settings.Reset_Passwort_Service_Url__c;
    }

    public static String confirmationEmailTemplate() {
        return settings.Confirmation_Email_Template__c;
    }

    public static String resetPwEmailTemplate() {
        return settings.Reset_PW_Email_Template__c;
    }

    public static String resetPwServiceEmailTemplate() {
        return settings.Reset_PW_Service_Email_Template__c;
    }

    public static String invitationEmailTemplate() {
        return settings.Invitation_Email_Template__c;
    }

    public static String invitationChargerEmailTemplate() {
        return settings.Invitation_Charger_Email_Template__c;
    }

    public static String invitationServiceEmailTemplate() {
        return settings.Invitation_Service_Email_Template__c;
    }

    public static String welcomeEmailTemplate() {
        return settings.Weclome_Email_Template__c;
    }

    public static String portalProfileName() {
        return settings.Portal_Profile_Name__c;
    }

    public static String contractRecTypeName() {
        return settings.Contract_Rec_Type_Name__c;
    }

    public static String batteryPlaceholderAccountId() {
        return settings.Battery_Placeholder_Account_Id__c;
    }

    public static String personRecType() {
        return settings.Person_Rec_Type__c;
    }

    public static String privateAmbassadorRecType() {
        return settings.Private_Ambassador_Rec_Type__c;
    }

    public static String portalEmailAddressId() {
        return settings.Portal_Email_Address_Id__c;
    }

    public static String welcomeEmailAddressId() {
        return settings.Welcome_Email_Address_Id__c;
    }
    
    public static String adminLoginUrl() {		
	    return settings.Admin_Login_Url__c;		
	}
    
    public static String adminLoginServiceUrl() {		
	    return settings.Admin_Login_Service_Url__c;		
	}
    
}