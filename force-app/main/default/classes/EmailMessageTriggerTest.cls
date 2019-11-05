/**
 * EmailMessage Trigger Tests
 *
 * Changelog
 * ---------
 * v1.0.0   ?           Leonel Meirinho          Initial version
 *
 * @see EmailMessageTriggerHandler
 */
@isTest
public class EmailMessageTriggerTest {

    @TestSetup
    static void testSetup() {
        //Insert test case record
        Case c = new Case();
        c.subject = 'Test';
        c.Status = 'New';
        c.Country__c = '';
        insert c;
        
        /**
         * Test Setup for checkCase() method
		 */
        CaseStatus openStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = FALSE LIMIT 1];

        Case newCase = new Case(Subject = 'Test check Case', Description = 'Test check Case', Status = openStatus.ApiName, Priority = 'Normal');
        insert newCase;

        Task newActivity = new Task(Subject = 'Test check Case');
        insert newActivity;
    }

    @isTest
    static void testCase() {
        Id caseId = [Select Id From Case where Subject = 'Test' Limit 1].Id;
        Test.startTest();
        //Insert Emailmessage for case
        EmailMessage email = new EmailMessage();
        email.FromAddress = 'test@abc.org';
        email.Incoming = True;
        email.ToAddress = 'community@sonnen.it';
        email.Subject = 'Test email';
        email.HtmlBody = 'Test email body';
        email.ParentId = caseId;
        insert email;
        Test.StopTest();
        Case_Country__mdt mdt = [SELECT Label, Country_ISOCode__c FROM Case_Country__mdt WHERE Label='community@sonnen.it'];
        system.debug('mdt:: ' + mdt);
        List<Case> caseList = [SELECT Id, Origin, Country__c From Case Where Subject = 'Test' LIMIt 1];
        System.debug('case country:: ' + caseList[0].Country__c);
        //Assert if case Country__c field update with country ISO code from custom metadata with same label as toAddress email
        system.assertEquals('IT',CaseList[0].Country__c);
    }
    
    /**
     * Test for checkcase() method of EmailMessageTriggerHandler()
     * 
     */
	@IsTest
    static void attachToCase() {
        Id caseId = [SELECT Id FROM Case WHERE Subject = 'Test check Case' LIMIT 1].Id;
        Id activityId = [SELECT Id FROM Task LIMIT 1].Id;

        Test.startTest();
        EmailMessage eMassage = new EmailMessage(FromAddress = 'test@testmail.asd', Incoming = true, ToAddress = 'test@testmail.incas', Subject = 'Test check Case', HtmlBody = 'Test check Case', ParentId = caseId, ActivityId = activityId);
        insert eMassage;
        Test.stopTest();

        List<Case> caseList = [SELECT Id, IsClosed, Description, Subject FROM Case];
        List<case> checkCaseList = new List<Case>();
        
        for (Case filterCase : caseList) {
            if ((String.isNotBlank(filterCase.Description) && filterCase.Description.contains('Test check Case')) ||filterCase.Subject.contains('Test check Case')) {
                checkCaseList.add(filterCase);
            }
        }
        
        System.assertEquals(1, checkCaseList.size());
        System.assertEquals(false, checkCaseList[0].IsClosed);
    }

    @IsTest
    static void createNewCase() {
        CaseStatus closedStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = TRUE AND ApiName != 'Closed - Waiting for Customer Reply' LIMIT 1];
        Case updateCase = [SELECT Id, Status FROM Case WHERE Subject = 'Test check Case' LIMIT 1];
        Id activityId = [SELECT Id FROM Task LIMIT 1].Id;

        updateCase.Status = closedStatus.ApiName;
        update updateCase;

        Test.startTest();
        EmailMessage eMassage = new EmailMessage(FromAddress = 'test@testmail.asd', Incoming = true, ToAddress = 'test@testmail.incas', Subject = 'Test check Case', HtmlBody = 'Test check Case', ParentId = updateCase.Id, ActivityId = activityId);
        insert eMassage;
        Test.stopTest();

        List<Case> caseList = [SELECT Id, IsClosed, Description, Subject FROM Case ORDER BY CreatedDate ASC];
        List<case> checkCaseList = new List<Case>();
        
        for (Case filterCase : caseList) {
            if ((String.isNotBlank(filterCase.Description) && filterCase.Description.contains('Test check Case')) ||filterCase.Subject.contains('Test check Case')) {
                checkCaseList.add(filterCase);
            }
        }

        System.assertEquals(2, checkCaseList.size());
        System.assertEquals(true, checkCaseList[0].IsClosed);
        System.assertEquals(false, checkCaseList[1].IsClosed);
    }

}