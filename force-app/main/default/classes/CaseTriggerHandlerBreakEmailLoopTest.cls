/**
 * Created by m.muchow on 26.08.2019.
 */

@IsTest
private class CaseTriggerHandlerBreakEmailLoopTest {
    @TestSetup
    static void testSetup() {
        List<Case> insertCaseList = new List<Case>();

        CaseStatus openStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = FALSE LIMIT 1];

        Case breakCase = new Case(Subject = 'Test Case Break', Description = 'Test', Status = openStatus.ApiName, Priority = 'Normal', Origin = 'Email', SuppliedEmail = 'testSuppliedEmail@test.test');
        insertCaseList.add(breakCase);

        Case notBreakCase = new Case(Subject = 'Test Case Not Break', Description = 'Test', Status = openStatus.ApiName, Priority = 'Normal', Origin = 'Email', SuppliedEmail = 'testSuppliedEmail@test.test', CreatedDate = System.today().addDays(-10));
        insertCaseList.add(notBreakCase);

        insert insertCaseList;
    }

    @IsTest
    static void breakLoop() {
        Test.startTest();
        CaseStatus openStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = FALSE LIMIT 1];
        Case newBreakCase = new Case(Subject = 'Test Case Break', Description = 'Test', Status = openStatus.ApiName, Priority = 'Normal', Origin = 'Email', SuppliedEmail = 'testSuppliedEmail@test.test');
        insert newBreakCase;
        Test.stopTest();

        List<Case> caseList = [SELECT Id, BreakLoop__c FROM Case WHERE Subject = 'Test Case Break' ORDER BY CreatedDate ASC];

        System.debug(caseList);

        System.assertEquals(2, caseList.size());
        System.assertEquals(false, caseList[0].BreakLoop__c);
        System.assertEquals(true, caseList[1].BreakLoop__c);
    }

    @IsTest
    static void doNotBreakLoopOlder5Minutes() {
        Test.startTest();
        CaseStatus openStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = FALSE LIMIT 1];
        Case newBreakCase = new Case(Subject = 'Test Case Not Break', Description = 'Test', Status = openStatus.ApiName, Priority = 'Normal', Origin = 'Email', SuppliedEmail = 'testSuppliedEmail@test.test');
        insert newBreakCase;
        Test.stopTest();

        List<Case> caseList = [SELECT Id, BreakLoop__c FROM Case WHERE Subject = 'Test Case Not Break' ORDER BY CreatedDate ASC];

        System.debug(caseList);

        System.assertEquals(2, caseList.size());
        System.assertEquals(false, caseList[0].BreakLoop__c);
        System.assertEquals(false, caseList[1].BreakLoop__c);
    }

    @IsTest
    static void doNotBreakDifferentSubject() {
        Test.startTest();
        CaseStatus openStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = FALSE LIMIT 1];
        Case newBreakCase = new Case(Subject = 'Test Case Not Break New', Description = 'Test', Status = openStatus.ApiName, Priority = 'Normal', Origin = 'Email', SuppliedEmail = 'testSuppliedEmail@test.test');
        insert newBreakCase;
        Test.stopTest();

        List<Case> caseList = [SELECT Id, BreakLoop__c FROM Case WHERE Subject != 'Test Case Break' ORDER BY CreatedDate ASC];

        System.debug(caseList);

        System.assertEquals(2, caseList.size());
        System.assertEquals(false, caseList[0].BreakLoop__c);
        System.assertEquals(false, caseList[1].BreakLoop__c);
    }

    @IsTest
    static void doNotBreakLoopDifferentDescription() {
        Test.startTest();
        CaseStatus openStatus = [SELECT ApiName FROM CaseStatus WHERE IsClosed = FALSE LIMIT 1];
        Case newBreakCase = new Case(Subject = 'Test Case Not Break', Description = 'Test Do Not Break', Status = openStatus.ApiName, Priority = 'Normal', Origin = 'Email', SuppliedEmail = 'testSuppliedEmail@test.test');
        insert newBreakCase;
        Test.stopTest();

        List<Case> caseList = [SELECT Id, BreakLoop__c FROM Case WHERE Subject = 'Test Case Not Break' ORDER BY CreatedDate ASC];

        System.debug(caseList);

        System.assertEquals(2, caseList.size());
        System.assertEquals(false, caseList[0].BreakLoop__c);
        System.assertEquals(false, caseList[1].BreakLoop__c);
    }
}