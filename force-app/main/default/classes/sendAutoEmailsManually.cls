/**
 * Created by m.muchow on 29.01.2019.
 */

public without sharing class sendAutoEmailsManually {

    @AuraEnabled
    public static List<EmailTemplate> getEmailTemplateList(Id recordId) {
        settingWrapper custMetaSettings = getCustomMetadata(recordId);
        List<String> templateList = custMetaSettings.custMetaWrapper.TemplateList__c.split(',');
        List<EmailTemplate> emailTemplateList = [SELECT Id, Subject, Description, DeveloperName FROM EmailTemplate WHERE DeveloperName IN: templateList ORDER BY DeveloperName ASC];
        return emailTemplateList;
    }

    public static settingWrapper getCustomMetadata(Id recordId) {
        settingWrapper setWrapper = new settingWrapper();

        //get RecordType from Object
        Schema.SObjectType sObjType = recordId.getSobjectType();
        String sObjName = sObjType.getDescribe().getName();
        String sObjRecQuery = 'SELECT RecordTypeId FROM '+sObjName+' WHERE Id = \''+recordId+'\'';

        SObject sObjRecQueryObject = Database.query(sObjRecQuery);

        Id recTypeId = String.valueOf(sObjRecQueryObject.get('RecordTypeId'));
        Map<Id, Schema.RecordTypeInfo> rtMapById = sObjType.getDescribe().getRecordTypeInfosById();
        String rtDeveloperName = rtMapById.get(recTypeId).getDeveloperName();


        //get CustomMetadata Fields and build Set
        Map<String, Schema.SObjectField> m = Schema.SObjectType.Manually_Email_Setting__mdt.fields.getMap();
        Set<String> keySet = new Set<String>();
        for(Integer i =0; i<m.values().size();i++) {
            if(m.values()[i].getDescribe().isCustom()) {
                keySet.add(m.values()[i].getDescribe().getName());
            }
        }

        //get chosen Custom Metadata Record
        String mdtFieldString = '';
        for(String key: keySet) {
            mdtFieldString += key+',';
        }

        mdtFieldString = mdtFieldString.substring(0, mdtFieldString.length()-1);
        String mdtQuery = 'SELECT '+mdtFieldString+' FROM Manually_Email_Setting__mdt WHERE Object__c = \''+sObjName+'\''+'AND RecordTypeDeveloperName__c = \''+rtDeveloperName+'\'';
        Manually_Email_Setting__mdt custMeta = Database.query(mdtQuery);

        setWrapper.custMetaWrapper = custMeta;
        setWrapper.keySetWrapper = keySet;

        return setWrapper;
    }

    @AuraEnabled
    public static Map<String, String> getObjectQueryMap(Id recordId) {

        settingWrapper custMetaSettings = getCustomMetadata(recordId);
        Set<String> keySet = custMetaSettings.keySetWrapper;
        Manually_Email_Setting__mdt custMeta = custMetaSettings.custMetaWrapper;

        //build sQuery Strings
        String fieldString = '';
        String objectString;
        Map<String, String> fieldMap = new Map<String, String>();
        Map<String, String> settingsMap = new Map<String, String>();
        Set<String> fieldKey = new Set<String>();

        for(String key : keySet) {
            if(key == 'TemplateList__c' || key == 'RecordTypeDeveloperName__c') {
                continue;
            }
            if(key == 'Object__c') {
                objectString = String.valueOf(custMeta.get(key));
            } else if(key == 'EmailFromAddress__c') {
                settingsMap.put(key.removeEnd('__c'),String.valueOf(custMeta.get(key)));
            } else if(String.valueOf(custMeta.get(key)) != null) {
                fieldKey.add(String.valueOf(custMeta.get(key)));
                fieldMap.put(key, String.valueOf(custMeta.get(key)));
            }
        }

        for(String key: fieldKey) {
            fieldString += key+',';
        }

        fieldString = fieldString.substring(0, fieldString.length()-1);
        String sQuery = 'SELECT '+fieldString+' FROM '+objectString+' WHERE Id =\''+recordId+'\'';

        SObject queryObject = Database.query(sQuery);

        for(String key : fieldMap.keySet()) {
            settingsMap.put(key.removeEnd('__c'), String.valueOf(queryObject.get(fieldMap.get(key))));
        }

        return settingsMap;
    }

    @AuraEnabled
    public static void sendEmail(Id recordId, String template) {
        Map<String, String> queryObjectMap = getObjectQueryMap(recordId);
        CreateAndSendEmail.EmailRequest request = new CreateAndSendEmail.EmailRequest();

            request.ContactId = queryObjectMap.get('ContactId');
            request.SaveActivityToObjectId = queryObjectMap.get('SaveActivityToObjectId');
            request.EmailToAddress = queryObjectMap.get('EmailToAddress');
            request.EmailTemplate = template;
            request.EmailFromAddress = queryObjectMap.get('EmailFromAddress');
            request.Account = queryObjectMap.get('Account');
            request.Contact = queryObjectMap.get('Contact');
            request.BankData = queryObjectMap.get('BankData');
            request.CommmunityMembership = queryObjectMap.get('CommmunityMembership');
            request.MeterInstallation = queryObjectMap.get('MeterInstallation');
            request.MonitoringeServices = queryObjectMap.get('MonitoringeServices');
            request.Opportunity = queryObjectMap.get('Opportunity');
            request.sonnenFlatContract = queryObjectMap.get('sonnenFlatContract');
            request.DirectMarketingContract = queryObjectMap.get('DirectMarketingContract');
            request.BatteryAsset = queryObjectMap.get('BatteryAsset');
            request.PVPlantAsset = queryObjectMap.get('PVPlantAsset');

        CreateAndSendEmail.CreateAndSendEmail(new CreateAndSendEmail.EmailRequest[]{request});
    }

    public class settingWrapper {
        Manually_Email_Setting__mdt custMetaWrapper;
        Set<String> keySetWrapper;
    }
}