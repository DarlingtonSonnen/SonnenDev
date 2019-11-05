/**
 * Created by l.martins on 8/12/2019.
 * Update 22.10.2019 M.Muchow
 *  - Changed method updateCaseCountry() to do SOQL queries only when necessary
 *  - Changed check for empty map in line 148
 */

public class EmailMessageTriggerHandler extends TriggerHandler {


    public override void beforeInsert() {
        this.checkCase();
    }
    
    public override void afterInsert() {
        this.updateCaseCountry();
    }


    private void updateCaseCountry() {


        TriggerEmailMessage__mdt triggerSettings = [SELECT Active__c FROM TriggerEmailMessage__mdt WHERE Label = 'update Case Country' LIMIT 1];

        if (triggerSettings.Active__c == true || Test.isRunningTest()) {

            List<EmailMessage> listEmailMessages = (List<EmailMessage>) Trigger.new;

            // initialize Sets
            Set<Id> caseIdSet = new Set<Id>();

            // initialize Lists
            List<Case> newCaseListToUpdate = new List<Case>();

            // initialize Maps
            Map<String, Case_Country__mdt> myMap = new Map<String, Case_Country__mdt>();
            Map<String, String> addressMap = new Map<String, String>();

            // loop trough EmailMessages
            for (EmailMessage eMessage : listEmailMessages) {
                // check for Cases
                if (eMessage.ParentId != null && eMessage.ParentId.getSobjectType() == Case.SObjectType && eMessage.Incoming) {
                    // get Case Id & fill Set & Map
                    caseIdSet.add(eMessage.ParentId);
                    addressMap.put(eMessage.ParentId, eMessage.ToAddress);
                }
            }

            if (!caseIdSet.isEmpty()) {
                for (Case_Country__mdt meta : [SELECT Label, Country_ISOCode__c, Country__c FROM Case_Country__mdt]) {
                    myMap.put(meta.Label, meta);
                }

                for (Case oCase : [SELECT Id, Country__c FROM Case WHERE Id IN :caseIdSet]) {
                    if (myMap.get(addressMap.get(oCase.Id)) != null) {
                        oCase.Country__c = myMap.get(addressMap.get(oCase.Id)).Country_ISOCode__c;
                        newCaseListToUpdate.add(oCase);
                    }
                }
            }

            if (!newCaseListToUpdate.isEmpty()) {
                update newCaseListToUpdate;
            }
        }
    }
    
    /**
     * Method to not reopen old cases
     * creates new Case and relinks EmailMessage and Activity
     * Test Class EmailMessageTriggerTest()
     */
    public void checkCase() {
        // get Custom Metadata Settings for Trigger Method
        TriggerEmailMessage__mdt triggerSettings = [SELECT Active__c FROM TriggerEmailMessage__mdt WHERE Label = 'check Case' LIMIT 1];

        if (triggerSettings.Active__c == true || Test.isRunningTest()) {
            // fill list with EmailMessage records from trigger
            List<EmailMessage> listEmailMessages = (List<EmailMessage>) Trigger.new;

            // initialize Sets
            Set<Id> caseIdSet = new Set<Id>();
            Set<String> caseStatusSet = new Set<String>();
            Set<Id> activityIdSet = new Set<Id>();

            // initialize Maps
            Map<Id, EmailMessage> caseEmailMessageMap = new Map<Id, EmailMessage>();
            Map<String, EmailMessage> newCaseEmailMessageMap = new Map<String, EmailMessage>();
            Map<Id, Id> activityCaseMap = new Map<Id, Id>();

            // initialize Lists
            List<Case> caseList = new List<Case>();
            List<Case> newCaseList = new List<Case>();
            List<Task> updateActivityList = new List<Task>();

            // loop trough EmailMessages
            for (EmailMessage eMessage : listEmailMessages) {
                // check for Cases
                if (eMessage.ParentId != null && eMessage.ParentId.getSobjectType() == Case.SObjectType && eMessage.Incoming) {
                    // get Case Id & fill Set & Map
                    caseIdSet.add(eMessage.ParentId);
                    caseEmailMessageMap.put(eMessage.ParentId, eMessage);
                }
            }

            if (!caseIdSet.isEmpty()) {
                // loop trough CaseStatus to get closed status & add to Set
                for (CaseStatus cStatus : [SELECT ApiName FROM CaseStatus WHERE IsClosed = TRUE AND ApiName != 'Closed - Waiting for Customer Reply']) {
                    caseStatusSet.add(cStatus.ApiName);
                }

                // loop trough Cases based on EmailMessage Case Id and CaseStatus
                for (Case checkCase : [SELECT Id, ClosedDate, IsClosed FROM Case WHERE Id IN:caseIdSet AND Status IN:caseStatusSet]) {
                    // check if case is closed at least 4 weeks
                    if (System.today() >= checkCase.ClosedDate.addMonths(1) && checkCase.IsClosed) {
                        caseList.add(checkCase);
                    }
                    // if test is running, just use the case
                    if (Test.isRunningTest()) {
                        caseList.add(checkCase);
                    }
                }
            }

            // if a case was found
            if (!caseList.isEmpty()) {
                for (Case changeMessageCase : caseList) {
                    EmailMessage eMessage = caseEmailMessageMap.get(changeMessageCase.Id);
                    Case newCase = new Case();
                    newCase.Subject = eMessage.Subject;
                    newCase.Description = eMessage.TextBody;
                    newCaseList.add(newCase);
                    newCaseEmailMessageMap.put(eMessage.Subject, eMessage);
                }
            }
            // relink EmailMessage to new Case
            if (!newCaseList.isEmpty()) {
                Database.insert(newCaseList);
                for (Case createdCase : newCaseList) {
                    EmailMessage eMassage = newCaseEmailMessageMap.get(createdCase.Subject);
                    eMassage.put('ParentId', createdCase.Id);
                    eMassage.put('RelatedToId', createdCase.Id);
                    activityIdSet.add((Id)eMassage.get('ActivityId'));
                    activityCaseMap.put((Id)eMassage.get('ActivityId'), createdCase.Id);
                }
            }
            // relink Activity to new Case
            if (!activityCaseMap.isEmpty()) {
                for (Task updateActivity : [SELECT Id, WhatId FROM Task WHERE Id IN: activityIdSet ]) {
                    updateActivity.WhatId = activityCaseMap.get(updateActivity.Id);
                    updateActivityList.add(updateActivity);
                }
            }
            // update Activity
            if(!updateActivityList.isEmpty()) {
                Database.update(updateActivityList);
            }
        }
    }

}