/**
 * Created by b.jarmolinski on 18/09/2018.
 * The class / object is used in amendment calls to zuora as data wrapper
 * Depending on the character of the change various sObjects may be passed as arguments. In order to keep the amendment call process
 * as unified as possible, the ZuoraAmendmentObject is used to handle different type of data with the same process (zuoraIntegrationV2 class)
 *
 * Version 1.1 on 24/01/2019 by Bartosz
 * - added variable energyRate - in order to make the electricity bonus dependent on the value of Contract__r.AppointedEnergyRate__c
 */

public with sharing class ZuoraAmendmentObject {

    public Contract contract;
    public String subscriptionId;
    public String operation;

    public Bonus__c bonus;
    public Decimal bonusAmount;
    public Decimal bonusNoOfMonths;
    public String campaignName;
    public Decimal energyRate;



    public ZuoraAmendmentObject(Contract c, String subscriptionId, String operation) {

        this.contract = c;
        this.subscriptionId = subscriptionId;
        this.operation = operation;
    }

    public ZuoraAmendmentObject (Bonus__c b, String subscriptionId, String campaignName, Decimal bonusNoOfMonths, Decimal bonusAmount, Decimal energyRate ) {
        this.bonus = b;
        this.subscriptionId = subscriptionId;
        this.campaignName = campaignName;
        this.bonusNoOfMonths = bonusNoOfMonths;
        this.bonusAmount = bonusAmount;
        this.energyRate = energyRate;
    }
}