/**
 * Created by b.jarmolinski on 18/09/2018.
 *
 * The class contains sync features with zuora: sending amendments to zuora if bonus is added to contract and/or if 'Regular prepayment' changes.
 *
 * Version 2.0 on 03/01/2019 by Bartosz
 * - Added 'if(a.Zuora__Subscriptions__r.size() > 0)' - to avoid error if bonus is added to non-zuora contract
 *
 * Version 2.1 on 16/01/2019 by Bartosz
 * - added 'if (aExtended.Zuora__Subscriptions__r.size() > 0)' to prevent adding amendments for contracts without zuora subscriptions
 * - added 'if (this.amendmentObjects.size() > 0)' not to execute the script if no zuoraAmendmentObject have been created in contructor
 *
 * Version 2.2 on 24/01/2019 by Bartosz
 * - added kWhPrice when calculating electricity bonus
 */

public with sharing class zuoraIntegrationV2 implements Queueable, Database.AllowsCallouts {

    private List<Contract> contracts; // received from trigger
    private Map<Id, Contract> contractMap; // map created from triggered contracts
    private Map<Id, Contract> contractMapExtended; // map of the triggered contracts with additional infos
    private String operation; // parameter to distinguish amendments
    private zuoraSetting__mdt settings;

    private List<ZuoraAmendmentObject> amendmentObjects; // map of sObject which are to be integrated with zuora


    // constructor accepting contracts for processing changes in regular prepayments (Abschlag)
    public zuoraIntegrationV2(List<Contract> contracts, String operation) {
        this.contracts = contracts;
        this.contractMap = new Map<Id, Contract>(contracts);
        this.operation = operation;

        // get account ID as a set and query accounts in order to get the most recent subscription under the account
        Set<Id> accounts = new Set<Id>();
        for (Contract c : contracts) {
            accounts.add(c.AccountId);
        }

        Map<Id, Account> accountMapExtended = new Map<Id, Account>([
                SELECT Id,
                (SELECT Id, Zuora__Zuora_Id__c FROM Zuora__Subscriptions__r ORDER BY Name DESC LIMIT 1)
                FROM Account WHERE ID IN:accounts
        ]);

        this.amendmentObjects = new List<ZuoraAmendmentObject>();
        // create amendment object for each contract - this object will be used further in processing and callout creation
        for (Contract c : contracts) {

            // get account from the map using contract's accountId - this way access to subscription ID queries in nested query above
            Account aExtended = accountMapExtended.get(c.AccountId);
            System.debug(c.AccountId);
            System.debug(aExtended);
            if (aExtended.Zuora__Subscriptions__r.size() > 0) {
                ZuoraAmendmentObject zao = new ZuoraAmendmentObject(c, aExtended.Zuora__Subscriptions__r[0].Zuora__Zuora_Id__c, operation);
                amendmentObjects.add(zao);
            }
        }
        System.debug(this.amendmentObjects);
    }

    // constructor for bonuses - creating amendments if bonus is added in salesforce
    public zuoraIntegrationV2(List<Bonus__c> bonuses) {

        Map<Id, Bonus__c> bonusMap = new Map<Id, Bonus__c>(bonuses);
        Map<Id, Bonus__c> bonusMapExtended = new Map<Id, Bonus__c>([
                SELECT Id, Contract__r.AccountId, CampaignId__r.Name, CampaignId__r.BonusNoOfMonths__c, CampaignId__r.BonusAmount__c,
                        Contract__r.AppointedEnergyRate__c
                FROM Bonus__c WHERE Id IN: bonusMap.keySet()
        ]);
        // loop through bonuses to get set of accounts they are linked to
        // -> the accounts IDs are needed to query for subscriptions where there is the zuora ID
        // -> zuora subscription ID is needed in an amendment call
        Set<Id> accounts = new Set<Id>();
        for (Bonus__c b : bonusMapExtended.values()) {
            accounts.add(b.Contract__r.AccountId);
        }

        Map<Id, Account> accountSubscriptionsMap = new Map<Id, Account> ( [SELECT Id,
        (SELECT Id, Zuora__Zuora_Id__c FROM Zuora__Subscriptions__r ORDER BY Name DESC LIMIT 1)
        FROM Account WHERE ID IN:accounts]);

        // created list of zuoraAmendmentObjects for the list of bonuses
        this.amendmentObjects = new List<ZuoraAmendmentObject>();

        for (Bonus__c b : bonuses) {

            Id accountId = bonusMapExtended.get(b.Id).Contract__r.AccountId;
            Account a = accountSubscriptionsMap.get(accountId);
            System.debug(a);

            if(a.Zuora__Subscriptions__r.size() > 0) {

                String subscriptionId = a.Zuora__Subscriptions__r[0].Zuora__Zuora_Id__c;
                System.debug(a.Zuora__Subscriptions__r[0]);
                Bonus__c bonusExtended = bonusMapExtended.get(b.Id);

                ZuoraAmendmentObject zao = new ZuoraAmendmentObject(b, subscriptionId, bonusExtended.CampaignId__r.Name, bonusExtended.CampaignId__r.BonusNoOfMonths__c,
                                                                    bonusExtended.CampaignId__r.BonusAmount__c, bonusExtended.Contract__r.AppointedEnergyRate__c );
                amendmentObjects.add(zao);

            }
        }
        System.debug(this.amendmentObjects);

    }

    // constructor accepting List of ZuoraAmendmentObjects if - for the re-queued situation
    public zuoraIntegrationV2(List<ZuoraAmendmentObject> objects) {
        this.amendmentObjects = objects;
    }

    public void execute(QueueableContext context) {
        // get metadata settings
        //querySettings();
        this.settings = ZuoraSettings.getZuoraSetting();
        if (this.amendmentObjects.size() > 0) {
            sendToZuora(this.settings, this.amendmentObjects);
        }
    }

    private static void sendToZuora(zuoraSetting__mdt settings, List<ZuoraAmendmentObject> amendmentObjects) {

        String accessToken; // Bearer token to be received from zuora and used then in amendment calls

        // create body for authentification call
        String body = 'client_id='+settings.client_id__c+'&client_secret='+settings.client_secret__c+'&grant_type=client_credentials';

        // authentification call
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.url__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        // add if test logic
        HttpResponse res = new HttpResponse();

        if (Test.isRunningTest())  {

            String testbody = '{ "access_token": "3e0ed11c851543ce823e645af68ec787", "token_type": "bearer", "expires_in": 3598, "scope": "entity.8adc8f99-5f6b-4342-015f-6ecadc321ab5 platform.write service.usage.delete service.usage.update service.usage.write tenant.2000125 user.8adce42161c1652f0161e24e376a56f6", "jti": "3e0ed11c851543ce823e645af68ec787" }';
            SingleRequestMock mockResponse = new SingleRequestMock(200, 'Completed', testbody, null);
            res = mockResponse.respond(req);

        } else {
            res = h.send(req);
        }


        Map<string, Object> jsonRes = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        accessToken = (String) jsonRes.get('access_token');

        System.debug(accessToken);
        // ** access token received

        // for each ZuoraAmendmentObject make an amendment call - respecting limits and requeue the class if the limit is reached
        // initialize a list of zuoraSync records where API reponses will be stored
        List<zuoraSync__c> zuoraAmend = new List<zuoraSync__c>();
        while (amendmentObjects.size() > 0) {
            // process only if within the limits
            // -1 because prepayment adjustments needs to make two calls
            // otherwise requeue the unprocessed records
            if(Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && Limits.getLimitCallouts() - 1 > Limits.getCallouts()) {

                ZuoraAmendmentObject zao = amendmentObjects.remove(0);
                System.debug(zao);
                String amendmentBody;

                if (zao.contract != null && zao.operation == 'prepayment') {
                    amendmentBody = amendPrepaymentBody(settings.BaseUrl__c, accessToken, zao);
                } else if (zao.bonus != null ) {
                    amendmentBody = bonusAmendmentBody(settings, zao);
                }

                HttpRequest req1 = new HttpRequest();
                req1.setEndpoint( settings.BaseUrl__c + '/v1/action/amend'); // need to be dynamic based on custom metadata
                req1.setMethod('POST');
                req1.setHeader('Content-Type', 'application/json');
                req1.setHeader('Authorization', 'Bearer '+accessToken);
                req1.setBody(amendmentBody);

                System.debug('req1 '+req1);

                Http h1 = new Http();
                HttpResponse res1 = new HttpResponse();

                if (Test.isRunningTest()) {
                    String testBody1= '{ "results": [ { "SubscriptionId": "8adc8f9965d230d40165ece21b981bec", "AmendmentIds": [ "8adc8f9965d230d40165ece21aed1bd0" ], "TotalDeltaMrr": 0, "Success": true } ] }';
                    SingleRequestMock mockResponse1 = new SingleRequestMock(200, 'Completed', testBody1, null);
                    res1 = mockResponse1.respond(req1);
                } else {
                    res1 = h1.send(req1);
                }

                System.debug(res1.getStatus());
                zuoraSync__c z = new zuoraSync__c();
                z.Name = 'zuora Bonus '+Datetime.now();
                z.HttpResponse__c = res1.getBody();
                z.ResponseCode__c = String.valueOf(res1.getStatusCode());
                z.Process__c = 'zuoraIntegrationV2';
                zuoraAmend.add(z);

            } else {
                // break reinitialize the class with zuoraAmendmentObjects which have not been processed yet
                break;
            }
        }
        insert zuoraAmend;
        // reinitialize and put the remaining zuora integration objects to the constructor.
        if (amendmentObjects.size() > 0) {
            zuoraIntegrationV2 q2 = new zuoraIntegrationV2(amendmentObjects);
            System.enqueueJob(q2);
        }
    }

    private static String amendPrepaymentBody(String baseUrl, String accessToken, ZuoraAmendmentObject zao) {

        String subsRatePlanChargeId;
        String prodRatePlanChargeId;

        // send GET request to zuora to get info about the subscription and its charges
        Http h = new Http();

        HttpRequest reqQuery = new HttpRequest();
        reqQuery.setEndpoint( baseUrl +  '/v1/subscriptions/' + zao.subscriptionId );
        reqQuery.setMethod('GET');
        reqQuery.setHeader('Content-Type', 'application/json');
        reqQuery.setHeader('Authorization', 'Bearer ' +accessToken);

        HttpResponse res = new HttpResponse();
        if (Test.isRunningTest()) {
            String body = '{ "success": true, "id": "8adc8f9965d230d40165ec8d40d10614", "accountId": "8adc8f996512644e0165135aa958105a", "accountNumber": "A00000084", "accountName": "Angus McGyver", "subscriptionNumber": "A-S00000154", "termType": "EVERGREEN", "invoiceSeparately": false, "contractEffectiveDate": "2018-03-18", "serviceActivationDate": "2018-08-06", "customerAcceptanceDate": "2018-09-01", "subscriptionStartDate": "2018-03-18", "termStartDate": "2018-03-18", "termEndDate": null, "initialTerm": null, "initialTermPeriodType": "Month", "currentTerm": null, "currentTermPeriodType": "Month", "autoRenew": false, "renewalSetting": "RENEW_WITH_SPECIFIC_TERM", "renewalTerm": null, "renewalTermPeriodType": "Month", "contractedMrr": 30.49, "totalContractedValue": null, "notes": null, "status": "Active", "dso_id__c": null, "QuoteNumber__QT": "Q001709", "QuoteBusinessType__QT": null, "SoldToCity__c": "Kempten", "OpportunityName__QT": "Web Order 07.08.2018 18:45:08 GMT", "CapacitySonnenBatteryKWh__c": "6.0", "SoldToStreet__c": "Ellharter Straße 9", "Jahresverbrauch__c": null, "market_location_id__c": null, "SoldToPostalCode__c": "87435", "amount_of_free_energy__c": null, "MinEnergyProduction__c": "7600", "SoldToCountry__c": "Germany", "OpportunityCloseDate__QT": "2018-09-06", "YearlyProduction__c": "5850", "metering_location_id__c": null, "CpqBundleJsonId__QT": null, "PVSize__c": null, "QuoteType__QT": "New Subscription", "ratePlans": [ { "id": "8adc8f9965d230d40165ec8d407d0609", "lastChangeType": "Update", "productId": "8adc8f996512644e0165146bee544a03", "productName": "sonnenFlat individual", "productSku": "SKU-00000016", "productRatePlanId": "8adc8f996512644e0165146bee714a05", "ratePlanName": "sonnenFlat individual", "ratePlanCharges": [ { "id": "8adc8f9965d230d40165ec8d410c0631", "originalChargeId": "8adc8f9965d230d40165e7ed39031590", "productRatePlanChargeId": "8adc8f996512644e0165146bef124a19", "number": "C-00001053", "name": "Geleistete Abschlagszahlungen", "type": "Usage", "model": "PerUnit", "uom": "ct.", "version": 1, "pricingSummary": "EUR-0.01/ct.", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": -0.01, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "ChargeTriggerDay", "listPriceBase": null, "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": null, "billingPeriodAlignment": "AlignToCharge", "quantity": null, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": "OnDemand", "segment": 1, "effectiveStartDate": "2018-08-06", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": false, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": null, "dmrc": null, "tcv": null, "dtcv": null, "description": "", "Type__c": "Paid-Pre-Payment" }, { "id": "8adc8f9965d230d40165ec8d40e70619", "originalChargeId": "8adc8f9965d230d40165e7ed38d7158a", "productRatePlanChargeId": "8adc8f996512644e0165146bee7d4a07", "number": "C-00001047", "name": "Community Fee", "type": "Recurring", "model": "FlatFee", "uom": null, "version": 1, "pricingSummary": "EUR19.99", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": 19.99, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "DefaultFromCustomer", "listPriceBase": "Per_Billing_Period", "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": "IN_ADVANCE", "billingPeriodAlignment": "AlignToCharge", "quantity": 1, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": null, "segment": 1, "effectiveStartDate": "2018-08-06", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": false, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": 19.99, "dmrc": 19.99, "tcv": null, "dtcv": null, "description": "", "Type__c": "None" }, { "id": "8adc8f9965d230d40165ec8d41020628", "originalChargeId": "8adc8f9965d230d40165e7ed38ee158d", "productRatePlanChargeId": "8adc8f996512644e0165146beec84a10", "number": "C-00001050", "name": "Abschlag", "type": "Recurring", "model": "FlatFee", "uom": null, "version": 3, "pricingSummary": "EUR10.5", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": 10.5, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "DefaultFromCustomer", "listPriceBase": "Per_Billing_Period", "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": "IN_ADVANCE", "billingPeriodAlignment": "AlignToCharge", "quantity": 1, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": null, "segment": 3, "effectiveStartDate": "2018-09-01", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": null, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": 10.5, "dmrc": -1, "tcv": null, "dtcv": null, "description": "", "Type__c": "Pre-Payment" }, { "id": "8adc8f9965d230d40165ec8d4105062b", "originalChargeId": "8adc8f9965d230d40165e7ed38f5158e", "productRatePlanChargeId": "8adc8f996512644e0165146beee04a13", "number": "C-00001051", "name": "Verbrauch nach 2.000 kWh", "type": "Usage", "model": "PerUnit", "uom": "kWh", "version": 1, "pricingSummary": "EUR0.259/kWh", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": 0.259, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "ChargeTriggerDay", "listPriceBase": null, "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": null, "billingPeriodAlignment": "AlignToCharge", "quantity": null, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": "OnDemand", "segment": 1, "effectiveStartDate": "2018-08-06", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": false, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": null, "dmrc": null, "tcv": null, "dtcv": null, "description": "", "Type__c": "Tier-Two-Usage" }, { "id": "8adc8f9965d230d40165ec8d4109062e", "originalChargeId": "8adc8f9965d230d40165e7ed38fc158f", "productRatePlanChargeId": "8adc8f996512644e0165146beef94a16", "number": "C-00001052", "name": "Verbrauch bis 2000 kWh", "type": "Usage", "model": "PerUnit", "uom": "kWh", "version": 1, "pricingSummary": "EUR0.23/kWh", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": 0.23, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "ChargeTriggerDay", "listPriceBase": null, "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": null, "billingPeriodAlignment": "AlignToCharge", "quantity": null, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": "OnDemand", "segment": 1, "effectiveStartDate": "2018-08-06", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": false, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": null, "dmrc": null, "tcv": null, "dtcv": null, "description": "", "Type__c": "Tier-One-Usage" }, { "id": "8adc8f9965d230d40165ec8d40ea061c", "originalChargeId": "8adc8f9965d230d40165e7ed38df158b", "productRatePlanChargeId": "8adc8f996512644e0165146bee974a0a", "number": "C-00001048", "name": "Bereitstellung Ihrer sonnenBatterie", "type": "Usage", "model": "PerUnit", "uom": "kWh", "version": 1, "pricingSummary": "EUR-0.19327731/kWh", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": -0.19327731, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "DefaultFromCustomer", "listPriceBase": null, "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": null, "billingPeriodAlignment": "AlignToCharge", "quantity": null, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": "OnDemand", "segment": 1, "effectiveStartDate": "2018-08-06", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": false, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": null, "dmrc": null, "tcv": null, "dtcv": null, "description": "", "Type__c": "Battery-Provision" }, { "id": "8adc8f9965d230d40165ec8d40ee061f", "originalChargeId": "8adc8f9965d230d40165e7ed38e7158c", "productRatePlanChargeId": "8adc8f996512644e0165146beeaf4a0d", "number": "C-00001049", "name": "Verbrauch innerhalb der Freimenge", "type": "Usage", "model": "PerUnit", "uom": "kWh", "version": 1, "pricingSummary": "EUR0.19327731/kWh", "priceChangeOption": "NoChange", "priceIncreasePercentage": null, "currency": "EUR", "price": 0.19327731, "tiers": null, "includedUnits": null, "overagePrice": null, "discountPercentage": null, "discountAmount": null, "applyDiscountTo": null, "discountLevel": null, "discountClass": null, "discountApplyDetails": [], "billingDay": "DefaultFromCustomer", "listPriceBase": null, "billingPeriod": "Month", "specificBillingPeriod": null, "billingTiming": null, "billingPeriodAlignment": "AlignToCharge", "quantity": null, "smoothingModel": null, "numberOfPeriods": null, "overageCalculationOption": null, "overageUnusedUnitsCreditOption": null, "unusedUnitsCreditRates": null, "usageRecordRatingOption": "OnDemand", "segment": 1, "effectiveStartDate": "2018-08-06", "effectiveEndDate": null, "processedThroughDate": null, "chargedThroughDate": null, "done": false, "triggerDate": null, "triggerEvent": "ServiceActivation", "endDateCondition": "Subscription_End", "upToPeriodsType": null, "upToPeriods": null, "specificEndDate": null, "mrr": null, "dmrc": null, "tcv": null, "dtcv": null, "description": "", "Type__c": "Free-Amount-Usage" } ] } ] }';
            SingleRequestMock mockResponse = new SingleRequestMock(200, 'Completed', body, null);
            res = mockResponse.respond(reqQuery);
        } else {
            res = h.send(reqQuery);
        }

        // the response contains info about the subscription and its charges
        // extract the reponse to get Abschlag component ID
        Map<String, Object> json1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> json2 = (List<Object>) json1.get('ratePlans');
        Map<String, Object> json3 = (Map<String, Object>) json2[0];

        String subscriptionRatePlanId = (String) json3.get('id');
        String productRatePlanId = (String) json3.get('productRatePlanId');

        List<Object> json4 = (List<Object>) json3.get('ratePlanCharges');
        for (Object obj : json4) {
            Map<String, Object> json5 = (Map<String, Object>) obj;
            if (json5.get('name') == 'Abschlag') {
                subsRatePlanChargeId = (String) json5.get('id');
                prodRatePlanChargeId = (String) json5.get('productRatePlanChargeId');
            }
        }
        Date d = Date.today();
        Date d2 = d.addMonths(1).toStartOfMonth();

        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeFieldName('requests');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeFieldName('AmendOptions');
        gen.writeStartObject();
        gen.writeBooleanField('ProcessPayments', false);
        gen.writeEndObject();
        gen.writeFieldName('Amendments');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeDateField('ContractEffectiveDate', d2);
        gen.writeDateField('CustomerAcceptanceDate', d2);
        gen.writeStringField('Description', 'Changed regular payment');
        gen.writeDateField('EffectiveDate', d2);
        gen.writeStringField('Name', 'Amendment '+String.valueOf(DateTime.now()));
        gen.writeFieldName('RatePlanData');
        gen.writeStartObject();
        gen.writeFieldName('RatePlan');
        gen.writeStartObject();
        gen.writeStringField('AmendmentSubscriptionRatePlanId',subscriptionRatePlanId );
        gen.writeStringField('ProductRatePlanId',productRatePlanId );
        gen.writeEndObject();
        gen.writeFieldName('RatePlanChargeData');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeFieldName('RatePlanCharge');
        gen.writeStartObject();
        gen.writeStringField('AmendmentSubscriptionRatePlanChargeId',subsRatePlanChargeId );
        gen.writeStringField('ProductRatePlanChargeId',prodRatePlanChargeId );
        gen.writeNumberField('Price', zao.contract.RegularPrePayment__c);
        gen.writeDateField('EffectiveStartDate', d2);
        gen.writeDateField('TriggerDate', d2);
        gen.writeStringField('TriggerEvent', 'ServiceActivation' );
        gen.writeEndObject();
        gen.writeEndObject();
        gen.writeEndArray();
        gen.writeEndObject();
        gen.writeDateField('ServiceActivationDate', d2);
        gen.writeStringField('Status', 'Completed' );
        gen.writeStringField('SubscriptionId', zao.subscriptionId );
        gen.writeStringField('Type', 'UpdateProduct' );
        gen.writeEndObject();
        gen.writeEndArray();
        gen.writeEndObject();
        gen.writeEndArray();
        gen.writeEndObject();

        String jsonBody = gen.getAsString();
        System.debug(jsonBody);

        return jsonBody;
    }

    private static String bonusAmendmentBody(zuoraSetting__mdt settings, ZuoraAmendmentObject zao) {

        String ProductRatePlanChargeId;
        String ProductRatePlanId;

        // find 1st day of the next month or current month if start date is 1.
        Date day1NextMonth;

        System.debug(zao);
        if (zao.bonus.StartDate__c.day() == 1) {
            day1NextMonth = zao.bonus.StartDate__c;
        } else {
            day1NextMonth = zao.bonus.StartDate__c.toStartOfMonth().addMonths(1);
        }

        // create bonus map
        if (zao.bonus.NoOfMonths__c == 1 || zao.bonus.NoOfMonths__c == null) {
            // One-time Bonus
            ProductRatePlanChargeId = settings.BonusChargeIdOneTime__c;
            ProductRatePlanId = settings.BonusRatePlanIdOnetime__c;
        } else if (zao.bonus.NoOfMonths__c > 1) {
            // Recurring Bonus
            ProductRatePlanChargeId = settings.RecurringBonusChargeId__c;
            ProductRatePlanId = settings.RecurringBonusRatePlan__c;
        }

        // create request body
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeFieldName('requests');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeFieldName('AmendOptions');
        gen.writeStartObject();
        gen.writeBooleanField('GenerateInvoice', false);
        gen.writeBooleanField('ProcessPayments', false);
        gen.writeEndObject();
        gen.writeFieldName('Amendments');
        gen.writeStartArray();

        gen.writeStartObject();
        gen.writeDateField('ContractEffectiveDate', zao.bonus.StartDate__c); // customer start date
        gen.writeDateField('CustomerAcceptanceDate', day1NextMonth); // customer signed date

        //System.debug(campaignMap.get(b.Id));
        gen.writeStringField('Description', zao.campaignName);

        gen.writeDateField('EffectiveDate', day1NextMonth); // confirmed delivery start
        gen.writeStringField('Name', zao.bonus.Name);
        gen.writeFieldName('RatePlanData');
        gen.writeStartObject();
        gen.writeFieldName('RatePlan');
        gen.writeStartObject();
        gen.writeStringField('ProductRatePlanId', ProductRatePlanId); // get from zuora Product by searching the id
        gen.writeEndObject();
        gen.writeFieldName('RatePlanChargeData');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeFieldName('RatePlanCharge');
        gen.writeStartObject();
        gen.writeStringField('ProductRatePlanChargeId', ProductRatePlanChargeId); // get from zuora products by searching the is

        if (zao.bonus.NoOfMonths__c > 1) {
            gen.writeStringField('ChargeType', 'Recurring');
            gen.writeStringField('EndDateCondition', 'FixedPeriod');
        }
        if (zao.bonus.Unit__c == 'Euro') {
            gen.writeNumberField('Price', zao.bonus.Amount__c - 2 * zao.bonus.Amount__c);
            gen.writeNumberField('NumberOfPeriods', zao.bonus.NoOfMonths__c);
            gen.writeStringField('UpToPeriodsType', 'Months');
            gen.writeNumberField('UpToPeriods', zao.bonus.NoOfMonths__c);
        } else if (zao.bonus.Unit__c == 'kWh') {
            gen.writeNumberField('NumberOfPeriods', zao.bonus.NoOfMonths__c);
            gen.writeNumberField('Price', calculateElectricityBonus(zao));
            gen.writeStringField('UpToPeriodsType', 'Months');
            gen.writeNumberField('UpToPeriods', zao.bonus.NoOfMonths__c);
        }
        gen.writeEndObject();
        gen.writeEndObject();
        gen.writeEndArray();
        gen.writeEndObject();
        gen.writeDateField('ServiceActivationDate', day1NextMonth);  // bonus start date
        gen.writeStringField('Status', 'Completed');
        gen.writeStringField('SubscriptionId', zao.subscriptionId); // get from bonus.contract.account - get latest subscription - is this correct?
        gen.writeStringField('Type', 'NewProduct');
        gen.writeEndObject();

        gen.writeEndArray();
        gen.writeEndObject();
        gen.writeEndArray();
        gen.writeEndObject();

        String jsonBody = gen.getAsString();
        System.debug('jsonBody ' +jsonBody);

        return jsonBody;
    }

    private static Decimal calculateElectricityBonus(ZuoraAmendmentObject zao){
        // return Decimal which is energy bonus converted to monthly discount in euro

        Decimal kWhPrice;
        if (zao.energyRate == null || zao.energyRate == 0) {
            kWhPrice = 0.23;
        } else {
            kWhPrice = zao.energyRate / 100;
        }

        System.debug(kWhPrice);
        Decimal amount; // calculated monetary bonus calculated per month
        if (zao.bonusNoOfMonths == 1 || String.isBlank(String.valueOf(zao.bonusNoOfMonths))) {
            amount = zao.bonusAmount * kWhPrice - 2*zao.bonusAmount * kWhPrice;
        } else if (zao.bonusNoOfMonths > 1) {
            amount = (zao.bonusAmount / zao.bonusNoOfMonths) * kWhPrice - 2*(zao.bonusAmount / zao.bonusNoOfMonths) * kWhPrice;
        }

        return amount;
    }
}