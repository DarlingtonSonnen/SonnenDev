/**
 * Created by b.jarmolinski on 17/01/2019.
 */

public without sharing class zuoraCreateQuoteWrapper {

    @InvocableMethod(description='invokes the process of zuora quote creation in salesforce')
    public static void generateQuote(List<zuoraSync__c> zuoraSyncs) {
        // wrapper method to follow up on quote creation

        List<Contract> contractsAll = new List<Contract>();
        for (zuoraSync__c zs : zuoraSyncs) {
            String dataChunk = zs.RemainingContracts__c;
            List<Contract> contracts = (List<Contract>) JSON.deserialize(dataChunk, List<Contract>.class);
            contractsAll.addAll(contracts);
        }
        ZuoraQuoteGenerator6.generateQuote(contractsAll);
    }
}