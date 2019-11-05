/**
 * Created by m.muchow on 05.03.2019.
 */

public without sharing class noAnswerController {

    @AuraEnabled(Cacheable=true)
    public static String getNoAnswerValue(Id recordId) {
        String fieldValue = [SELECT EmailHelper__c FROM Lead WHERE Id =: recordId].EmailHelper__c;
        if (fieldValue == null || String.isBlank(fieldValue)) {
            fieldValue = '1';
        }
        return fieldValue;
    }

    @AuraEnabled
    public static void sendEmailNoAns(Id recordId, String helperValue) {
        String emailTemplate;
        String helperValueDesc;
        Lead updateLead = [SELECT Id, EmailHelper__c FROM Lead WHERE Id =: recordId];
        LeadEmailSetting__mdt custMeta = getCustomMetadata(recordId);
        if (helperValue.contains('+')) {
            updateLead.EmailHelper__c = String.valueOf(Integer.valueOf(helperValue.left(1))+1)+helperValue.right(2);
            helperValueDesc = helperValue.left(1);
            if (helperValueDesc == '1' || helperValueDesc == '3' || helperValueDesc == '5') {
                emailTemplate = String.valueOf(custMeta.get('EmailNoAnswerTemplate'+helperValue.left(1)+'__c'));
            }
        } else {
            updateLead.EmailHelper__c =  String.valueOf(Integer.valueOf(helperValue)+1);
            helperValueDesc = helperValue;
            if (helperValueDesc == '1' || helperValueDesc == '3' || helperValueDesc == '5') {
                emailTemplate = String.valueOf(custMeta.get('EmailNoAnswerTemplate' + helperValue + '__c'));
            }
        }
        if (helperValueDesc == '1' || helperValueDesc == '3' || helperValueDesc == '5') {
            sendEmail.sendEmailActionRequest request = emailRequest(recordId, emailTemplate);
            sendEmail.sendEmails(new sendEmail.sendEmailActionRequest[]{request});
        }
        updateDescription(recordId, helperValueDesc);
        update(updateLead);
    }

    @AuraEnabled
    public static void sendEmailQualy(Id recordId) {
        String helperValue = 'qualy';
        Lead updateLead = [SELECT Id, EmailHelper__c FROM Lead WHERE Id =: recordId];
        LeadEmailSetting__mdt custMeta = getCustomMetadata(recordId);
        if (updateLead.EmailHelper__c == null || String.isBlank(updateLead.EmailHelper__c)) {
            updateLead.EmailHelper__c = '1+q';
        } else if (updateLead.EmailHelper__c == '6+q' || updateLead.EmailHelper__c == '6') {
            updateLead.EmailHelper__c = '6+d';
        } else if (!updateLead.EmailHelper__c.contains('+q')){
            updateLead.EmailHelper__c = updateLead.EmailHelper__c+'+q';
        }
        sendEmail.sendEmailActionRequest request = emailRequest(recordId, custMeta.EmailQualifyingTemplate__c);
        sendEmail.sendEmails(new sendEmail.sendEmailActionRequest[]{request});
        updateDescription(recordId, helperValue);
        update(updateLead);
    }

    @AuraEnabled
    public static LeadEmailSetting__mdt getCustomMetadata(Id recordId) {
        String targetCountry = [SELECT TargetCountry__c FROM Lead WHERE Id =: recordId].TargetCountry__c;
        LeadEmailSetting__mdt custMeta = [SELECT EmailNoAnswerTemplate1__c, EmailNoAnswerTemplate3__c, EmailNoAnswerTemplate5__c, EmailQualifyingTemplate__c FROM LeadEmailSetting__mdt WHERE Label =: targetCountry];
        return custMeta;
    }

    public static sendEmail.sendEmailActionRequest emailRequest(Id recordId, String emailTemplate) {
        Lead leadRequest = [SELECT Email FROM Lead WHERE Id =: recordId];
        sendEmail.sendEmailActionRequest request = new sendEmail.sendEmailActionRequest();
            request.toAddress = leadRequest.Email;
            request.targetObjectId = recordId;
            request.apiTemplateName = emailTemplate;
            request.saveAsActivity = true;
        return request;
    }

    public static void updateDescription(Id recordId, String helperDesc) {
        Lead leadDesc = [SELECT Description2__c FROM Lead WHERE Id =: recordId];
        String descHelper = leadDesc.Description2__c;
        String currentUserAlias;
        String descText;
        if (Test.isRunningTest()) {
            currentUserAlias = 'TestUser';
        } else {
            currentUserAlias = UserInfo.getFirstName().left(1)+UserInfo.getLastName();
        }
        if (helperDesc == '2' || helperDesc == '2+q' || helperDesc == '4' || helperDesc == '4+q') {
            descText = '\n\n';
        } else if (helperDesc == 'qualy') {
            descText = '\n - Qualy Mail versandt \n\n';
        } else {
            descText = '\n - Mail versandt ('+helperDesc+') \n\n';
        }
        String noAnswerText = System.Date.today().format()+' '+currentUserAlias+' '+String.valueOf(System.Datetime.now().time()).left(5)+' KA'+descText;
        leadDesc.Description2__c = noAnswerText;
        leadDesc.Description2__c += descHelper;
        update leadDesc;
    }
}