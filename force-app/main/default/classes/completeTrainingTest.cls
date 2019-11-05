/**
 * completeTrainingTest
 *
 * Test Class for the Apex Class 'completeTraining'
 *
 * @see completeTraining
 *
 * ___ Changelog ___
 * v 1.0 Michael Muchow 2018-03-20
 *
 * @version 1.0
 */

@isTest
public  class completeTrainingTest {
    @testSetup 
    static void testSetup() {
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
        insert attCons;

        Training__c newTraining = new Training__c(Name = 'Test Training', StartDate__c = DateTime.Now().AddDays(1), Trainings_Location__c = trainLocation.Id, Certification__c = cert.Id, TechnicalTrainer__c = trainer.Id);
        insert newTraining;

        List<TrainingAttendance__c> atts = new List<TrainingAttendance__c>();
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[0].Id, DocumentType__c = 'Certificate DE'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[1].Id, DocumentType__c = 'Participation Confirmation DE'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[2].Id, DocumentType__c = 'Certificate IT'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[3].Id, DocumentType__c = 'Participation Confirmation IT'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[4].Id, DocumentType__c = 'Certificate EN'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[5].Id, DocumentType__c = 'Participation Confirmation EN'));
        atts.add(new TrainingAttendance__c(Training__c = newTraining.Id, Contact__c = attCons[6].Id, DocumentType__c = 'Certificate US'));
        insert atts;
    }

    @isTest
    static void testConcludeTraining() {
        Id recordId = [SELECT Id from Training__c].Id;
        
        Test.startTest();
        completeTraining.concludeTraining(recordId);
        TrainingAttendance__c trainAtt = [SELECT Id FROM TrainingAttendance__c WHERE DocumentType__c = 'Certificate IT'];
        ApexPages.StandardController sc = new ApexPages.StandardController(trainAtt);
        certificationExtension ext = new certificationExtension(sc);
        completeTraining.createCerts(recordId);
        completeTraining.sendCerts(recordId);
        Test.stopTest();

        Training__c train = [SELECT Id, Status__c FROM Training__c];
        ContentVersion[] createdCV = [SELECT Id FROM ContentVersion];
        EmailMessage[] mail = [SELECT Id FROM EmailMessage];
        Certificate__c cert = [SELECT Id, EndDate__c FROM Certificate__c WHERE DocumentType__c = 'Certificate IT'];
        System.assertEquals('Training Completed', train.Status__c);
        System.assertEquals(true, createdCV.size() >= 7);
        System.assertEquals(true, mail.size() >= 7);
        System.assertEquals(ext.endDate, cert.EndDate__c);
    }

    @isTest
    static void testCancelTrain() {
        Id recordId = [SELECT Id from Training__c].Id;
        Test.startTest();
        completeTraining.cancelTrain(recordId);
        Test.stopTest();

        Training__c train = [SELECT Id, Status__c FROM Training__c];
        System.assertEquals('Cancelled', train.Status__c);
    }
    @isTest
    static void testAttendanceList() {
        Id recordId = [SELECT Id from Training__c].Id;
        Test.startTest();
        completeTraining.attendanceList(recordId);
        Test.stopTest();
        
        ContentVersion[] createdCV = [SELECT Id FROM ContentVersion];
        System.assertEquals(true, createdCV.size() == 1);
    }
}