/**
 * Created by m.muchow on 11.01.2019.
 * Initial - 11.01.2019 - M.Muchow - Test Class for LandingPageDoubleOptInController
 */

@IsTest
private class LandingPageDoubleOptInControllerTest
{
    @TestSetup
    static void testSetup() {

        Lead lead = new Lead(LastName = 'Test');
        insert lead;
    }
    
    @IsTest
    static void LandingPageDoubleOptInControllerTest() {
        Id leadId = [SELECT Id FROM Lead].Id;
        PageReference pageRef = Page.LandingPageDoubleOptIn;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', leadId);
        ApexPages.currentPage().getParameters().put('site', 'son');
        ApexPages.currentPage().getParameters().put('lang', 'de');
        LandingPageDoubleOptInController controller = new LandingPageDoubleOptInController();
        controller.checkDoubleOptIn();
        Test.stopTest();

        Lead leadTest = [SELECT Id, DoubleOptIn__c FROM Lead WHERE Id =: leadId];
        System.assertEquals(true,leadTest.DoubleOptIn__c);
    }
}