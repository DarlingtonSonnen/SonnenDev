@isTest
private class DirectSalesToOpportunityController_Test {

    static Map<String,String> lmRecordTypesOpportunity;
    static List<Opportunity> lOpportunities;
    static User oUser;
    
    @isTest 
    static void setup() {
        
        // Create a user who is Area Manager
        Id idProfile = [SELECT Id FROM Profile WHERE Name = :DirectSalesToOpportunityController.areaManagerProfileName].Id;

        //List<User> lUsers = [SELECT Id, Name FROM User WHERE ProfileId = :idProfile];
        //System.debug('setup() - Usercount: ' + lUsers.size());        
        
        oUser = new User(
          Alias = 'bogus',
          Email = 'test@foobar.com',
          EmailEncodingKey = 'UTF-8',
          LastName = 'Bogusman',
          LanguageLocaleKey = 'en_US',
          LocaleSidKey = 'en_US',
          TimeZoneSidKey='America/Los_Angeles',
          ProfileId = idProfile,
          // Try to be unique and creative over all Salesforce Orgs in the whole universe  
          UserName='skandal@der-hasenpapst-tanzt-samba-im-wurstsalat.ole.ole'
        );        
        insert oUser;  
        
        //lUsers = [SELECT Id, Name FROM User WHERE ProfileId = :idProfile];
        //System.debug('setup() - Usercount: ' + lUsers.size());        
        
        lmRecordTypesOpportunity = SonnenbatterieConstants.getRecordTypeIdsByObjectName('Opportunity');

        // Create Opportunities
        lOpportunities = new List<Opportunity>();
        
        lOpportunities.add(new Opportunity(
            Name = 'Test1',
        	RecordTypeId = lmRecordTypesOpportunity.get('DirectSales'),
            StageName = 'Open',
            CloseDate = System.today(),
            OwnerId = oUser.Id
        ));
        lOpportunities.add(new Opportunity(
            Name = 'Test2',
        	RecordTypeId = lmRecordTypesOpportunity.get('Order'), // = Partner Sales
            StageName = 'Open',
            CloseDate = System.today()
        ));
        lOpportunities.add(new Opportunity(
            Name = 'Test3',
        	RecordTypeId = lmRecordTypesOpportunity.get('Configurator'),
            StageName = 'Open',
            CloseDate = System.today()
        ));
        insert lOpportunities;
    }
    
    @isTest
    static void testController() {
        
		setup();
        
        Test.startTest();
        
        ApexPages.StandardSetController standardController = new ApexPages.StandardSetController(new List<Opportunity>());
        DirectSalesToOpportunityController controller = new DirectSalesToOpportunityController(standardController);
                
		System.assertEquals(true, controller.hasStopError, 'Expected stopError');
        
        standardController = new ApexPages.StandardSetController(lOpportunities);
        standardController.setSelected(lOpportunities);
        controller = new DirectSalesToOpportunityController(standardController);        

		System.assertEquals(false, controller.hasStopError, 'Expected no stopError');
        System.assertEquals(2, controller.selectedOpportunities.size(), 'Expect two selected Opportunities as the third one is of type "Configurator"');
        
        // For code coverage
        controller.getTeamSelections();
        
        // Select team "Ambassador" and set user ID
        controller.teamSelect = 'Ambassador';
        controller.ambassdorSelect = oUser.Id;
        
        // Save first Opportunity's modified date to check later
        Datetime firstOpportunityModifiyDate = [SELECT LastModifiedDate FROM Opportunity WHERE Id = :lOpportunities.get(0).Id].LastModifiedDate;
        
        controller.save();        
        
        Test.stopTest();
        
        // Assertions
        Map<Id,Opportunity> opportunitiesToCheck = new Map<Id,Opportunity>([SELECT Id, OwnerId, LastModifiedDate, RecordTypeId FROM Opportunity WHERE Id IN :lOpportunities]);
        
        // #1 Opportunity: Not modified
        Opportunity opportunityToCheck = opportunitiesToCheck.get(lOpportunities.get(0).Id);
        System.assertEquals(firstOpportunityModifiyDate, opportunityToCheck.LastModifiedDate, 'Expect no modification on first Opportunity');
        
        // #2 Opportunity: Changed RecordType and Owner
		opportunityToCheck = opportunitiesToCheck.get(lOpportunities.get(1).Id);
        System.assertEquals(lmRecordTypesOpportunity.get('DirectSales'), opportunityToCheck.RecordTypeId, 'Expect changed RecordType on second Opportunity');
        System.assertEquals(oUser.Id, opportunityToCheck.OwnerId, 'Expect changed RecordType on second Opportunity');
        
		// #3 Opportunity: Left untouched because of wrong RecordType "Configurator"        
		opportunityToCheck = opportunitiesToCheck.get(lOpportunities.get(2).Id);
        System.assertEquals(UserInfo.getUserId(), opportunityToCheck.OwnerId, 'Expect non changed Owner on third Opportunity');        
        System.assertEquals(lOpportunities.get(2).RecordTypeId, opportunityToCheck.RecordTypeId, 'Expect non changed Owner on third Opportunity');                
    }
}