/**
 * EmailSender
 *
 * --- Changelog
 *
 * v 1.3 Polina Tsuban-Drobot   2018-06-14 added cutting of too long strings for insert EmailMessage (SOBCRM-1201)
 * v 1.2 Michael Muchow 2018-02-14
 *       check for ObjectType of whatId and exclude message.Contract__c = emailSent.whatId; if whatId != Contract
 * v 1.1 Igor Savchenko 2018-01-16 SOBCRM-1127
 * v 1.0 Igor Savchenko 2017-12-08 SOBCRM-1125
 *
 * @version 1.3
 */
public with sharing class EmailSender {

    private static Integer MAX_LENGTH_LONG_TEXT = 32000;

    public class SendEmailRequest {
        @InvocableVariable(required=false)
        public String contactId;

        @InvocableVariable(required=false)
        public String contractId;

        @InvocableVariable(required=false)
        public String emailAddress;

        @InvocableVariable(required=false)
        public String emailTemplate;

        @InvocableVariable(required=false)
        public String emailAddressFrom;
    }

    public class EmailSenderException extends Exception {}

    @InvocableMethod (label='Send Email' description='Sends email using particular email template and saves data to EmailMessage')
    public static void sendEmail(List<SendEmailRequest> requests) {
        for (SendEmailRequest request: requests) {
            try {
                validateFields(request);
                Messaging.SingleEmailMessage emailSent = sendEmail(request);
                insertEmailMessage(emailSent, request);
            } catch (Exception e) {
                createCase(request, e.getMessage());
            }
        }
    }

    private static Messaging.SingleEmailMessage sendEmail(SendEmailRequest request) {
        EmailTemplate emailTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :request.emailTemplate LIMIT 1];
        OrgWideEmailAddress orgWideAddress = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = :request.emailAddressFrom LIMIT 1];

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(request.contactId);
        mail.setTreatTargetObjectAsRecipient(false);
        mail.setToAddresses(new String[]{request.emailAddress});
        mail.setTemplateId(emailTemplate.Id);
        mail.setWhatId(request.contractId);
        mail.setOrgWideEmailAddressId(orgWideAddress.Id);
        mail.setBccSender(false);
        mail.setUseSignature(false);
        mail.setSaveAsActivity(true);
        if (!isComplianceBccEnabled()) {
            mail.setBccAddresses(new List<String>{EmailSender__c.getInstance().BccAddress__c});
        }
        // We have to avoid this part of code in unit tests, as there is no good way to test email sending
        if (!Test.isRunningTest()) {
            Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
            if (!emailResults.get(0).isSuccess()) {
                throw new EmailSenderException('Error while sending email: ' + emailResults.get(0).getErrors().get(0).getMessage());
            }
        }
        return mail;
    }

    private static void validateFields(SendEmailRequest request) {
        if (request.contactId == null || request.contactId == '') {
            throw new EmailSenderException('Contact not specified.');
        }
        if (request.contractId == null || request.contractId == '') {
            throw new EmailSenderException('Contract not specified.');
        }
        if (request.emailAddress == null || request.emailAddress == '') {
            throw new EmailSenderException('No email address specified.');
        }
        EmailTemplate[] emailTemplates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :request.emailTemplate];
        if (emailTemplates.isEmpty()) {
            throw new EmailSenderException('Template not found: ' + request.emailTemplate);
        }
        OrgWideEmailAddress[] orgWideAddresses = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = :request.emailAddressFrom];
        if (orgWideAddresses.isEmpty()) {
            throw new EmailSenderException('There is no org wide email address (or no access to): ' + request.emailAddressFrom);
        }
    }

    private static Boolean isComplianceBccEnabled() {
        Boolean bccComplianceEnabled;
        Messaging.SingleEmailMessage m = new messaging.singleEmailmessage();
        m.bccsender = true;
        try {
            Messaging.sendEmail(new messaging.singleemailmessage[] {m});
        } catch (emailexception e) {
            bccComplianceEnabled = e.getDmlType(0) == StatusCode.BCC_NOT_ALLOWED_IF_BCC_COMPLIANCE_ENABLED;
        }
        return bccComplianceEnabled;
    }

    private static void createCase(SendEmailRequest request, String errorMessage) {
        Contact[] excContacts = [SELECT Id FROM Contact WHERE Id = :request.contactId];
        Contract[] excContracts = [SELECT Id FROM Contract WHERE Id = :request.contractId];
        String contactId;
        String contractId;
        if (!excContacts.isEmpty()) {
            contactId = excContacts.get(0).Id;
        }
        if (!excContracts.isEmpty()) {
            contractId = excContracts.get(0).Id;
        }
        String caseRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Case' AND DeveloperName = 'eServices'].Id;

        Case c = new Case();
        c.Subject = 'Email Automation: ' + errorMessage;
        c.RecordTypeId = caseRecordType;
        c.Status = 'New';
        c.Priority = 'Critical';
        c.ContactId = contactId;
        c.Type = 'Incident';
        c.Contract__c = contractId;
        c.Description = 'Template: ' + request.emailTemplate + '\n' +
                'Datetime: ' + Datetime.now() + '\n' +
                'Username(id): ' + UserInfo.getUserName() + ' (' + UserInfo.getUserId() + ')\n' +
                'Error: ' + errorMessage;
        insert c;
    }

    private static void insertEmailMessage(Messaging.SingleEmailMessage emailSent, SendEmailRequest request) {
        OrgWideEmailAddress orgWideAddress = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = :request.emailAddressFrom LIMIT 1];

        if (emailSent.targetObjectId != null) {
            String objectType = String.valueOf(Id.valueOf(emailSent.whatID).getSObjectType());

            EmailMessage message = new EmailMessage();
            if (objectType == 'Contract'){
                message.Contract__c = emailSent.whatId;
            }
            message.Contact__c = emailSent.targetObjectId;
            message.Status = '3';
            message.Subject = emailSent.subject;
            message.FromAddress = orgWideAddress.Address;
            message.ToAddress = emailSent.toAddresses.get(0);
            message.HtmlBody = cutIfNeeded(emailSent.htmlBody);
            message.TextBody = cutIfNeeded(emailSent.plainTextBody);
            insert message;
        }
    }

    private static String cutIfNeeded(String str) {
        return str.length() > MAX_LENGTH_LONG_TEXT ? str.substring(0, MAX_LENGTH_LONG_TEXT) : str;
    }
}