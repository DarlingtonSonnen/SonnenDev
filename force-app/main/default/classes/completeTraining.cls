/**
 * completeTraining
 *
 * Apex Class for the Object Training__c to execute actions depending on the Button used from the Lightning Component 'TrainingControls'
 *
 * @see TrainingControls
 * @see completeTrainingTest
 *
 * ___ Changelog ___
 * v 1.0 Michael Muchow 2018-03-20
 * v 1.1 Michael Muchow 2018-03-22
 * 		    added interception logics for non technician attendees and 'None' DocumentType__c
 * v 1.2 Michael Muchow 2018-05-09
 *          changed 'System.now()' to 'datetime.now()'
 *          added new fields to queries for Lightning Component
 *          added function for certification creation to get NABCEP hours from training record
 * v 1.3 Michael Muchow 2018-06-20
 *			added without sharing to class to query all contacts
 * v 1.4 Michel Muchow 2018-06-25
 *          changed Query for certification ID to get only Values starting with a number
 *          added line 39 and changed line 40
 * v 1.5 Michael Muchow 2018-07-10
 *          changed pdf title generation to dismiss null values for certification id and firstname
 *          added pdf title 'NABCEP' for us certification instead of certification id
 * v 1.6 Michael Muchow 2018-07-31
 *          added possiblity to use a second Document Type for certificates
 * v 1.7 Michael Muchow 2018-08-28
 *          change Method 'createCerts' and 'sendCerts' to use maps instead of SOQL For Loops
 *
 * @version 1.7
 */

global without sharing class completeTraining {

    @AuraEnabled
    global static void concludeTraining(ID recordId) {

        List<TrainingAttendance__c> trainAtts = new List<TrainingAttendance__c>();
        List<TrainingAttendance__c> updateAtts = new List<TrainingAttendance__c>();
        List<Certificate__c> insertCert = new List<Certificate__c>();
        List<Contact> updateCon = new List<Contact>();
        ID newRecordType = [SELECT ID FROM RecordType WHERE DeveloperName = 'Technician'].ID;
        String userName = [SELECT ID, Name from User WHERE ID =: userinfo.getUserId()].Name;
        Set<ID> conIdSet = new Set<ID>();
        Map<ID, ID> attConMap = new Map<ID, ID>();
        Set<String> numQuery = new Set<String>{'0%','1%','2%','3%','4%','5%','6%','7%','8%','9%'};
        Integer conCertNum = Integer.valueOf([SELECT ID, TopMCertificationId__c FROM Contact WHERE TopMCertificationId__c LIKE :numQuery ORDER BY TopMCertificationId__c DESC NULLS LAST LIMIT 1].TopMCertificationId__c);

        if (conCertNum < 40000) {
            conCertNum = 40000;
        }

        Training__c training = [SELECT Id, Certification__c, CompletedDate__c, CompletedUser__c, Status__c, NABCEPHours__c FROM Training__c WHERE ID =:recordId];
        training.Status__c = 'Training Completed';
        training.CompletedDate__c = datetime.now();
        training.CompletedUser__c = userinfo.getName();
        update training;

        for (Training__c train : [SELECT ID, Name,
        (SELECT ID, Contact__c, Training__c, Contact__r.TopMCertificationid__c,
                Status__c, Contact__r.RecordTypeId, Contact__r.Type__c, Contact__r.TopMSeller__c,
                Contact__r.TopMResponsible__c, NoTechnician__c, DocumentType__c
        FROM TrainingAttendances__r)
        FROM Training__c WHERE ID =: training.ID]) {
            for (TrainingAttendance__c trainAtt : train.TrainingAttendances__r) {
                TrainingAttendance__c trainCon = trainAtt;
                trainAtts.Add(trainCon);
                conIdSet.add(trainCon.Contact__C);
                attConMap.put(trainAtt.ID,trainCon.Contact__c);
            }
        }

        Map<ID, Contact> conMap = new Map<ID, Contact>([SELECT ID, TopMCertificationid__c, RecordTypeId, Type__c, TopMSeller__c, TopMResponsible__c from Contact WHERE ID IN : conIdSet]);

        for (TrainingAttendance__c trainCon : trainAtts) {

            if (trainCon.Status__c == 'Registered') {
                trainCon.Status__c = 'Attended';
                contact conUpd = conMap.get(attConMap.get(trainCon.ID));

                if (trainCon.NoTechnician__c != TRUE) {
                    if (conUpd.RecordTypeID != newRecordType) {
                        conUpd.RecordTypeID = newRecordType;
                    }
                    conUpd.Type__c = 'Technician';
                    conUpd.TopMSeller__c = userName;
                    conUpd.TopMResponsible__c = userName;
                    if (conUpd.TopMCertificationid__c == NULL) {
                        Integer conCertNumUp = conCertNum++;
                        conUpd.TopMCertificationid__c = String.valueOf(conCertNumUp+1);
                    }
                    if (trainCon.DocumentType__c != 'None') {
                        system.debug(trainCon.DocumentType__c);
                        Certificate__c newCert = new Certificate__c(
                                Contact__c = conUpd.ID, Training__c = training.ID,
                                Certification__c = training.Certification__c, StartDate__C = System.Today(),
                                DocumentType__c = trainCon.DocumentType__c, NABCEPHours__c = training.NABCEPHours__c
                        );
                        insertCert.Add(newCert);
                    }
                    updateCon.Add(conUpd);
                }
            }
            updateAtts.Add(trainCon);
        }
        update(updateAtts);
        update(updateCon);
        insert(insertCert);
    }

    @AuraEnabled
    global static void createCerts(ID recordId) {

        List<TrainingAttendance__c> trainAtts = new List<TrainingAttendance__c>();
        List<ContentVersion> cVL = new List<ContentVersion>();
        List<ContentDocumentLink> cDLTrain = new List<ContentDocumentLink>();
        List<ContentDocumentLink> cDLCert = new List<ContentDocumentLink>();
        Map<String, TrainingSetting__mdt> trainMap = new Map<String, TrainingSetting__mdt>();
        Map<String, String> certMap = new Map<String, String>();
        List<TrainingSetting__mdt> trainSetList = [SELECT Label, DocumentTypeCert__c, DocumentTypePart__c, CertificateDocument__c, ParticipationDocument__c,DocumentTypeCert2__c,CertificateDocument2__c FROM TrainingSetting__mdt];
        String pdfTitle;
        String pdfFirstname;

        for (TrainingSetting__mdt ts : trainSetList) {
            trainMap.put(ts.Label, ts);
        }

        for (String key : trainMap.keyset()) {
            certMap.put(trainMap.get(key).DocumentTypeCert__c,trainMap.get(key).CertificateDocument__c);
            certMap.put(trainMap.get(key).DocumentTypeCert2__c, trainMap.get(key).CertificateDocument2__c);
            certMap.put(trainMap.get(key).DocumentTypePart__c,trainMap.get(key).ParticipationDocument__c);
        }

        Training__c training = [SELECT ID, CertificationGenerateDate__c, CertificationGenerateUser__c  FROM Training__c WHERE ID =:recordId];
        training.CertificationGenerateDate__c = datetime.now();
        training.CertificationGenerateUser__c = userinfo.getName();
        update training;

        for (Training__c train : [SELECT ID, Name,
        (SELECT ID, Contact__c, Training__c, Training__r.Name, Contact__r.FirstName, Contact__r.LastName, Contact__r.TopMCertificationid__c, DocumentType__c, Status__c, NoTechnician__c
        FROM TrainingAttendances__r)
        FROM Training__c WHERE ID =: recordId]) {
            for (TrainingAttendance__c trainAtt : train.TrainingAttendances__r) {
                TrainingAttendance__c trainCon = trainAtt;
                trainAtts.Add(trainCon);
            }
        }

        for (TrainingAttendance__c trainCon : trainAtts) {
            if (trainCon.Status__c == 'Attended' && trainCon.DocumentType__c != 'None') {
                Pagereference pdf = new PageReference('/apex/'+certMap.get(trainCon.DocumentType__c));
                if (trainCon.DocumentType__c == 'Certificate US') {
                    pdfTitle = 'NABCEP - ';
                }
                else if (trainCon.Contact__r.TopMCertificationid__c == NULL) {
                    pdfTitle = '';
                }
                else {
                    pdfTitle = trainCon.Contact__r.TopMCertificationid__c+' - ';
                }
                if (trainCon.Contact__r.FirstName == NULL) {
                    pdfFirstname = '';
                }
                else {
                    pdfFirstname = trainCon.Contact__r.FirstName+' - ';
                }
                pdf.getParameters().put('id',trainCon.ID);
                ContentVersion cv = new ContentVersion();
                cv.ContentLocation = 'S';
                Blob body;
                if (Test.isRunningTest()) {
                    body = blob.valueOf('Test');
                }
                else {
                    body = pdf.getContent();
                }
                cv.VersionData = body;
                cv.PathOnClient = pdfTitle+pdfFirstname+' '+trainCon.Contact__r.LastName+'.pdf';
                cv.Title = pdfTitle+pdfFirstname+' '+trainCon.Contact__r.LastName;
                cv.FirstPublishLocationId = trainCon.Contact__c;
                cVL.Add(cv);
            }
        }
        insert cVL;

        // 2018-08-21
        // create set of contentdocument links
        Set<Id> contVersionIdSet = new Set<Id>();
        for (ContentVersion cv : cvl) {
            contVersionIdSet.add(cv.Id);
        }
        // create map of content version id as key and content version as value to get access to the contentDocumentId
        Map<Id, ContentVersion> contVersionMap = new Map<Id, ContentVersion>([SELECT Id, ContentDocumentId, FirstPublishLocationId FROM ContentVersion WHERE Id IN :contVersionIdSet]);
        // create map of content version id as key and list of certificates as value
            // create set of firstPublishLocations to query contacts
        List<Certificate__c> certificates = [SELECT Id, Contact__c FROM Certificate__c WHERE Training__c =: recordId];
        Map<Id, Id> ContVersionCertificationMap = new Map<Id, Id>(); // key is the the content version Id to refer when looping through cVL. Value is the corresponding certificate Id

        for (Id i : contVersionMap.keySet()) {
            for (Certificate__c c : certificates) {
                if (contVersionMap.get(i).FirstPublishLocationId == c.Contact__c) {
                    ContVersionCertificationMap.put(i, c.Id);
                }
            }
        }
        System.debug(certificates);
        System.debug(ContVersionCertificationMap);
        for (ContentVersion cvDoc : cVL) {
            //ID cvID = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =: cvDoc.ID].ContentDocumentId;
            ID cvID = contVersionMap.get(cvDoc.Id).ContentDocumentId;

            //List<Certificate__c> cvCerts = [SELECT ID FROM Certificate__c WHERE Training__c =: recordId AND Contact__c =: ([SELECT FirstPublishLocationId FROM ContentVersion WHERE Id =: cvDoc.ID].FirstPublishLocationId) LIMIT 1];
            //if (!cvCerts.isEmpty()){
                //ID cvCert = cvCerts[0].ID;
            if  (ContVersionCertificationMap.get(cvDoc.Id) != null) {
                ContentDocumentLink cDeCert = new ContentDocumentLink();
                cDeCert.ContentDocumentId = cvID;
                cDeCert.LinkedEntityId = ContVersionCertificationMap.get(cvDoc.Id);
                cDeCert.ShareType = 'V';
                cDeCert.Visibility = 'InternalUsers';

                cDLCert.Add(cDeCert);
            }
            ContentDocumentLink cDeTrain = new ContentDocumentLink();
            cDeTrain.ContentDocumentId = cvID;
            cDeTrain.LinkedEntityId = recordId;
            cDeTrain.ShareType = 'V';
            cDeTrain.Visibility = 'InternalUsers';

            cDLTrain.Add(cDeTrain);
        }
        insert cDLTrain;
        insert cDLCert;
        System.debug(cDLTrain.size());
        System.debug(cDLCert.size());
    }

    @AuraEnabled
    global static void cancelTrain(ID recordId) {

        List<TrainingAttendance__c> trainAtts = new List<TrainingAttendance__c>();
        List<TrainingAttendance__c> updateAtts = new List<TrainingAttendance__c>();

        Training__c training = [SELECT CompletedDate__c, CompletedUser__c, Status__c FROM Training__c WHERE ID =:recordId];
        training.Status__c = 'Cancelled';
        training.CompletedDate__c = datetime.now();
        training.CompletedUser__c = userinfo.getName();
        update training;

        for (Training__c train : [SELECT ID, Name,
        (SELECT ID, Contact__c, Training__c, Contact__r.TopMCertificationid__c, Status__c, Contact__r.RecordTypeId, Contact__r.Type__c, Contact__r.TopMSeller__c, Contact__r.TopMResponsible__c
        FROM TrainingAttendances__r)
        FROM Training__c WHERE ID =: training.ID]) {
            for (TrainingAttendance__c trainAtt : train.TrainingAttendances__r) {
                TrainingAttendance__c trainCon = trainAtt;
                trainAtts.Add(trainCon);
            }
        }

        for (TrainingAttendance__c trainCon : trainAtts) {
            trainCon.Status__c = 'Cancelled by sonnen';
            updateAtts.Add(trainCon);
        }
        update updateAtts;
    }

    @AuraEnabled
    global static void attendanceList(ID recordId) {

        Pagereference pdf;
        pdf = Page.AttendanceList;
        pdf.getParameters().put('id',recordId);
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        Blob body;
        if (Test.isRunningTest()) {
            body = Blob.valueOf('Test');
        }
        else {
            body = pdf.getContent();
        }
        cv.VersionData = body;
        cv.PathOnClient = 'Attendance List.pdf';
        cv.Title = 'Attendance List';
        cv.FirstPublishLocationId = recordId;
        insert cv;
    }

    @AuraEnabled
    global static void sendCerts(ID recordId) {

        List<TrainingAttendance__c> trainAtts = new List<TrainingAttendance__c>();
        List<Messaging.SingleEmailMessage> listMails = new List<Messaging.SingleEmailMessage>();
        Set<Id> contentDocIds = new Set<Id>();
        Id emailTemplate;
        Id orgWideAddress;
        Map<String, TrainingSetting__mdt> trainMap = new Map<String, TrainingSetting__mdt>();
        Map<String, TrainingSetting__mdt> certMap = new Map<String, TrainingSetting__mdt>();
        Map<String, TrainingSetting__mdt> langMap = new Map<String, TrainingSetting__mdt>();
        Map<String, ID> certIDMap = new Map<String, ID>();
        Map<String, ID> emailMap = new Map<String, ID>();
        Map<Id, Id> contVersionMap = new Map<Id, Id>();
        List<TrainingSetting__mdt> trainSetList = [SELECT Label, EmailTemplateCertificate__c, SendFrom__c, DocumentTypeCert__c, DocumentTypeCert2__c, DocumentTypePart__c, Language__c FROM TrainingSetting__mdt];

        for (TrainingSetting__mdt ts : trainSetList) {
            trainMap.put(ts.Label, ts);
        }

        for (String key : trainMap.keyset()) {
            certMap.put(trainMap.get(key).DocumentTypeCert__c,trainMap.get(key));
            certMap.put(trainMap.get(key).DocumentTypeCert2__c,trainMap.get(key));
            certMap.put(trainMap.get(key).DocumentTypePart__c,trainMap.get(key));
        }

        for (String key : trainMap.keyset()) {
            langMap.put(trainMap.get(key).Language__c,trainMap.get(key));
        }

        for (String Key : certMap.keySet()) {
            certIDMap.put(key,[SELECT Id FROM OrgWideEmailAddress WHERE Address =: certMap.get(key).SendFrom__c LIMIT 1].Id);
        }

        for (String Key : langMap.keySet()) {
            emailMap.put(key,[SELECT Id FROM EmailTemplate WHERE DeveloperName =: langMap.get(key).EmailTemplateCertificate__c LIMIT 1].Id);
        }

        for (Training__c train : [SELECT ID, Name,
        (SELECT ID, Contact__c, Training__c, Training__r.Name, Contact__r.Email, Contact__r.Language__c, Contact__r.FirstName, Contact__r.LastName, Contact__r.TopMCertificationid__c, DocumentType__c, Status__c
        FROM TrainingAttendances__r)
        FROM Training__c WHERE ID =: recordId]) {
            for (TrainingAttendance__c trainAtt : train.TrainingAttendances__r) {
                TrainingAttendance__c trainCon = trainAtt;
                trainAtts.Add(trainCon);
            }
        }

        List<ContentDocumentLink> contentDocLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId =: recordId];

        for(ContentDocumentLink contentDocLink : contentDocLinks) {
            contentDocIds.add(contentDocLink.ContentDocumentId);
        }

        //List<Id> contentDocIdList = new List<Id>(contentDocIds);

        //create Map of contact and contentVersion to use instead a SOQL for loop
        Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>([SELECT Id, FirstPublishLocationId FROM ContentVersion WHERE ContentDocumentId IN :contentDocIds]);
        for (String key : contentVersionMap.keySet()) {
            contVersionMap.put(contentVersionMap.get(key).FirstPublishLocationId, contentVersionMap.get(key).Id);
        }

        Training__c training = [SELECT ID, CertificateSendDate__c, CertificateSendUser__c  FROM Training__c WHERE ID =:recordId];
        training.CertificateSendDate__c = datetime.now();
        training.CertificateSendUser__c = userinfo.getName();
        update training;



        for (TrainingAttendance__c trainCon : trainAtts) {
            if (trainCon.DocumentType__c != 'None') {
                List<Id> cvIDList = new List<Id>();
                /*for (ContentVersion cv : [SELECT ID FROM ContentVersion WHERE ContentDocumentId IN :contentDocIdList AND IsLatest = True AND FirstPublishLocationId =: trainCon.Contact__c]) {
                    cvIDList.add(cv.ID);
                } */
                cvIDList.add(contVersionMap.get(trainCon.Contact__c));
                if (trainCon.Contact__r.Email != NULL) {
                    emailTemplate =  emailMap.get(trainCon.Contact__r.Language__c);
                    orgWideAddress = certIDMap.get(trainCon.DocumentType__c);
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setEntityAttachments(cvIDList);
                    mail.setToAddresses(new String[]{trainCon.Contact__r.Email});
                    mail.setTargetObjectId(trainCon.Contact__c);
                    mail.setWhatId(recordId);
                    mail.setTemplateId(emailTemplate);
                    mail.setOrgWideEmailAddressId(orgWideAddress);
                    listMails.Add(mail);
                }
            }
        }
        Messaging.sendEmail(listMails);
    }
}