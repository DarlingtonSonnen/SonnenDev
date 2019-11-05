/**
 * Created by b.jarmolinski on 31/07/2018.
 * Test coverage: zuoraCreatePaymentMethod_Test
 *
 * The class creates Payment method in zuora
 * This should happen anytime a new subscription is created and if bank data change on a contract
 *
 * The class may be changed to queueable to ensure callouts limits are not reached - reaching the limits is unlikely though
 *
 * CreatePaymentMethod(future) - is a method to be called from quote trigger when a new subscription is created in zuora and synced back to salesforce (subscription Id will then get populated on the quote)
 * CreatePaymentMethod - is called from other methods in the class - does the callout to zuora to create the new payment method
 * sendWarning - sends warning email (internally) if a callout failed
 * updateZuoraPayment(List<Contract> contracts) - invocable - method invoked from process builder if bank data changes on contract (process builder because there are many pending jobs on the trigger Contract and deployment of the changes is delayed - maybe switched to trigger in the future)
 * authZuora - makes authentification callout to zuora, return access token
 *
 * CHANGES
 *
 * 23/11/2018 - Version 3.0 by Bartosz
 *  - reverted back to non-queueable - causes problems if multiple records updated right after another - hitting number of queueable jobs > 1 limit
 *  - implemented error logging to zuoraSync object if governance limits are hit
 *
 * 25/10/2018 - Version 2.0
 * - implements queueable interface to avoid hitting limits on queries and callouts if there are multiple
 * - added method updateZuoraPayment, which is to be called when BankData changes on contract
 *
 * 17/10/2018 - by Bartosz
 * - added check for bank data - send to zuora only if the IBAN Check result is passed.
 *
 */

public without sharing class zuoraCreatePaymentMethod {

    @future (callout=true)
    public static void createPaymentMethods(String jsonObject, String accessToken, String baseUrl) {

        List<newPaymentObject> newPaymentObjects = (List<newPaymentObject>) JSON.deserialize(jsonObject, List<newPaymentObject>.class );

        System.debug(newPaymentObjects);

        // get zuora access token if a null values has been passed to the constructor
        String token;
        if (accessToken != null) {
            token = accessToken;
        } else {
            HttpResponse res = zuoraLogin.loginZuora();
            Map<String, Object> jsonRes = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            token = (String) jsonRes.get('access_token');
        }

        List<zuoraSync__c> syncs = new List<zuoraSync__c>();
        List<newPaymentObject> remainderList = new List<newPaymentObject>();
        while(newPaymentObjects.size() > 0) {
            newPaymentObject obj = newPaymentObjects.remove(0);

            if (Limits.getLimitCallouts() > (Limits.getCallouts() + 1)  && Limits.getLimitQueries() > (Limits.getQueries() + 1)) {
                // check limits in the context against the actual usage
                // +1 because there are two callouts within the if context

                // call method to create new payment method
                HttpResponse res1 = newPaymentMethod(obj, token, baseUrl);

                // extract zuora payment Id from the response and use for marking the method as default
                System.debug(res1);
                Map<String, Object> res1Map = (Map<String, Object>) JSON.deserializeUntyped(res1.getBody());
                System.debug(res1Map);

                String paymentMethodId = (String) res1map.get('Id');

                // create zuoraSync record
                zuoraSync__c sync = new zuoraSync__c();
                sync.HttpRequest__c = JSON.serialize(obj);
                sync.HttpResponse__c = res1.getBody();
                sync.Process__c = 'creation payment method';
                sync.ResponseCode__c = String.valueOf(res1.getStatusCode());
                syncs.add(sync);

                // mark the method as default for the account
                HttpResponse res2 = markDefault(paymentMethodId, baseUrl, obj.zAccountId, token);
                System.debug(res2.getBody());

                zuoraSync__c sync2 = new zuoraSync__c();
                sync2.HttpRequest__c = 'paymentMethodId='+paymentMethodId+'; objzAccountId='+obj.zAccountId;
                sync2.HttpResponse__c = res2.getBody();
                sync2.Process__c = 'creation payment method';
                sync2.ResponseCode__c = String.valueOf(res2.getStatusCode());
                syncs.add(sync2);

            } else {
                remainderList.add(obj);
            }
        }
        insert syncs;
        if (remainderList.size() > 0) {
//            zuoraCreatePaymentMethod que2 = new zuoraCreatePaymentMethod(remainderList, token, baseUrl);
////            System.enqueueJob(que2);
            zuoraSync__c sync = new zuoraSync__c();
            sync.Message__c = 'Creation of payment method failed due to hitting governance limits. The list of failed records: \n' + remainderList;
            sync.Process__c = 'Creation of payment methods';
            insert sync;
        }
    }

    private static HttpResponse newPaymentMethod(newPaymentObject obj, String token, String baseUrl) {

        System.debug(obj);
        // *** create body of the create payment request
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeStringField('AccountId', obj.zAccountId);
        gen.writeStringField('BankTransferAccountName', obj.firstName + ' ' + obj.lastName);
        gen.writeStringField('BankTransferAccountNumber', obj.iban);
        gen.writeStringField('BankTransferType', 'SEPA');
        gen.writeStringField('Country', obj.country);
        gen.writeStringField('FirstName', obj.firstName);
        gen.writeStringField('LastName', obj.lastName);
        gen.writeStringField('Email', obj.email);
        gen.writeStringField('Type', 'BankTransfer');
        gen.writeStringField('MandateID', obj.mandateId);
        gen.writeStringField('MandateCreationDate', String.valueOf(obj.sepaDate));
        gen.writeStringField('MandateReceived', 'Yes');
        gen.writeStringField('ExistingMandate', 'Yes');
        gen.writeEndObject();

        String jsonBody = gen.getAsString();

        // ****actual call to create the payment method
        Http h1 = new Http();
        HttpRequest req1 = new HttpRequest();
        req1.setEndpoint(baseUrl + '/v1/object/payment-method');
        req1.setMethod('POST');
        req1.setHeader('Authorization', 'Bearer ' + token);
        req1.setHeader('Content-Type', 'application/json');
        req1.setBody(jsonBody);

        HttpResponse res1 = new HttpResponse();

        if (Test.isRunningTest()) {
            String strRes1 = '{ "Success": true, "Id": "8adc8f9964ea660b0164f05ad3f97276" }';
            SingleRequestMock mockRes1 = new SingleRequestMock(200, 'Completed', strRes1, null);
            res1 = mockRes1.respond(req1);
        } else {
            res1 = h1.send(req1);
        }
        return res1;
    }

    private static HttpResponse markDefault(String paymentMethodId, String baseUrl, String zAccountId, String token) {
        // makes call to zuora to mark a payment method as default

        JSONGenerator gen2 = JSON.createGenerator(true);
        gen2.writeStartObject();
        gen2.writeBooleanField('AutoPay', true);
        gen2.writeStringField('DefaultPaymentMethodId', paymentMethodId);
        gen2.writeEndObject();

        String req2Body = gen2.getAsString();

        Http h2 = new Http();
        HttpRequest req2 = new HttpRequest();
        req2.setEndpoint(baseUrl + '/v1/object/account/'+ zAccountId);
        req2.setHeader('Authorization', 'Bearer '+ token);
        req2.setHeader('Content-Type', 'application/json');
        req2.setMethod('PUT');
        req2.setBody(req2Body);

        HttpResponse res2 = new HttpResponse();
        if (Test.isRunningTest()) {
            String str2Res = '{ "Success": true, "Id": "8adce4216342dced01634f18c10045b3" }';
            SingleRequestMock mockRes2 = new SingleRequestMock(200, 'Completed', str2Res, null);
            res2 = mockRes2.respond(req2);
        } else {
            res2 = h2.send(req2);
        }

        return res2;
    }

    @invocableMethod
    public static void updateZuoraPayment(List<Contract> contracts) {

        // check if those contracts have zuoraQuotes with subscriptions
        Set<Id> contractIDs = new Set<Id>();
        for (Contract c : contracts) {
            contractIDs.add(c.Id);
        }
        System.debug(contractIDs);
        //find custom metadata settings
        ZuoraSetting__mdt settings = ZuoraSettings.getZuoraSetting();

        // find all necessary data to change the payment method - from zQuote, as only contracts with zuora quotes matter
        List<zqu__Quote__c> quotes = [SELECT Id, zqu__ZuoraAccountID__c, Contract__r.BankData__r.FirstName__c, Contract__r.BankData__r.LastName__c,
                zqu__BillToContact__r.MailingCountryCode, zqu__BillToContact__r.Email, zqu__Number__c,
                Contract__r.BankData__r.IBAN__c, Contract__r.BankData__r.SepaReference__c, Contract__r.BankData__r.SepaDate__c,
                Contract__r.BankData__r.IBANCheckResult__c
                FROM zqu__Quote__c WHERE Contract__c IN :contractIDs AND zqu__Status__c = 'Sent to Z-Billing'];

        if (quotes.size() > 0) {
            System.debug(quotes[0].Contract__r.BankData__r.FirstName__c);
        }

        // find the new account IDs;
        // because those on the quote may not be valid any more causing problem on zuora side
        Set<String> quoteNumbers = new Set<String>();
        for (zqu__Quote__c q : quotes) {
            quoteNumbers.add(q.zqu__Number__c);
        }

        List<Zuora__Subscription__c> subscriptions = [SELECT Zuora__QuoteNumber__c, Zuora__CustomerAccount__r.Zuora__Zuora_Id__c FROM Zuora__Subscription__c WHERE Zuora__QuoteNumber__c IN :quoteNumbers];
        Map<String, String> newAccountIdMap = new Map<String, String>();
        for (Zuora__Subscription__c s : subscriptions) {
            newAccountIdMap.put(s.Zuora__QuoteNumber__c, s.Zuora__CustomerAccount__r.Zuora__Zuora_Id__c);
        }
        System.debug(subscriptions);
        System.debug(newAccountIdMap);
        // create map where zAccountId is a key, and payment update wrapper is a value - to make sure there is only one request per zuora account
        List<newPaymentObject> objs = new List<newPaymentObject>();
        Map<String, newPaymentObject> updateMap = new Map<String, newPaymentObject>();

        for (zqu__Quote__c q : quotes) {

            // process further only records where the respective bank data status is passed (positively went through IBAN check)
            String newAccountId = newAccountIdMap.get(q.zqu__Number__c);
            System.debug(newAccountId);

            if (!updateMap.keySet().contains(newAccountId) && !String.isBlank(newAccountId)
                    && q.Contract__r.BankData__r.IBANCheckResult__c == 'passed') {

                System.debug(q.Contract__r.BankData__r.FirstName__c);

                newPaymentObject newValue = new newPaymentObject();
                newValue.firstName = q.Contract__r.BankData__r.FirstName__c;
                newValue.lastName = q.Contract__r.BankData__r.lastName__c;
                //newValue.zAccountId = q.zqu__ZuoraAccountID__c;
                newValue.zAccountId = newAccountId;
                newValue.iban = q.Contract__r.BankData__r.IBAN__c;
                newValue.mandateID = q.Contract__r.BankData__r.SepaReference__c;
                newValue.sepaDate = q.Contract__r.BankData__r.SepaDate__c;
                newValue.country = q.zqu__BillToContact__r.MailingCountryCode;
                newValue.email = q.zqu__BillToContact__r.Email;

                updateMap.put(q.zqu__ZuoraAccountID__c, newValue);
                objs.add(newValue);
            }
        }
        System.debug(objs);

        if (objs.size() > 0) {
            String jsonObject = JSON.serialize(objs);
            createPaymentMethods(jsonObject, null, settings.baseUrl__c);
        }
    }

    public class newPaymentObject {
        // wrapper class for parameters to create payment method
        public String zAccountId;
        public String firstName;
        public String lastName;
        public String iban;
        public String country;
        public String email;
        public String mandateID;
        public Date sepaDate;
    }
}