/**
 * Created by b.jarmolinski on 25/09/2018.
 * The class sends emails related to contract
 * 1. on the day of confirmed delivery start, informing the client that the delivery begins on the day (scheduled)
 * 2. on the day when confirmed delivery date is filled in (getting contracts from a trigger/process)
 *
 * Version 1.2 on 28/11/2018 by Bartosz
 * Added condition Tariff_Version__c != 'sFh 2.1' not the send emails to that group
 *
 * Version 1.1 on 20/11/2018 by Bartosz
 * Added filter on Financial Service Provider = zuora
 * Removed constructor, moved contract finding to execute class.
 */

public with sharing class ContractEmails_Schedulable implements Schedulable{

    private List<Contract> contracts;
    private String operation; // values: startSupply or deliveryDate

    public void execute(SchedulableContext sc) {
        // find contracts whose delivery start date is today and send email informing about it
        // add check if there is already an email sent to the client

        this.contracts = [SELECT Id, ConfirmedDeliveryStart__c, TariffType__c, Type__c, RecordTypeId, Tariff_Version__c,
                            CustomerSignedId, CustomerSigned.Email, RecordType.DeveloperName, Account.BillingCountryCode,
                            FinancialServiceProvider__c
                            FROM Contract WHERE ConfirmedDeliveryStart__c = :Date.today() AND Tariff_Version__c != 'sFh 2.1'];

        System.debug(Datetime.now());

        System.debug(contracts.size());
        this.operation = 'startSupply';

        sendEmails(this.contracts, this.operation);
    }


    @InvocableMethod
    public static void sendDeliveryDateEmails(List<Contract> contracts) {
        // method to be used by trigger / process builder when confirmed delivery date gets filled in
        Set<Id> contractSet = new Set<Id>();
        for (Contract c : contracts) {
            contractSet.add(c.Id);
        }
        List<Contract> contractsExtended = [SELECT Id, ConfirmedDeliveryStart__c, TariffType__c, Type__c, RecordTypeId, Tariff_Version__c,
                                            CustomerSignedId, CustomerSigned.Email, RecordType.DeveloperName, Account.BillingCountryCode,
                                            FinancialServiceProvider__c
                                            FROM Contract WHERE Id IN:contractSet ];

        String operation = 'deliveryDate';
        sendEmails(contractsExtended, operation);
    }

    public static ContractEmailSetting__mdt getSettings() {
        // the method queries and returns all fields within the ContractEmailSetting__mdt custom metadata type

        SObjectType baType = Schema.getGlobalDescribe().get('ContractEmailSetting__mdt');
        Map<String,Schema.SObjectField> mfields = baType.getDescribe().fields.getMap();

        // create a list of all fields in the ContractEmailSetting__mdt
        List<String> sList = new List<String>();
        for (Schema.SObjectField s : mfields.values()) {
            sList.add(s.getDescribe().getName());
        }

        // create a string for SOQL query by concatenating field names
        String queryString;
        for (Integer i=0; i < sList.size(); i++) {
            if (i == 0) {
                queryString = sList[0] + ', ';
            } else if (i < sList.size() - 1) {
                queryString = queryString + sList[i] + ', ';
            } else {
                queryString = queryString + sList[i] + ' ';
            }
        }
        queryString = 'SELECT ' + queryString + 'FROM ContractEmailSetting__mdt LIMIT 1';
        ContractEmailSetting__mdt settings = Database.query(queryString);

        return settings;
    }

    public static void sendEmails(List<Contract> contracts, String operation) {
        // the method sends respective email - based on the operation parameter it is
        ContractEmailSetting__mdt settings = getSettings();

        // identify countries
        List<String> countryList = settings.CountryCodes__c.split(';');

        System.debug(contracts.size());

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        if (contracts.size() > 0 ) {

            for (Contract c : contracts) {

                if (countryList.contains(c.Account.BillingCountryCode) && c.FinancialServiceProvider__c == 'Zuora' ) {

                    // identify template
                    String template;
                    if (c.RecordType.DeveloperName.toLowerCase().contains('sonnenstrom')) {
                        if (operation == 'startSupply') {
                            template = (String) settings.get(c.RecordType.DeveloperName + c.Type__c + '_SupplyStart__c');
                        } else if (operation == 'deliveryDate') {
                            template = (String) settings.get(c.RecordType.DeveloperName + c.Type__c + '_Delivery__c');
                        }
                    } else if (c.RecordType.DeveloperName.toLowerCase().contains('sonnenflat')) {
                        if (operation == 'startSupply') {
                            template = (String) settings.get('sonnenFlat_SupplyStart__c');
                        } else if (operation == 'deliveryDate') {
                            template = (String) settings.get('sonnenFlat_Delivery__c');
                        }
                    }
                    System.debug(template);
                    System.debug(c.CustomerSignedId);

                    List<String> toAddresses = new List<String>{c.CustomerSigned.Email};

                    Messaging.SingleEmailMessage sem = new Messaging.SingleEmailMessage();
                    sem.setOrgWideEmailAddressId(settings.SendFromId__c);
                    sem.setToAddresses(toAddresses);
                    sem.setTargetObjectId(c.CustomerSignedId); // mandatory field
                    sem.setTreatTargetObjectAsRecipient(false); // prevent sending the copy of email to the targetId user
                    sem.setTemplateId(template);
                    sem.setWhatId(c.Id);
                    sem.setSaveAsActivity(true);

                    emails.add(sem);
                }
            }

            List<Messaging.SendEmailResult> result = Messaging.sendEmail(emails, false);
            System.debug(result);
            List<Log__c> failedList = new List<Log__c>();
            for (Messaging.SendEmailResult res : result) {
                if (res.isSuccess() == false) {
                    Log__c log = new Log__c();
                    log.Timestamp__c = Datetime.now();
                    log.Message__c = res.getErrors()[0].getMessage();
                    failedList.add(log);
                }
            }
            if (failedList.size() > 0) {
                insert failedList;
            }
        }
    }
}