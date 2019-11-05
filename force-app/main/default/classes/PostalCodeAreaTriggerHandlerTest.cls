@isTest
public class PostalCodeAreaTriggerHandlerTest {
    
	// Dummy CRON expression: midnight on March 15.
    // Because this is a test, job executes
    // immediately after Test.stopTest().
    public static String CRON_EXP = '0 0 0 15 3 ? 2020';

    @testSetup
    private static void setupTestData() {
        
        RecordType rt = [SELECT Name, Id FROM RecordType WHERE sObjectType='Account' AND DeveloperName='SBC' AND isActive=true];

        Account acc1 = new Account(Name='GCME #1', RecordTypeId=rt.Id, Status__c='active');
        Account acc2 = new Account(Name='GCME #2', RecordTypeId=rt.Id, Status__c='active');
        insert new List<Account>{acc1, acc2};
        
        List<PostalCodeArea__c> pcas = new List<PostalCodeArea__c>();
        pcas.add(new PostalCodeArea__c(Name='1000', Country__c='DE', AssignedPartner__c=acc1.Id));
        pcas.add(new PostalCodeArea__c(Name='1001', Country__c='DE', AssignedPartner__c=acc2.Id));
        insert pcas;
    }
    
    @isTest
    static void testAssigningRecommendedPartnerForLead() {
        
        Lead l = new Lead(LastName='Doe', Email='john@doe-interaktiven.de', PostalCode='1000', CountryCode='DE');
        insert l;
        
        Test.startTest();
        	LeadAssignPartnerAndManagerBatch lb = new LeadAssignPartnerAndManagerBatch();
        	Id batchId = Database.executeBatch(lb);
        Test.stopTest();
        
        l = [SELECT Id, PostalCode, 
             		AssignSBC__c, AssignPartnerDebug__c, WasHandledByPartnerAssignBatch__c,
             		AreaManager__c, AssignAreaManagerDebug__c, WasHandledByAreaManagerAssignBatch__c
             FROM Lead];
        system.assert(l.AssignSBC__c != null);
        system.assert(l.AreaManager__c != null);
    }
    
    @isTest
    static void testChangingAssignedPartnerForPCA() {
        
        // PostalCodeArea currently assigned to a partner who's not really performing well
        PostalCodeArea__c pca = [SELECT Id, AssignedPartner__c, AssignedPartner__r.RecordTypeId FROM PostalCodeArea__c WHERE Name='1000'];

        // Insert Lead with pre-assigned old partner (this functionality is tested in the testAssigningRecommendedPartnerForLead)
        Lead l = new Lead(LastName='Doe', Email='john@doe-interaktiven.de', PostalCode='1000', CountryCode='DE', AssignSBC__c=pca.AssignedPartner__c);
        insert l;
        
        // New Partner entered the market, from now on this Partner is responsible for PostalCode 1000
        Account accNew = new Account(Name='SuperPartner1000', RecordTypeId=pca.AssignedPartner__r.RecordTypeId, Status__c='active');
        insert accNew;
        
        // Updating PostalCodeArea should expectedly reset AssignSBC/AreaManager/WasHandledByAssignBatch on all Leads with th
        pca.AssignedPartner__c = accNew.id;
        update pca;
        
        Test.startTest();
        	LeadAssignPartnerAndManagerBatch lb = new LeadAssignPartnerAndManagerBatch();
        	Id batchId = Database.executeBatch(lb);
        Test.stopTest();
        
        l = [SELECT Id, PostalCode, 
             		AssignSBC__c, AssignPartnerDebug__c, WasHandledByPartnerAssignBatch__c,
             		AreaManager__c, AssignAreaManagerDebug__c, WasHandledByAreaManagerAssignBatch__c
             FROM Lead];
        system.assert(l.AssignSBC__c != null);
        system.assertEquals(pca.AssignedPartner__c, l.AssignSBC__c);
    }
}