@isTest
private class LeadTriggerHandler_Test {

    private static List<Campaign> campaigns;

	@isTest static void setupStatic() {
        
        // Create some Campaigns
        campaigns = new List<Campaign>();        
        campaigns.add(new Campaign(
            Name = 'Campaign #1'            
        ));
        campaigns.add(new Campaign(
            Name = 'Campaign #2'
        ));
        insert campaigns;        
    }

    /**
     * Tests LeadTriggerHandler.resetHandledByAssignBatch()
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-755
     * @see LeadTriggerHandler.resetHandledByAssignBatch()
     * @since 2017-01-04
     */
    @isTest static void testLeadResetHandledByAssignBatch() {

        //----------------------------
        // Area Manager
        //----------------------------
        // Create an Area Manager which is a normal User
        Id idProfile = AssignDelegate.getAreaManagerProfileId();

        // This one will be related to a PostalCodeArea
        User oAreaManager = new User(
            Alias = 'AM1',
            Email = 'test@foobar.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Bogusman',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey='America/Los_Angeles',
            ProfileId = idProfile,
            // Try to be unique and creative over all Salesforce Orgs in the whole universe
            UserName='bogusman@tri-tra-trullala-der-sonnen-area-manager-ist-wieder.da'
        );
        insert oAreaManager;

        //----------------------------
        // Partner Account
        //----------------------------
        // Add some Accounts
        Map<String,Id> recordTypesAccount = SonnenbatterieConstants.getRecordTypeIdsByObjectName('Account');

        Account oPartnerAccount = new Account(
            Name = 'Partner',
            RecordTypeId = recordTypesAccount.get('SBC'),
            Status__c = 'active'
        );
        insert oPartnerAccount;

        //----------------------------
        // Lead
        //----------------------------
        Lead oLead = new Lead(
            FirstName          = 'Duffy',
            LastName           = 'Duck',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Street             = 'Teststr. 2',
            PostalCode         = '35578',
            City               = 'Wetzlar',
            CountryCode        = 'de',
            AssignSBC__c       = oPartnerAccount.Id,
            AreaManager__c     = oAreaManager.Id,
            WasHandledByAreaManagerAssignBatch__c = TRUE,
            WasHandledByPartnerAssignBatch__c     = TRUE
        );
        insert oLead;

        Test.startTest();
        oLead.Street = 'Teststr. 1';
        update oLead;

        Test.stopTest();

        oLead = [
            SELECT AssignSBC__c, AreaManager__c, WasHandledByAreaManagerAssignBatch__c, WasHandledByPartnerAssignBatch__c
            FROM Lead
            WHERE Id = :oLead.Id
        ];

        System.assertEquals(FALSE, oLead.WasHandledByPartnerAssignBatch__c);
        System.assertEquals(FALSE, oLead.WasHandledByAreaManagerAssignBatch__c);
        System.assertEquals(NULL, oLead.AssignSBC__c);
        System.assertEquals(NULL, oLead.AreaManager__c);
    }

    @isTest static void testCampaignInsert() {
        
        setupStatic();

        System.assert(campaigns.size() == 2, 'Expected at least one Campaign');
                
        Test.startTest();
                
        // Create some Leads
        List<Lead> leads = new List<Lead>();
        leads.add(new Lead(
            FirstName          = 'Duffy',
            LastName           = 'Duck',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            ApiCampaign__c     = ':-P'
        ));
        leads.add(new Lead(
            FirstName          = 'Donald',
            LastName           = 'Duck',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            ApiSecondCampaign__c = '0067E000002xGoL' // Test wrong ID (here Opportunity)
        ));
        leads.add(new Lead(
            FirstName          = 'Mickey',
            LastName           = 'Mouse',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            ApiCampaign__c     = campaigns.get(0).Id,  // #1 CampaignMember object
            ApiSecondCampaign__c = campaigns.get(0).Id // Check on duplicate Membership
        ));
        leads.add(new Lead(
            FirstName          = 'Daisy',
            LastName           = 'Duck',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            ApiCampaign__c     = campaigns.get(0).Id,  // #2 CampaignMember object
            ApiSecondCampaign__c = campaigns.get(1).Id // #3 CampaignMember object
        ));
        insert leads;
         
        List<CampaignMember> campaignMembers = [SELECT FirstName, LeadId, CampaignId FROM CampaignMember];        
        System.assert(campaignMembers.size() == 3, 'Expected exactly 3 CampaignMembers');
        
        Test.stopTest();
    } 
    
    @isTest static void testLanguageMapping() {
        
        List<CountryToLanguageMapping__c> countryToLanguageMappings = new List<CountryToLanguageMapping__c>();
        
        countryToLanguageMappings.add(new CountryToLanguageMapping__c(
            Name = 'default',
            LanguageISOCode__c = 'en'
        ));
        countryToLanguageMappings.add(new CountryToLanguageMapping__c(
            Name = 'CH',
            LanguageISOCode__c = 'de'
        ));
        
        insert countryToLanguageMappings;
        
        Test.startTest();
        
		List<Lead> leads = new List<Lead>();        
        
        leads.add(new Lead(
            FirstName          = 'Foo',
            LastName           = 'Bar1',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla'
        ));        
        leads.add(new Lead(
            FirstName          = 'Foo',
            LastName           = 'Bar2',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            TargetCountry__c   = 'CN'
        ));        
        leads.add(new Lead(
            FirstName          = 'Foo',
            LastName           = 'Bar3',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla',
            TargetCountry__c   = 'CH'
        ));        
        insert leads;
        
        Map<Id,Lead> leadMap = new Map<Id,Lead>([SELECT Id, Language__c FROM Lead]);
        System.assertEquals('en', leadMap.get(leads.get(0).Id).Language__c, 'Expected lead\'s language to be "en" because TargetCountry__c is NOT set'); 
        System.assertEquals('en', leadMap.get(leads.get(1).Id).Language__c, 'Expected lead\'s language to be "en" because TargetCountry__c is set to CN which is not mapped'); 
        System.assertEquals('de', leadMap.get(leads.get(2).Id).Language__c, 'Expected lead\'s language to be "de" because TargetCountry__c is CH wich is mapped to "de"'); 
        
        Test.stopTest();        
    }

    /**
     * Tests LeadTriggerHandler.checkForDuplicates()
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-967
     * @see LeadTriggerHandler.checkForDuplicates()
     * @since 2017-06-06
     */    
    @isTest static void testDuplicateCheckLead() {

        Test.startTest();
        
        List<Lead> leads = new List<Lead>(); 

        insert new Lead(
            FirstName          = 'Foo',
            LastName           = 'Bar1',
            Email              = 'my@test.mail',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla'
        );  

        Lead dupLead1 = new Lead(
                            FirstName          = 'Foo',
                            LastName           = 'Bar2',
                            Email              = 'my@test.mail',
                            Type__c            = 'Other',
                            LeadSource         = 'Other',
                            ProductInterest__c = 'eco',
                            Description2__c    = 'Blabla'
                        );  

        Lead dupLead2 = new Lead(
                            FirstName          = 'Foo',
                            LastName           = 'Bar3',
                            Email              = 'my@test.mail',
                            Type__c            = 'Other',
                            LeadSource         = 'Other',
                            ProductInterest__c = 'eco',
                            Description2__c    = 'Blabla'
                        );  

        Lead dupLead3 = new Lead(
                            FirstName          = 'Foo',
                            LastName           = 'Bar4',
                            Email              = 'my@test.mail',
                            Type__c            = 'Other',
                            LeadSource         = 'Other',
                            ProductInterest__c = 'eco',
                            Description2__c    = 'Blabla'
                        );  

        List<Lead> dupLeads = new List<Lead>{dupLead2,dupLead3}; 

        insert dupLead1; 
        insert dupLeads;

        Test.stopTest();        

        System.assertEquals('Duplicate',[SELECT Status FROM Lead WHERE Id = :dupLead1.Id].Status);
        System.assertEquals('Duplicate',[SELECT Status FROM Lead WHERE Id = :dupLead2.Id].Status);
        System.assertEquals('Duplicate',[SELECT Status FROM Lead WHERE Id = :dupLead3.Id].Status);
    }
    /**
     * Tests LeadTriggerHandler.checkForDuplicates()
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-967
     * @see LeadTriggerHandler.checkForDuplicates()
     * @since 2017-06-06
     */    
    @isTest static void testDuplicateCheckContact() {

        Test.startTest();
        
        List<Lead> leads = new List<Lead>(); 

        Account account = new Account(Name = 'Testkunde');
        insert account ;

        insert new Contact( FirstName = 'Voidberg', 
                            LastName  = 'Bogusman', 
                            Email     = 'my@test.mail',
                            AccountId = account.Id);

        Lead dupLead1 = new Lead(
                            FirstName          = 'Foo',
                            LastName           = 'Bar2',
                            Email              = 'my@test.mail',
                            Type__c            = 'Other',
                            LeadSource         = 'Other',
                            ProductInterest__c = 'eco',
                            Description2__c    = 'Blabla'
                        );  

        Lead dupLead2 = new Lead(
                            FirstName          = 'Foo',
                            LastName           = 'Bar3',
                            Email              = 'my@test.mail',
                            Type__c            = 'Other',
                            LeadSource         = 'Other',
                            ProductInterest__c = 'eco',
                            Description2__c    = 'Blabla'
                        );  

        Lead dupLead3 = new Lead(
                            FirstName          = 'Foo',
                            LastName           = 'Bar4',
                            Email              = 'my@test.mail',
                            Type__c            = 'Other',
                            LeadSource         = 'Other',
                            ProductInterest__c = 'eco',
                            Description2__c    = 'Blabla'
                        );  

        List<Lead> dupLeads = new List<Lead>{dupLead2,dupLead3}; 

        insert dupLead1; 
        insert dupLeads;

        Test.stopTest();        

        System.assertEquals('Duplicate',[SELECT Status FROM Lead WHERE Id = :dupLead1.Id].Status);
        System.assertEquals('Duplicate',[SELECT Status FROM Lead WHERE Id = :dupLead2.Id].Status);
        System.assertEquals('Duplicate',[SELECT Status FROM Lead WHERE Id = :dupLead3.Id].Status);
    }

    /**
     * Tests LeadTriggerHandler.checkForDuplicates()
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-1062
     * @author Igor Savchenko
     * @since 2017-08-26
     */    
    @isTest static void testSetAccountOnReferral() {
        Test.startTest();
        Lead lead = new Lead(
            FirstName          = 'Foo',
            LastName           = 'Bar2',
            Email              = 'my@test.mail',
            Type__c            = 'Other',
            LeadSource         = 'Other',
            ProductInterest__c = 'eco',
            Description2__c    = 'Blabla'
        );  
        insert lead;

        Referral__c referral = new Referral__c(
            ReferredLead__c = lead.Id,
            ReferringLead__c = lead.Id
        );
        insert referral;

        Database.LeadConvert lc = new database.LeadConvert();
        lc.setLeadId(lead.id);
        lc.setConvertedStatus('Qualified');
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        
        Test.stopTest();
    }

}