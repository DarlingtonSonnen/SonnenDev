global without sharing class CustomerCommunityControlsCtr {

    @AuraEnabled
    global static User getCommunityUser(Id recordId) {
        Id contactId = getContactId(recordId);

        List<User> users = [SELECT Id, Email, FirstName, LastName, Username, LastLoginDate, Customer_Portal_Admin__c FROM User WHERE ContactId = :contactId];

        if(users.isEmpty()) {
            return null;
        } else {
            return users.get(0);
        }
    }

    @AuraEnabled
    global static User getCurrentUser() {
        return [SELECT Customer_Portal_Admin__c FROM User WHERE Id = :UserInfo.getUserId()];
    }

    @AuraEnabled
    global static void sendEmail(Id recordId, String emailType) {
        Id contactId = getContactId(recordId);
        String result = CustmerEmailService.sendEmail(contactId, emailType);
        if(String.isNotEmpty(result)) {
            throw new CustomerCommunityControlsException(result);
        }
    }

    @AuraEnabled
    global static Result createCommunityUserService(Id recordId, Boolean serviceUser) {
        Result res = new Result();
        try {
            res.user = createCommunityUser(recordId, serviceUser);
        } catch (Exception e) {
        	res.error = e.getMessage();    
        }
        
        return res;
    }

    @AuraEnabled
    global static String getAdminLoginUrl() {
        return CustomerSettingsHelper.adminLoginUrl();
    }

    @AuraEnabled
    global static String getAdminLoginServiceUrl() {
        return CustomerSettingsHelper.adminLoginServiceUrl();
    }

    @AuraEnabled
    global static Result setUserPassword(Id userId, String password) {
        Result res = new Result();
        
        try {
            // This is mainly for security, so you can't change the PW of every user with this method
            List<User> users = [SELECT UserType FROM User WHERE Id = :userId AND Profile.Name = :CustomerSettingsHelper.portalProfileName()];
            if(users.isEmpty()) {
                res.error =  'No portal user found for this id';
            } else if(users.get(0).UserType != 'CspLitePortal') {
                res.error =  'User type: ' + users.get(0).UserType + ' is not supported';
            } else if(String.isBlank(password) || password.length() < 5) {
                res.error = 'Password must at least be 5 characters long';
            } else {
            	changePw(userId, password);
            }
        } catch (Exception e) {
        	res.error = e.getMessage();    
        }
        
        return res;
    }
    
    public static User createCommunityUser(Id recordId, Boolean serviceUser) {
        Id contactId = getContactId(recordId);
    
        Contact con = [
            SELECT FirstName,
            LastName,
            Email
            FROM Contact
            WHERE Id = :contactId
        ];
        
        if(serviceUser) {
            con.ServicePortal__c = true;
            update con;
        }
        
        User currentUser = [
            SELECT TimeZoneSidKey,
            LocaleSidKey,
            EmailEncodingKey,
            LanguageLocaleKey,
            ProfileId
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        
        Id profileId = [
            SELECT Id
            FROM Profile
            WHERE Name = :CustomerSettingsHelper.portalProfileName()
            LIMIT 1
        ].Id;
        
        String emailFirstPart = con.Email.substringBefore('@');
        String alias = emailFirstPart.left(8);
        
        User usr = new User(
            Username = con.Email + '.sonnen',
            FirstName = con.FirstName,
            LastName = con.LastName,
            Email = con.Email,
            Alias = alias,
            TimeZoneSidKey = currentUser.TimeZoneSidKey,
            LocaleSidKey = currentUser.LocaleSidKey,
            EmailEncodingKey = currentUser.EmailEncodingKey,
            ProfileId = profileId,
            LanguageLocaleKey = currentUser.LanguageLocaleKey,
            ContactId = contactId
        );
        insert usr;
        return usr;
    }
    
    // Had to move this into a future method because of session id issues when called from LEX
    @future
    private static void changePw(String userId, String password) {
        System.setPassword(userId, password); 
    }

    private static Id getContactId(Id recordId) {
        return [SELECT Id FROM Contact WHERE AccountId = :recordId OR Id = :recordId].Id;
    }
    
    
    global class Result {
        
        @AuraEnabled
        public String error {get;set;}
        
        @AuraEnabled
        public User user {get;set;}
        
    }

    public class CustomerCommunityControlsException extends Exception{}

}