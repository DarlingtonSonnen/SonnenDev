/*
 /* Created by b.jarmolinski on 01/08/2018
*
* Version 2.1 by Bartosz on 23/01/2019
*   - added if (objs.size() > 0) {...} and if (syncs.size() > 0) {...} to prevent insert and calling another method if the arrays are empty
*
* Version 2.0 by Bartosz on 14/12/2018
*   - added method quoteCount - the method creates a new case if second or further zqu__Quote__c is created under the same contract.
*
* Version 1.3 by Bartosz on 23/11/2018
*   - reverted back to non-queueable - causes problems if multiple records updated right after another - hitting number of queueable jobs > 1 limit
*   - implemented error logging to zuoraSync object if governance limits are hit
*
* Version 1.2 by Bartosz on 25/10/2018
*   - adjusted to work with new version of zuoraCreatePaymentMethod (queueable) - bulkified process
*
* Version 1.1
    - Added 00D24000000opicEAA as org ID - previously only 15 digit ID was included
 */

public class zQuoteTriggerHandler extends TriggerHandler {

    public override void afterInsert() {
        //sendQuotes(); // for automatic quote send to zuora
        quoteCount();
    }

    public override void beforeUpdate() {
        createSEPA();
    }
    public override void afterUpdate() {

    }

    private void createSEPA() {
        // the method creates payment method at zuora

        // custom metadata settings
        zuoraSetting__mdt settings;
        // 00D24000000opic AND 00D24000000opicEAA are org Id of sonnen  Live org / production
        if(UserInfo.getOrganizationId() != '00D24000000opic' && UserInfo.getOrganizationId() != '00D24000000opicEAA') {
            settings = [SELECT TriggerSwitchCreatePayment__c, baseUrl__c FROM zuoraSetting__mdt WHERE Label = 'Sandbox'];
        } else {
            settings = [SELECT TriggerSwitchCreatePayment__c, baseUrl__c FROM zuoraSetting__mdt WHERE Label = 'Prod'];
        }

        if (settings.TriggerSwitchCreatePayment__c || Test.isRunningTest()) {
            // makes callout to zuora, creates SEPA payment method, marks the method as default
            Map<Id, zqu__Quote__c> oldMap = (Map<Id, zqu__Quote__c>) Trigger.oldMap;
            Map<Id, zqu__Quote__c> newMap = (Map<Id, zqu__Quote__c>) Trigger.newMap;

            // is it possible that multiple contacts will be filled in with a confirmed delivery start?
            // if so, the zuoraCreatePaymentMethod must be queueable

            Map<Id, zqu__Quote__c> newMapExtended = new Map<Id, zqu__Quote__c>([SELECT Id, zqu__BillToContact__r.FirstName, zqu__BillToContact__r.LastName,
                    zqu__BillToContact__r.Email, zqu__BillToContact__r.MailingCountryCode,
                    zqu__Opportunity__r.OrderSource__c, Contract__r.BankData__c
            FROM zqu__Quote__c WHERE Id IN:newMap.keySet()]);

            Set<String> contractSet = new Set<String>();
            for (zqu__Quote__c q : newMapExtended.values()) {
                contractSet.add(q.Contract__r.BankData__c);
            }

            Map<Id, BankData__c> contractBankData = new Map<Id, BankData__c>(); // contract Id as key, bank data as value
            Map<Id, BankData__c> BankDataMap = new Map<Id, BankData__c>([SELECT Id, IBAN__c, IBANCheckResult__c,  SepaReference__c, SepaDate__c	, Name
            FROM BankData__c WHERE Id IN:contractSet]);

            for (zqu__Quote__c q : newMapExtended.values()) {
                contractBankData.put(q.Contract__c, BankDataMap.get(q.Contract__r.BankData__c));
            }
            System.debug('BankDataMap: '+BankDataMap);

            //***
            List<zuoraCreatePaymentMethod.newPaymentObject> objs = new List<zuoraCreatePaymentMethod.newPaymentObject>();
            //***
            List<zuoraSync__c> syncs = new List<zuoraSync__c>();
            for (Id id : newMap.keySet()) {
                if (String.isBlank(oldMap.get(id).zqu__ZuoraSubscriptionID__c) && !String.isBlank(newMap.get(id).zqu__ZuoraSubscriptionID__c)) {

                    BankData__c bd = contractBankData.get(newMapExtended.get(id).Contract__c);

                    if (bd.IBANCheckResult__c == 'passed') {

                        zuoraCreatePaymentMethod.newPaymentObject obj = new zuoraCreatePaymentMethod.newPaymentObject();
                        obj.zAccountId = newMap.get(id).zqu__ZuoraAccountID__c;
                        obj.firstName = newMapExtended.get(id).zqu__BillToContact__r.FirstName;
                        obj.lastName = newMapExtended.get(id).zqu__BillToContact__r.LastName;
                        obj.iban = (String) bd.IBAN__c;
                        obj.country = newMapExtended.get(id).zqu__BillToContact__r.MailingCountryCode;
                        obj.email = newMapExtended.get(id).zqu__BillToContact__r.Email;
                        obj.mandateID = (String) bd.SepaReference__c;
                        obj.sepaDate = bd.SepaDate__c;
                        objs.add(obj);

                    } else {
                        System.debug('Error creating payment in zuora: bank data check result is not \'passed\':' +bd.Name);

                        zuoraSync__c sync = new zuoraSync__c();
                        sync.Message__c = 'Creating of payment method in zuora failed. BankData: '+bd.Name+'. Subscription: '+newMap.get(id).Name;
                        sync.Process__c = 'Creation of payment methods';
                        syncs.add(sync);
                    }
                }
            }
            if (syncs.size() > 0) {
                insert syncs;
            }

            if (objs.size() > 0) {
                String jsonObject = JSON.serialize(objs);
                zuoraCreatePaymentMethod.createPaymentMethods( jsonObject, null, settings.baseUrl__c);
            }
        }
    }
    public void quoteCount() {

        // query zuora metadata settings
        zuoraSetting__mdt settings = ZuoraSettings.getZuoraSetting();

        if(settings.TriggerSwitch_CountQuotes__c || Test.isRunningTest()) {
            
            // count quotes under specific contract
            // create case if there is more than 1
            List<zqu__Quote__c> quotes = (List<zqu__Quote__c>) Trigger.new;
            //List<zqu__Quote__c> quotes = [SELECT Id, Contract__c FROM zqu__Quote__c WHERE Id != null AND Contract__c != null];
            Set<Id> contractsIds = new Set<Id>();

            for (zqu__Quote__c q : quotes) {
                if(!String.isBlank(q.Contract__c)) {
                    contractsIds.add(q.Contract__c);
                }
            }

            // query contracts to get data needed for creation of case eService Intern
            Map<Id, Contract> contractsMap = new Map<Id, Contract>([SELECT Id, AccountId, CustomerSignedId, Account.PrimaryContact__c
            FROM Contract WHERE Id IN: contractsIds]);

            // aggregate query to see how many zQuotes per contracts
            Map<Id, AggregateResult> quoteCountMap = new Map<Id, AggregateResult>([SELECT Contract__c Id, Count(Id) qCount FROM zqu__Quote__c
            WHERE Contract__c IN :contractsIds AND Id != null AND Contract__c != null
            GROUP BY Contract__c]);

            List<Case> cases = new List<Case>();

            for (Id id : quoteCountMap.keySet()) {
                if ( (Integer) quoteCountMap.get(id).get('qCount') > 1) {
                    // create case
                    System.debug(id + ' ' + quoteCountMap.get(id) );
                    Case c = new Case();
                    c.Subject = 'There are multiple zuora quotes under this contract: '+ id;
                    c.Description = 'There are multiple zuora quotes under the contract related to this case. Check if this is relevant';
                    c.Contract__c = id;
                    c.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('eServicesIntern').getRecordTypeId();
                    c.AccountId = contractsMap.get(id).AccountId;
                    if (contractsMap.get(id).CustomerSignedId != null) {
                        c.ContactId = contractsMap.get(id).CustomerSignedId;
                    } else {
                        c.ContactId = contractsMap.get(id).Account.PrimaryContact__c;
                    }
                    c.Type = 'Request';
                    c.Origin = 'Internal';
                    c.Category__c = 'zuora';
                    c.OwnerId = settings.CaseOwnerId__c;
                    cases.add(c);
                }
            }
            try {
                insert cases;
            } catch (Exception e) {
                System.debug(e.getMessage());
            }
        }
    }

//    private void sendQuotes() {
//        // send quote auotmatically to zuora - invokes ZuoraQuoteGenerator_CalloutHandler class which uses zuora package util class
//
//        // custom metadata settings to check if trigger is active
//        zuoraSetting__mdt settings;
//        // 00D24000000opic AND 00D24000000opicEAA are org Id of sonnen  Live org / production
//        if(UserInfo.getOrganizationId() != '00D24000000opic' && UserInfo.getOrganizationId() != '00D24000000opicEAA') {
//            settings = [SELECT TriggerSwitchAutoSendQuote__c FROM zuoraSetting__mdt WHERE Label = 'Sandbox'];
//        } else {
//            settings = [SELECT TriggerSwitchAutoSendQuote__c FROM zuoraSetting__mdt WHERE Label = 'Prod'];
//        }
//
//        if (settings.TriggerSwitchAutoSendQuote__c) {
//            List<zqu__Quote__c> quotes = (List<zqu__Quote__c>) Trigger.new;
//            ZuoraQuoteGenerator_CalloutHandler handler = new ZuoraQuoteGenerator_CalloutHandler(quotes);
//            System.enqueueJob(handler);
//        }
//    }
}