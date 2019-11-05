/**
 * attendanceListControllerTest
 *
 * Test Class for the Controller Extension 'attendanceListController'
 *
 * @see attendanceListController
 *
 * ___ Changelog ___
 * v 1.0 Michael Muchow 2018-03-20
 *
 * @version 1.0
 */

@isTest
public class attendanceListControllerTest {
    @testSetup
    static void testSetup () {
        ID locationRecordTypeID = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Trainings Location').getRecordTypeId();
        Account trainLocation = new Account(Name = 'Trainings Location', RecordtypeId = locationRecordTypeID, BillingCity = 'City');
        insert trainLocation;

        ID partnerRecordTypeID = Schema.SObjectType.Account.getRecordTypeInfosByname().get('Partner').getRecordTypeId();
        Account attAccount = new Account(Name = 'Attendance Account', RecordtypeId = partnerRecordTypeID);
        insert attAccount;

        Certification__c cert = new Certification__c(Name = 'Test Cert');
        insert cert;

        Contact trainer = new Contact(FirstName = 'Test', LastName = 'Trainer', AccountId = trainLocation.Id);
        insert trainer;
		
        ID contactRecordTypeID = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Technician').getRecordTypeId();
        
        List<Contact> attCons = new List<Contact>();
        attCons.add(new Contact(FirstName = 'First', LastName = 'AttCertDE', Language__c = 'de', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com', TopMCertificationId__c = '123'));
        attCons.add(new Contact(FirstName = 'First', Lastname = 'AttPartDE', Language__c = 'de', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com'));
        attCons.add(new Contact(FirstName = 'First', LastName = 'AttCertIT', Language__c = 'it', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com'));
        attCons.add(new Contact(FirstName = 'First', Lastname = 'AttPartIT', Language__c = 'it', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com'));
        attCons.add(new Contact(FirstName = 'First', Lastname = 'AttCertInt', Language__c = 'en', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com'));
        attCons.add(new Contact(FirstName = 'First', LastName = 'AttPartInt', Language__c = 'en', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com'));
        attCons.add(new Contact(FirstName = 'First', Lastname = 'AttCertUS', Language__c = 'en', AccountId = attAccount.Id, Email ='spamtestemailtest@mailforspam.com'));
        system.debug('attCons '+attCons);
        insert attCons;

        Training__c newTraining = new Training__c(Name = 'Test Training', StartDate__c = DateTime.Now().AddDays(1), Trainings_Location__c = trainLocation.Id, Certification__c = cert.Id, TechnicalTrainer__c = trainer.Id);
        insert newTraining;

        List<TrainingAttendance__c> atts = new List<TrainingAttendance__c>();
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[0].Id, DocumentType__c = 'Certificate DE', Status__c = 'Registered'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[1].Id, DocumentType__c = 'Participation Confirmation DE', Status__c = 'Registered'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[2].Id, DocumentType__c = 'Certificate IT', Status__c = 'Registered'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[3].Id, DocumentType__c = 'Participation Confirmation IT', Status__c = 'Registered'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[4].Id, DocumentType__c = 'Certificate EN', Status__c = 'Registered'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[5].Id, DocumentType__c = 'Participation Confirmation EN', Status__c = 'Registered'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[6].Id, DocumentType__c = 'Certificate US', Status__c = 'Registered'));
        insert atts;
    }
    
    @isTest
    static void attendanceListControllerTest() {
        Training__c newTraining = [SELECT Id FROM Training__c];

        Pagereference pageRef = Page.AttendanceList;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.StandardController std = new Apexpages.StandardController(newTraining);
        attendanceListController controller = new attendanceListController (std);
        Test.stopTest();

        List<TrainingAttendance__c> attList = controller.attList;
        System.assertEquals(7, attList.size());
    }
}