/**
 * Created by m.muchow on 19.11.2018.
 * Update 12.12.2018
 *      added bulkification to work with more than 10 Emails
 *      removed file attachment to email and activity, needs to be addressed in the future
 * Update 14.12.2018
 *      removed 2 unnecessary SOQL queries and replaced with maps
 */

public class CreateAndSendEmail {

    private static Integer MAX_LENGTH_LONG_TEXT = 32000;

    public class EmailRequest {
        @InvocableVariable (Label='Contact Id' Description='Contact to relate Activity' Required = true)
        public String ContactId;

        @InvocableVariable (Label='Save Activity to Record Id' Description='Record to relate Activity' Required = true)
        public String SaveActivityToObjectId;

        @InvocableVariable (Label='To Email Address' Description='Send to Email Address' Required = true)
        public String EmailToAddress;

        @InvocableVariable (Label='From Email Address' Description='Send from Email Address' Required = true)
        public String EmailFromAddress;

        @InvocableVariable (Label='Email Template' Description='API Name of Email Template' Required = true)
        public String EmailTemplate;

        @InvocableVariable (Label='Account' Description='Account Id for Email Record')
        public String Account;

        @InvocableVariable (Label='Contact' Description='Contact Id for Email Record')
        public String Contact;

        @InvocableVariable (Label='Bank Data' Description='Bank Data Id for Email Record')
        public String BankData;

        @InvocableVariable (Label='Community Membership' Description='Community Membership Id for Email Record')
        public String CommmunityMembership;

        @InvocableVariable (Label='Meter Installation' Description='Meter Installation Id for Email Record')
        public String MeterInstallation;

        @InvocableVariable (Label='Monitoring eServices' Description='Monitoring eServices Id for Email Record')
        public String MonitoringeServices;

        @InvocableVariable (Label='Opportunity' Description='Opportunity Id for Email Record')
        public String Opportunity;

        @InvocableVariable (Label='sonnenFlat Contract' Description='sonnenFlat Contract Id for Email Record')
        public String sonnenFlatContract;

        @InvocableVariable (Label='Direct Marketing Contract' Description='Direct Marketing Contract Id for Email Record')
        public String DirectMarketingContract;

        @InvocableVariable (Label='Battery Asset' Description='Battery Asset Id for Email Record')
        public String BatteryAsset;

        @InvocableVariable (Label='PV-Plant Asset' Description='PV-Plant Asset Id for Email Record')
        public String PVPlantAsset;
    }

    public class EmailSenderException extends Exception {}

    @InvocableMethod (Label='Create Email and Send' Description='Creates an email record and sends email')
    public static List<EmailRequest> CreateAndSendEmail(List<EmailRequest> requests) {

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Messaging.SendEmailResult> emailResults = new List<Messaging.SendEmailResult>();
        List<EmailMessage> listEmailMessages = new List<EmailMessage>();

        Map<String, Id> templateMap = new Map<String, Id>();
//        Map<Id, String> templateIdMap = new Map<Id, String>();
        Map<String, Id> fromAddressMap = new Map<String, Id>();
        Map<String, String> orgAddressMap = new Map<String, String>();
        Map<String, String> orgDisplayNameMap = new Map<String, String>();
//        Map<String, Id> contentMap = new Map<String, Id>();

        Set<String> templates = new Set<String>();
        Set<String> fromAddresses = new Set<String>();
//        Set<Id> templateIds = new Set<Id>();

        for (EmailRequest eR : requests) {
            templates.add(eR.EmailTemplate);
            fromAddresses.add(eR.EmailFromAddress);
        }
        List<EmailTemplate> templateList = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN : templates];
        List<OrgWideEmailAddress> orgWideAddressList = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address IN : fromAddresses];


        for (EmailTemplate eT : templateList) {
            templateMap.put(eT.DeveloperName, eT.Id);
//            templateIdMap.put(eT.Id, eT.DeveloperName);
//            templateIds.add(eT.Id);
        }

        for (OrgWideEmailAddress oWA : orgWideAddressList) {
            fromAddressMap.put(oWA.Address, oWA.Id);
            orgAddressMap.put(oWA.Address, oWA.Address);
            orgDisplayNameMap.put(oWA.Address, oWA.DisplayName);
        }

        //add Attachment to Template
/*
        List<ContentDocumentLink> contentLinkList = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN : templateIds];

        for (ContentDocumentLink cDL : contentLinkList) {
            contentMap.put(templateIdMap.get(cDL.LinkedEntityId), cDL.ContentDocumentId);
        }

        Map<ContentVersion> documents = new List<ContentVersion>{};
        documents.addAll([SELECT Id, Title, FileType, VersionData, IsLatest, ContentDocumentId, FileExtension FROM ContentVersion WHERE IsLatest = TRUE AND ContentDocumentId IN :contentDocumentIds]);


        Map<String, List<Messaging.EmailFileAttachment>> emailAttachmentMap = ContentDocumentAsAttachement(contentMap);
*/

        for (EmailRequest request: requests) {
            try {
                validateEmailInput(request, templateMap, fromAddressMap);
                Id recordId = createEmailRecord(request);
                system.debug('map before '+templateMap);
                system.debug('id before '+templateMap.get(request.EmailTemplate));
                Messaging.SingleEmailMessage emailSent = sendEmail(request, recordId, templateMap, fromAddressMap);
                emails.add(emailSent);
                EmailMessage eMessage = insertEmailActivity(emailSent, request, orgAddressMap, orgDisplayNameMap);
                listEmailMessages.add(eMessage);
            } catch (Exception e) {
                createCase(request, e.getMessage());
                System.debug('CreateAndSendEmail '+e.getMessage());
            }
        }
        try {
            emailResults = Messaging.sendEmail(emails, false);
            for (Messaging.SendEmailResult result : emailResults) {
                if (!result.isSuccess()) {
                    throw new EmailSenderException('Error while sending email: ' + result.getErrors()[0].getMessage());
                }
            }
            insert listEmailMessages;
            updateEmailRelation(listEmailMessages);
        } catch (Exception e) {
            System.debug('CreateAndSendEmail '+e.getMessage());
        }
        return null;
    }

    public static Id createEmailRecord(EmailRequest request) {
        Email__c emailRecord = new Email__c();
        if (!String.isBlank(request.Account)) {
            emailRecord.Account__c = Id.valueOf(request.Account);
        }
        if (!String.isBlank(request.sonnenFlatContract)) {
            emailRecord.sonnenFlatContract__c = Id.valueOf(request.sonnenFlatContract);
        }
        if (!String.isBlank(request.DirectMarketingContract)) {
            emailRecord.DirectMarketingContract__c = Id.valueOf(request.DirectMarketingContract);
        }
        if (!String.isBlank(request.BatteryAsset)) {
            emailRecord.AssetBattery__c = Id.valueOf(request.BatteryAsset);
        }
        if (!String.isBlank(request.PVPlantAsset)) {
            emailRecord.AssetPVPlant__c = Id.valueOf(request.PVPlantAsset);
        }
        if (!String.isBlank(request.Contact)) {
            emailRecord.Contact__c = Id.valueOf(request.Contact);
        }
        if (!String.isBlank(request.BankData)) {
            emailRecord.BankData__c = Id.valueOf(request.BankData);
        }
        if (!String.isBlank(request.CommmunityMembership)) {
            emailRecord.CommunityMembership__c = Id.valueOf(request.CommmunityMembership);
        }
        if (!String.isBlank(request.MeterInstallation)) {
            emailRecord.MeterInstallation__c = Id.valueOf(request.MeterInstallation);
        }
        if (!String.isBlank(request.MonitoringeServices)) {
            emailRecord.MonitoringeServices__c = Id.valueOf(request.MonitoringeServices);
        }
        if (!String.isBlank(request.Opportunity)) {
            emailRecord.Opportunity__c = Id.valueOf(request.Opportunity);
        }
        insert emailRecord;
        return emailRecord.Id;

    }

    public static Messaging.SingleEmailMessage sendEmail(EmailRequest request, Id recordId, Map<String, Id> templateMap, Map<String, Id> fromAddressMap) {
        system.debug('map after '+templateMap);
        system.debug('id after '+templateMap.get(request.EmailTemplate));
        Messaging.SingleEmailMessage mail = Messaging.renderStoredEmailTemplate(templateMap.get(request.EmailTemplate),request.ContactId,recordId);
        mail.setTargetObjectId(request.ContactId);
        mail.setTreatTargetObjectAsRecipient(false);
        mail.setToAddresses(new String[]{request.EmailToAddress});
        mail.setTemplateId(templateMap.get(request.EmailTemplate));
        mail.setWhatId(recordId);
        mail.setOrgWideEmailAddressId(fromAddressMap.get(request.EmailFromAddress));
        mail.setBccSender(false);
        mail.setUseSignature(false);
        mail.setSaveAsActivity(false);
        //mail.fileAttachments = null;
//attach file to email-Message
/*      if (!contentDocIds.isEmpty()) {
            mail.fileAttachments = ;
            for (ContentDocumentLink cLL : contentLinkList) {
                mail.entityAttachments.add(String.valueOf(cLL.ContentDocumentId));
            }
        }
*/
        return mail;
    }

    public static EmailMessage insertEmailActivity(Messaging.SingleEmailMessage emailSent, EmailRequest request, Map<String, String> orgAddressMap, Map<String, String> orgDisplayNameMap) {
        EmailMessage message = new EmailMessage();
        if (emailSent.targetObjectId != null) {
            message.Contact__c = request.ContactId;
            message.Status = '3';
            message.Subject = emailSent.subject;
            message.FromAddress = orgAddressMap.get(request.EmailFromAddress);
            message.RelatedToId = request.SaveActivityToObjectId;
            message.ToAddress = emailSent.toAddresses[0];
            message.FromName = orgDisplayNameMap.get(request.EmailFromAddress);
            message.MessageDate = Datetime.now();
            if (emailSent.htmlBody != null) {
                message.HtmlBody = cutIfNeeded(emailSent.htmlBody);
            }
            if (emailSent.plainTextBody != null) {
                message.TextBody = cutIfNeeded(emailSent.plainTextBody);
            }
        }
        return message;
    }

    public static void updateEmailRelation(List<EmailMessage> messages) {
        // update Email Message Relation after insert
        List<EmailMessageRelation> relationList = [SELECT Id, RelationId, RelationType FROM EmailMessageRelation WHERE EmailMessageId IN :messages];
        List<EmailMessageRelation> updateRelation = new List<EmailMessageRelation>();
        for (EmailMessage message : messages) {
            for (EmailMessageRelation eMR : relationList) {
                if (eMR.RelationType == 'FromAddress') {
                    eMR.RelationId = UserInfo.getUserId();
                }
                if (eMR.RelationType == 'ToAddress') {
                    eMR.RelationId = message.Contact__c;
                }
                updateRelation.add(eMR);
            }
        }
        update updateRelation;
    }
/*
       // relate files or create new attachments(for documents) for Email Message Activity
       List<ContentDocumentLink> cDLList = new List<ContentDocumentLink>();
       List<Attachment> attachList = new List<Attachment>();
       for (String attachment : emailSent.entityAttachments) {
           if (attachment.startsWith('069')) {
               ContentDocumentLink cdl = new ContentDocumentLink();
               cdl.ContentDocumentId = attachment;
               cdl.LinkedEntityId = message.Id;
               cdl.ShareType = 'V';
               cdl.Visibility = 'InternalUsers';
               cDLList.add(cdl);
           }
           if (attachment.startsWith('015')) {
               Document doc = [SELECT Name, Body FROM Document WHERE Id =: attachment];
               Attachment a = new Attachment();
               a.Name = doc.Name;
               a.Body = doc.Body;
               a.ParentId = message.Id;
               attachList.add(a);
           }
       }
       if (!cDLList.isEmpty()) {
           insert cDLList;
       }
       if (!attachList.isEmpty()) {
           insert attachList;
       }
    }

    public static Map<String, List<Messaging.EmailFileAttachment>> ContentDocumentAsAttachement(Map<String, Id> contentMap) {
        Map<String, Messaging.EmailFileAttachment> attachmentsMap = new Map<String, Messaging.EmailFileAttachment>{};
        for (ContentVersion document: documents) {
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setBody(document.VersionData);
            attachment.setFileName(document.Title+'.'+document.FileExtension);
            attachmentsMap.put(contentMap.getattachment);

        }
        return attachments;
    }
*/

    private static void validateEmailInput(EmailRequest request, Map<String, Id> templateMap, Map<String, Id> orgWideAddressmap) {
        if (request.ContactId == null || request.ContactId == '') {
            throw new EmailSenderException('Contact not specified');
        }
        if (request.SaveActivityToObjectId == null || request.SaveActivityToObjectId == '') {
            throw new EmailSenderException('Record Id to relate activity not specified');
        }
        if (request.EmailToAddress == null || request.EmailToAddress == '') {
            throw new EmailSenderException('No address to send email specified');
        }
        if (templateMap.isEmpty()) {
            throw new EmailSenderException('Template with API Name '+request.EmailTemplate+' not found');
        }
        if (orgWideAddressmap.isEmpty()) {
            throw new EmailSenderException('There is no org wide email address named (or no access to) '+request.EmailFromAddress+' to send the email from');
        }
    }

    private static void createCase(EmailRequest request, String errorMessage) {
        Contact[] excContacts = [SELECT Id FROM Contact WHERE Id = :request.ContactId];
        Contract[] excSObjects = [SELECT Id FROM Contract WHERE Id = :request.SaveActivityToObjectId];
        String contactId;
        String sobjectId;
        if (!excContacts.isEmpty()) {
            contactId = excContacts.get(0).Id;
        }
        if (!excSObjects.isEmpty()) {
            sobjectId = excSObjects.get(0).Id;
        }
        String caseRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Case' AND DeveloperName = 'eServices'].Id;

        Case c = new Case();
        c.Subject = 'Email Automation: ' + errorMessage;
        c.RecordTypeId = caseRecordType;
        c.Status = 'New';
        c.Priority = 'High';
        c.ContactId = contactId;
        c.Type = 'Incident';
        c.Description = 'Template: ' + request.EmailTemplate + '\n' +
                'Datetime: ' + Datetime.now() + '\n' +
                'Username(id): ' + UserInfo.getUserName() + ' (' + UserInfo.getUserId() + ')\n' +
                'Error: ' + errorMessage;
        insert c;
    }

    private static String cutIfNeeded(String str) {
        return str.length() > MAX_LENGTH_LONG_TEXT ? str.substring(0, MAX_LENGTH_LONG_TEXT) : str;
    }
}