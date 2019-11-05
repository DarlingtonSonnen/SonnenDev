/**
 * Created by m.muchow on 13.03.2019.
 */

@IsTest
private class noAnswerControllerTest {

    @TestSetup
    static void testSetup() {
        Id customerLeadId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        Lead customerLead = new Lead(FirstName = 'Test', LastName = 'Lead', TargetCountry__c = 'DE', Email='email@mailforspam.com', RecordTypeId = customerLeadId);
        insert customerLead;
    }

    @IsTest
    static void sendFirstNoAnswerEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];

        Test.startTest();
        String helperString = noAnswerController.getNoAnswerValue(testLead.Id);
        noAnswerController.sendEmailNoAns(testLead.Id, helperString);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Mail versandt (1)');
        System.assertEquals(true, containsDesc);
        System.assertEquals('2', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendSecondNoAnswerEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '3';
        update testLead;

        Test.startTest();
        String helperString = noAnswerController.getNoAnswerValue(testLead.Id);
        noAnswerController.sendEmailNoAns(testLead.Id, helperString);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Mail versandt (3)');
        System.assertEquals(true, containsDesc);
        System.assertEquals('4', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendThirdNoAnswerEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '5';
        update testLead;

        Test.startTest();
        String helperString = noAnswerController.getNoAnswerValue(testLead.Id);
        noAnswerController.sendEmailNoAns(testLead.Id, helperString);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Mail versandt (5)');
        System.assertEquals(true, containsDesc);
        System.assertEquals('6', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendNoAnswerPlusEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '1+q';
        update testLead;

        Test.startTest();
        String helperString = noAnswerController.getNoAnswerValue(testLead.Id);
        noAnswerController.sendEmailNoAns(testLead.Id, helperString);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Mail versandt (1)');
        System.assertEquals(true, containsDesc);
        System.assertEquals('2+q', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendQualyEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];

        Test.startTest();
        noAnswerController.sendEmailQualy(testLead.Id);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Qualy Mail versandt');
        System.assertEquals(true, containsDesc);
        System.assertEquals('1+q', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void logNoAnswerCall() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '2';
        update testLead;

        Test.startTest();
        String helperString = noAnswerController.getNoAnswerValue(testLead.Id);
        noAnswerController.sendEmailNoAns(testLead.Id, helperString);
        Test.stopTest();

        Lead testLeadResult = [SELECT EmailHelper__c, Description2__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('KA');
        System.assertEquals(true, containsDesc);
        System.assertEquals('3', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void logNoAnswerPlusCall() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '4+q';
        update testLead;

        Test.startTest();
        String helperString = noAnswerController.getNoAnswerValue(testLead.Id);
        noAnswerController.sendEmailNoAns(testLead.Id, helperString);
        Test.stopTest();

        Lead testLeadResult = [SELECT EmailHelper__c, Description2__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('KA');
        System.assertEquals(true, containsDesc);
        System.assertEquals('5+q', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendQualyBetweenEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '2';
        update testLead;

        Test.startTest();
        noAnswerController.sendEmailQualy(testLead.Id);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Qualy Mail versandt');
        System.assertEquals(true, containsDesc);
        System.assertEquals('2+q', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendQualyLastEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '6';
        update testLead;

        Test.startTest();
        noAnswerController.sendEmailQualy(testLead.Id);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Qualy Mail versandt');
        System.assertEquals(true, containsDesc);
        System.assertEquals('6+d', testLeadResult.EmailHelper__c);
    }

    @IsTest
    static void sendQualyPlusLastEmail() {
        Lead testLead = [SELECT Id, EmailHelper__c FROM Lead];
        testLead.EmailHelper__c = '6+q';
        update testLead;

        Test.startTest();
        noAnswerController.sendEmailQualy(testLead.Id);
        Test.stopTest();

        Lead testLeadResult = [SELECT Description2__c, EmailHelper__c FROM Lead];
        Boolean containsDesc = testLeadResult.Description2__c.contains('Qualy Mail versandt');
        System.assertEquals(true, containsDesc);
        System.assertEquals('6+d', testLeadResult.EmailHelper__c);
    }
}