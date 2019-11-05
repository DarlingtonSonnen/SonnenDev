/**
 * Provides webservices to onboard users into the sonnen community.
 *
 */
@RestResource(urlMapping='/customeronboarding/*')
global class CustomerOnboardingService {
    
    public static final String ONBOARDING_TYPE_VERSION_1 = 'v_1';
    public static final String ONBOARDING_TYPE_VERSION_2 = 'v_2';
    
    public static final String ONBOARDING_TYPE_BATTERY = 'battery';
    public static final String ONBOARDING_TYPE_EMAIL = 'email';
    public static final String ONBOARDING_TYPE_CREATE_USER = 'create_user';
    
    @HttpPost
    global static Result onboardingEntryPoint(String first_name, String last_name, String email, String serial_number, String account_id, String contact_id) {
        RestRequest req = RestContext.request;      
        List<String> uriParts = req.requestURI.split('/');
        
        String onboardingType = uriParts.get(uriParts.size() - 1);
        
        String version = uriParts.get(uriParts.size() - 2);
        if(!version.startsWith('v_')) {
            version = ONBOARDING_TYPE_VERSION_1;
        }
		
        Result result;
        Savepoint sp = Database.setSavepoint();
        try {
            if(onboardingType == ONBOARDING_TYPE_BATTERY && version == ONBOARDING_TYPE_VERSION_1) {
                result = doBatteryOnboarding(first_name, last_name, email, serial_number, true);
            } else if(onboardingType == ONBOARDING_TYPE_BATTERY) {
                result = doBatteryOnboarding(first_name, last_name, email, serial_number, false);
            } else if(onboardingType == ONBOARDING_TYPE_CREATE_USER) {
                result = createUserIfNoneExistsSync(account_id, contact_id);
            } else if(onboardingType == ONBOARDING_TYPE_EMAIL) {
                result = doEmailOnboarding(email);
            } else {
                throw new OnboardingServiceException('Unsupported onboarding type: ' + onboardingType);
            }
        } catch (OnboardingServiceException e) {
            Database.rollback(sp);
            result = new Result();
            result.errors = e.getMessage();
        }

        return result;
    }
    
    private static Result doBatteryOnboarding(String firstName, String lastName, String email, String serialNumber, Boolean createUser) {
        Asset ast = findAsset(serialNumber);
          
        Contact con = findContact(firstName, lastName, email, ast);
        
        if(createUser) {
            createUserIfNoneExists(con.Id);
        }  
        
        Result result = new Result();
        
        if(ast == null) {
            StockItem__c item = findStockItem(serialNumber);
            if(item != null) {
                item.Account__c = con.AccountId;
                update item;
                result.stock_item_id = item.Id;
            } else {
                result.errors = Label.Customer_No_Asset_Error_Message + ' ' + serialNumber;
            }
        } else if(ast.AccountId != con.AccountId || ast.ContactId != con.Id) {
            ast.AccountId = con.AccountId;
            ast.ContactId = con.Id;
            upsert ast;
        }
        
        result.account_id = con.AccountId;
        result.contact_id = con.Id;
        return result;
    }
    
    private static StockItem__c findStockItem(String serialNumber) {
        List<StockItem__c> items = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = :serialNumber];
        
        return items.isEmpty() ? null : items.get(0);
    }
    
    private static Result doEmailOnboarding(String email) {
        Result result = new Result();
        if(String.isBlank(email)) {
            result.errors = 'Onboarding failed: email must not be empty';
            return result;
        }
        
        List<Contact> contacts = [SELECT Email, AccountId FROM Contact WHERE Email = :email.toLowerCase()];
        
        String username = email.toLowerCase() + '.sonnen';
        List<User> users = [SELECT Id FROM User WHERE Username = :username];
        
        if(contacts.isEmpty()) {
            result.errors = 'Onboarding failed: no contact found for this email';
        } else if(contacts.size() > 1 && users.isEmpty()) {
            result.errors = 'Onboarding failed: multiple contacts found for this email';
        } else {
            result.contact_id = contacts.get(0).Id;
            result.account_id = contacts.get(0).AccountId;
        }        
        
        return result;
    }
    
    private static boolean assetBelongsToPlaceholderAccount(Asset ast) {
		return CustomerSettingsHelper.batteryPlaceholderAccountId() == ast.AccountId;        
    }
    
    @future
    private static void createUserIfNoneExists(Id conId) {        
        createUserIfNoneExistsSync(null, conId);
    }
    
    private static Result createUserIfNoneExistsSync(String accId, String conId) {        
        if(String.isEmpty(accId) && String.isEmpty(conId)) {
            throw new OnboardingServiceException('Failed to create user, account id must not be empty');
        }
           
        Contact con = [SELECT AccountId 
                        FROM Contact 
                       WHERE Id = :conId 
                          OR (AccountId = :accId
                              AND (Account.RecordTypeId = :CustomerSettingsHelper.personRecType()
                                   OR Account.RecordTypeId = :CustomerSettingsHelper.privateAmbassadorRecType()))];
        
        List<User> users = [SELECT LastLoginDate FROM User WHERE ContactId = :con.Id];   
        
        Result res = new Result();
        res.contact_id = con.Id;
        res.account_id = con.AccountId;
        if(users.isEmpty()) {
            res.user_id = CustomerCommunityControlsCtr.createCommunityUser(con.Id, false).Id;
            res.user_existed = false;
        } else {
            res.user_id = users.get(0).Id;
            res.user_last_login_date = users.get(0).LastLoginDate;
            res.user_existed = true;
        }
        
        return res;
    }
    
    private static Contact findContact(String firstName, String lastName, String email, Asset ast) {
        if(String.isBlank(email)) {
            throw new OnboardingServiceException('Email must not be empty');
        }
        
        Id accountId = ast != null && !assetBelongsToPlaceholderAccount(ast) ? ast.AccountId : null;
        
        List<Contact> contacts;
        if(accountId != null) {
            contacts = [SELECT AccountId, Email 
                          FROM Contact 
                         WHERE (Email = :email OR Id = :ast.ContactId OR AccountId = :ast.AccountId)
                           AND AccountId = :accountId]; 
        } else {
            contacts = [SELECT AccountId, Email 
                          FROM Contact 
                         WHERE Email = :email]; 
        }      
        System.debug(accountId);
        System.debug(email);
        System.debug(contacts);
        
        if(contacts.size() > 1 && accountId == null) {
            throw new OnboardingServiceException('Multiple contacts found for email address');
        } if(contacts.size() > 1 && ast != null) {
            return new Map<Id, Contact>(contacts).get(ast.ContactId);
        } else if(contacts.size() == 1) {
            return contacts.get(0);
        } else if(accountId != null){
            return createContact(firstName, lastName, email, accountId);
        } else {
            return createPersonAccount(firstName, lastName, email);
        }
    }    
    
    private static Asset findAsset(String serialNumber) {
        if(String.isBlank(serialNumber)) {
            throw new OnboardingServiceException('Serial number must not be empty');
        }
        
        List<Asset> assets = [SELECT AccountId, Account.RecordTypeId, Account.Id, ContactId FROM Asset WHERE SerialNumber = :serialNumber];
        
        if(assets.size() > 1) {
            throw new OnboardingServiceException('Multiple assets found for serial number');
        } else if(assets.size() == 1) {
            return assets.get(0);
        } else {
            return null;
        }
    }
    
    private static Contact createPersonAccount(String firstName, String lastName, String email) {
        Account acc = new Account(
            RecordTypeId = CustomerSettingsHelper.personRecType(),
            FirstName = firstName,
            LastName = lastName,
            PersonEmail = email
        );
        insert acc;
        return [SELECT AccountId FROM Contact WHERE AccountId = :acc.Id];
    }
    
    private static Contact createContact(String firstName, String lastName, String email, String accountId) {
        Contact con = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            AccountId = accountId
        );
        insert con;
        return con;
    }
    
    global class Result {
        public String account_id;        
        public String contact_id;        
        public String stock_item_id;
        public String user_id;        
        public Boolean user_existed;  
        public DateTime user_last_login_date;
        public String errors;
    }

    public class OnboardingServiceException extends Exception {}
    
}