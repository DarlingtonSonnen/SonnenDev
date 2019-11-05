@isTest
private class OpportunityTriggerHandler_Test {       

    private static List<Account> accounts;
    private static Contact contact;
    private static Lead leadToConvert;
    private static LeadStatus convertStatus;
    
    @isTest static void setupStatic() {
     
        // Get "Customer" RecordType
        Map<String,Map<String,Id>> recordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Lead','Account'});
                       
        accounts = new List<Account>();        
        
        // Add BusinessAccount with Contact
        accounts.add(new Account(
            RecordTypeId = recordTypes.get('Account').get('BusinessAccount'),
            Name         = 'Duffy Duck'
        ));
        // Add PersonAccount
        accounts.add(new Account(
            RecordTypeId = recordTypes.get('Account').get('Private'),            
            FirstName    = 'Duffy',
            LastName     = 'Duck'
        ));
        insert accounts;
        
        // Add Contact to BusinessAccount
        contact = new Contact(
            AccountId = accounts.get(0).Id,
            FirstName = 'Duffy',
            LastName  = 'Duck'
        );
        insert contact;
        
        // Create lead to convert
        leadToConvert = new Lead(
            RecordTypeId       = recordTypes.get('Lead').get('Customer'),
            Salutation         = 'Mr.',
            FirstName          = 'Duffy',
            LastName           = 'Duck',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            Street             = 'Duck 1',
            PostalCode         = '12345',
            City               = 'Duckberg',
            StateCode          = 'AL',
            CountryCode        = 'US',
            AwarenessSource__c = 'Other',
            AwarenessSourceDetails__c = 'Gnagnagna',
			Email              = 'duffy@duck.org',
			Phone              = '123456789',
			PurchasingTimeframe__c = 'Immediately',            
            HasPvPlant__c      = 'Yes',
            PowerPvPlant__c    = '10000',
            PvPlantInstallationDate__c = 'Never',
            NumberOfResidents__c = 2
        );
        insert leadToConvert; 
        
        convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
    }
    
    /**
     * Convert a Lead with a BusinessAccount and expect the
     * Opportunity's PrimaryContact__c to match it's first Contact ID
     * (SOBCRM-328)
     */
    @isTest static void testOpportunityPrimaryContactAtBusinessAccount() {
        
        setupStatic();
        
        Test.startTest();
        
        System.assert(accounts.size() == 2, 'Expect 2 Accounts');
        
        Database.LeadConvert leadConvert = new Database.LeadConvert();
        leadConvert.setAccountId(accounts.get(0).Id);
        leadConvert.setLeadId(leadToConvert.id);
        leadConvert.setDoNotCreateOpportunity(false);
        leadConvert.setConvertedStatus(convertStatus.MasterLabel);
        leadConvert.setOwnerId(UserInfo.getUserId());
        
        Database.LeadConvertResult leadConvertResult = Database.convertLead(leadConvert);
        System.assert(leadConvertResult.isSuccess(), 'Expect Lead to be converted successfully');
        
        System.debug('OpportunityTriggerHandler_Test - testOpportunityPrimaryContactAtBusinessAccount() - leadConvertResult: ' + leadConvertResult);
        
        // Expect the BusinessAccount's Contact to be the PrimaryAccount
        Opportunity opportunity = [SELECT Id, PrimaryContact__c FROM Opportunity WHERE Id = :leadConvertResult.getOpportunityId()];
        System.assertEquals(contact.Id, opportunity.PrimaryContact__c, 'Expect opportunity.PrimaryContact__c to match contact.Id');        
                        
        Test.stopTest();
    }
    
    /**
     * Convert a Lead with a PersonAccount and expect the
     * Opportunity's PrimaryContact__c to match it's PersonContactId
     * (SOBCRM-328)
     */    
    @isTest static void testOpportunityPrimaryContactAtPersonAccount() {
        
        setupStatic();
        
        Test.startTest();
        
        System.assert(accounts.size() == 2, 'Expect 2 Accounts');
        
        Database.LeadConvert leadConvert = new Database.LeadConvert();
        leadConvert.setAccountId(accounts.get(1).Id);
        leadConvert.setLeadId(leadToConvert.id);
        leadConvert.setDoNotCreateOpportunity(false);
        leadConvert.setConvertedStatus(convertStatus.MasterLabel);
        leadConvert.setOwnerId(UserInfo.getUserId());
        
        Database.LeadConvertResult leadConvertResult = Database.convertLead(leadConvert);
        System.assert(leadConvertResult.isSuccess(), 'Expect Lead to be converted successfully');
        
        System.debug('OpportunityTriggerHandler_Test - testOpportunityPrimaryContactAtPersonAccount() - leadConvertResult: ' + leadConvertResult);
        
        Account personAccount = [SELECT PersonContactId FROM Account WHERE Id = :accounts.get(1).Id];
        
        // Expect the BusinessAccount's Contact to be the PrimaryAccount
        Opportunity opportunity = [SELECT Id, PrimaryContact__c FROM Opportunity WHERE Id = :leadConvertResult.getOpportunityId()];
        System.assertEquals(personAccount.PersonContactId, opportunity.PrimaryContact__c, 'Expect opportunity.PrimaryContact__c to match contact.Id');        
                        
        Test.stopTest();
    }    
}