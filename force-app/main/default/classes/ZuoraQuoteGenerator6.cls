/*
 * Created by b.jarmolinski on 16/08/2018.
 *
 * The class is part of sync between Zuora and Salesforce
 * It is invoked by process builder when confirmed delivery start on contract is filled in
 * Unit test: zuoraIntegration_Test
 *
 * Version 1.1 on 16/11/2018 by Bartosz
 * - added if statement to update quotes charges only if quotes was successfully created
 *
 * Version 1.2 on 08/01/2019 by Bartosz
 * - added zqu__InvoiceSeparately__c parameter when creating quote
 * - Changed newQuote.zqu__Customer_Acceptance_Date__c - if ConfirmedDeliveryStart is on the 1. day of the month, then the two dates are equal
 *
 * Version 1.3 on 14/01/2019 by Bartosz
 * - added method calculateDate(Contract cont)
 * - changed newQuote.zqu__StartDate__c assignment to return value of the calculateDate method
 * - modified /qc.Name == 'Abschlag' && newQuote.zqu__StartDate__c != 1/. before: cont.StartDate__c
 *
 * Version 2.0 on 17/01/2019 by Bartosz
 * - DML and SOQL limit checking to handle multiple contracts in the context
 * - Saving contracts above limits for later processing (quote creation)
 * - Adding logging zuoraSync__c for the contracts above limits
 * - Remark: queueable interface is an alternative but risky one due to limit of 1 concurrent class instances
 */

public without sharing class ZuoraQuoteGenerator6 {

    @InvocableMethod(description='invokes the process of zuora quote creation in salesforce')
    public static void generateQuote(List<Contract> contracts) {

        zuoraSetting__mdt sett = ZuoraSettings.getZuoraSetting();

        System.debug(contracts.size());
        List<Contract> remainingContracts = new List<Contract>();
        while (contracts.size() > 0) {

            Contract cont = contracts.remove(0);

            if (Limits.getLimitDMLStatements() > Limits.getDMLStatements()+ sett.GovernanceLimitsBuffer__c
                    && Limits.getLimitQueries() > Limits.getQueries() + sett.GovernanceLimitsBuffer__c) {
                // Limits with buffer (set in metadata settings) to make sure the operation can be completed and will not
                // hit the governance limits

                createQuote(cont);
            } else {
                remainingContracts.add(cont);
            }
        }
        System.debug(remainingContracts.size());
        if (remainingContracts.size() > 0) {
            // create zuora sync with list of contracts (serialized) for which the quotes have not been created
            // the insert will trigger future action to insert the quotes for them
            zuoraSync__c remainder = new zuoraSync__c();
            remainder.RemainingContracts__c = JSON.serialize(remainingContracts);
            remainder.Process__c = 'Delayed quote creation';
            remainder.Message__c = 'Zuora quote creation delayed for the contracts in Remaining Contracts field in order to avoid SF limits.';
            try {
                insert remainder;
            } catch (Exception e) {
                System.debug(e.getMessage());
            }
        }
    }

    private static void createQuote(Contract cont) {
        System.debug('cont: '+cont);
        List<Zuora__CustomerAccount__c> zaList = [SELECT Zuora__Zuora_Id__c, Zuora__AccountNumber__c FROM Zuora__CustomerAccount__c
        WHERE Zuora__Account__c = :cont.AccountId];

        zqu__Quote__c newQuote = new zqu__Quote__c();
        // The Quote objects have lots of options. Here a list of most of them
        newQuote.Name = 'Auto-created Quote ' + String.valueOf(Datetime.now());
        newQuote.Contract__c = cont.Id;

        Contact contact = [select Id from Contact where AccountId =: cont.AccountId limit 1];
        newQuote.zqu__Account__c = cont.AccountId; // mandatory
        newQuote.zqu__BillToContact__c = contact.Id;
        newQuote.zqu__SoldToContact__c = contact.Id;

        if (zaList.size() != 0) {
            newQuote.zqu__ZuoraAccountID__c = zaList[0].Zuora__Zuora_Id__c; // mandatory
            newQuote.zqu__Zuora_Account_Number__c = zaList[0].Zuora__AccountNumber__c; // mandatory??
        }


        // Approval Status needs to be changed to `Approved` to be allowed to be sent to Zuora
        newQuote.zqu__Subscription_Term_Type__c = 'Evergreen';
        if (cont.ConfirmedDeliveryStart__c != null) {
            newQuote.zqu__StartDate__c = calculateDate(cont); //cont.StartDate; // mandatory
            newQuote.zqu__Service_Activation_Date__c = cont.ConfirmedDeliveryStart__c;
        } else {
            newQuote.zqu__StartDate__c = cont.StartDate; // mandatory
        }

        if (cont.ConfirmedDeliveryStart__c.day() == 1) {
            newQuote.zqu__Customer_Acceptance_Date__c = cont.ConfirmedDeliveryStart__c;
        } else {
            newQuote.zqu__Customer_Acceptance_Date__c = cont.ConfirmedDeliveryStart__c.toStartOfMonth().addMonths(1);
        }
        newQuote.zqu__Opportunity__c = cont.OpportunitySource__c;

        // Term settings
        newQuote.zqu__AutoRenew__c = true; // mandatory
        newQuote.zqu__InitialTerm__c = cont.ContractTerm; // mandatory
        newQuote.zqu__InitialTermPeriodType__c = 'Month';
        newQuote.zqu__RenewalTermPeriodType__c = 'Month';
        newQuote.zqu__RenewalTerm__c = 1;

        newQuote.zqu__GenerateInvoice__c = false;
        newQuote.zqu__PaymentMethod__c = 'Wire Transfer';
        newQuote.zqu__Currency__c = cont.CurrencyIsoCode;
        newQuote.zqu__InvoiceSeparately__c = true;

        try {
            insert newQuote;
        } catch(Exception e) {
            System.debug('Quote creation failed: '+e);
        }

        System.debug('quote: ' +newQuote);

        if (newQuote.Id != null) {
            // query for rate plan charge Id
            // add RatePlanCharges to the quote from the specified ProductRatePlanCharges

            String zProdId = [SELECT Product2.zProductRatePlan__c FROM OpportunityLineItem WHERE OpportunityId = :cont.OpportunitySource__c AND
            (Product2.Name LIKE 'sonnenFlat%' OR Product2.Name LIKE 'sonnenStrom%') LIMIT 1].Product2.zProductRatePlan__c;

            System.debug('zProdId '+zProdId);

            // zQuoteUtil is utility class provided in zuora managed package
            zqu__ProductRatePlan__c prodRatePlan = [SELECT Id FROM zqu__ProductRatePlan__c WHERE zqu__ZuoraId__c =:zProdId LIMIT 1];
            zqu.zChargeGroup newChargeGroup = zqu.zQuoteUtil.getChargeGroup(newQuote.Id, prodRatePlan.Id);
            zqu.ZQuoteUtil.addChargeGroup(newChargeGroup);
            System.debug(newChargeGroup);

            // change prices of the charges which will come from the website - to be found on webOrder Opportunity and contract
            List<zqu__QuoteRatePlanCharge__c> quoteCharges = [SELECT Id, Name, zqu__EffectivePrice__c, zqu__EffectiveStartDate__c
            FROM zqu__QuoteRatePlanCharge__c WHERE zqu__QuoteRatePlan__r.zqu__Quote__c = :newQuote.Id];
            System.debug('quoteCharges '+ quoteCharges);

            for (zqu__QuoteRatePlanCharge__c qc : quoteCharges) {
                if (qc.Name == 'Abschlag' && cont.RegularPrePayment__c != null ) {
                    qc.zqu__EffectivePrice__c = cont.RegularPrePayment__c;
                }
                if (qc.Name == 'Arbeitspreis' && cont.AppointedEnergyRate__c != null) {
                    qc.zqu__EffectivePrice__c = cont.AppointedEnergyRate__c/100; // because prices taken from the website and saved on contract are in cents
                }
                if (qc.Name == 'Abschlag' && newQuote.zqu__StartDate__c.day() != 1) {
                    qc.zqu__EffectiveStartDate__c = newQuote.zqu__StartDate__c.toStartOfMonth();
                } else {
                    qc.zqu__EffectiveStartDate__c = newQuote.zqu__StartDate__c;
                }
            }
            update quoteCharges;
        }
    }

    private static Date calculateDate(Contract cont) {
        // handles situation when confirmed delivery start is earlier than contract start date - zuora parameters cannot accept and
        // the date needs to be recalculated

        Date d;
        if (cont.ConfirmedDeliveryStart__c < cont.StartDate) {
            d = cont.ConfirmedDeliveryStart__c;
        } else {
            d = cont.StartDate;
        }

        return d;
    }
}