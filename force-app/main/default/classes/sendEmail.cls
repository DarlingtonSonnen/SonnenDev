/*
* by Bartosz Jarmolinski
* v2.0 on 09/07/2018
* - enabled for bulkification
*
* v2.1 on 07/11/2018
* - put mail.setSubject and mail.setHtmlBody into if clause - to prevent from overwriting template values
*/
global without sharing class sendEmail {

    private static Integer maxLength = 32000;
    
    @InvocableMethod
    public static List<sendEmailActionResult> sendEmails(List<sendEmailActionRequest> requests) {
        
        List<sendEmailActionResult> results = new List<sendEmailActionResult>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        Map<String, Id> fromAddressesMap = new Map<String, Id>();
        Map<String, Id> templateIdsMap = new Map<String, Id>();
        Map<String, EmailTemplate> templateMap = new Map<String, EmailTemplate>();
        
        Set<String> fromSet = new Set<String>();
        Set<String> templates = new Set<String>();
        
        for (sendEmailActionRequest se : requests) {
            fromSet.add(se.orgWideFromEmail);
            templates.add(se.apiTemplateName);
        }
        
        List<orgWideEmailAddress> fromAddresses = [SELECT Id, Address FROM orgWideEmailAddress WHERE Address IN :fromSet ];
        List<EmailTemplate> templatesList = [SELECT Id, DeveloperName, Body, Subject, HtmlValue FROM EmailTemplate WHERE DeveloperName IN :templates];
        
        for (orgWideEmailAddress fromAdr : fromAddresses) {
            fromAddressesMap.put(fromAdr.Address, fromAdr.Id);
        }
        for (EmailTemplate et : templatesList) {
            templateIdsMap.put(et.DeveloperName, et.Id);
            templateMap.put(et.DeveloperName, et);
        }
        
        for (sendEmailActionRequest request : requests) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setOrgWideEmailAddressId(fromAddressesMap.get(request.orgWideFromEmail));
            mail.setTemplateId(templateIdsMap.get(request.apiTemplateName));
            mail.setToAddresses(new String[]{request.toAddress});
            mail.setCcAddresses(request.ccAddresses);
            mail.setBccAddresses(request.bccAddresses);
            mail.setEntityAttachments(request.entityAttachments);

            if (request.apiTemplateName == null) {
                mail.setSubject(request.subject);
                if (request.htmlBody != null) {
                    mail.setHtmlBody(request.htmlBody);
                }
            }
            mail.setTargetObjectId(request.targetObjectId);     
            mail.setWhatId(request.whatId);
            mail.saveAsActivity = request.saveAsActivity;
            mail.setTreatTargetObjectAsRecipient(false);
            emails.add(mail);
        }
        List<Messaging.SendEmailResult> resSent = new List<Messaging.SendEmailResult>();
        try {
            System.debug(emails);
            resSent = Messaging.sendEmail(emails, false);
            sendEmailActionResult result = new sendEmailActionResult();
            result.sent = true;
            results.add(result);
        } catch (Exception e) {
            System.debug(e);
            sendEmailActionResult result = new sendEmailActionResult();
            result.sent = false;
            results.add(result);            
        }
        System.debug(results);
        return results;
    }
    
    global class sendEmailActionRequest {
        @InvocableVariable
        global String orgWideFromEmail;

        @InvocableVariable(required = true)
        global String toAddress;

        @InvocableVariable
        global List<String> ccAddresses;

        @InvocableVariable
        global List<String> bccAddresses;

        @InvocableVariable
        global List<Id> entityAttachments;

        @InvocableVariable
        global String htmlBody;

        @InvocableVariable
        global String subject;      

        @InvocableVariable
        global Id targetObjectId;       

        @InvocableVariable
        global String apiTemplateName;

        @InvocableVariable
        global Id whatId;

        @InvocableVariable
        global Boolean saveAsActivity;
    }

    global class sendEmailActionResult {
        @InvocableVariable
        global Boolean sent;
    }
}