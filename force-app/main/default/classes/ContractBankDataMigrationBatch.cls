/**
 * Batch for migration of bank data from Contract to BankData__c object.
 *
 * @version    2018-04-26 marko@die-interaktiven.de             Bypass ContractTriggerHandler instead of deprecated LumenazaContractTriggerHandler
 * @version    2016-12-14 marko@die-interaktiven.de             Bypass LumenazaContractTriggerHandler as there are no relevant fields updated
 *                                                              here and the risk to run into a callout limit is given
 * @version    2016-12-12 dino.ursic@die-interaktiven.de        SOBCRM-733 - Bank Data in Contract REST API einbinden (Teil 2: Datenmigration)
 */
global without sharing class ContractBankDataMigrationBatch implements Database.Batchable<sObject> {

    global String query = 'SELECT Id, AccountId, Account.MandateReferenceNumber__c, Account.CustomerNoDatev__c, ' +
                              'BankDataFirstname__c, ' +
                              'BankDataLastname__c, ' +
                              'BankDataSWIFT__c, ' +
                              'BankDataIBAN__c, ' +
                              'SEPADate__c ' +
                        'FROM Contract ' +
                        'WHERE BankData__c = NULL AND AccountId != NULL AND BankDataIBAN__c != NULL';

    /** START method */
    global Database.QueryLocator start(Database.BatchableContext BC) {

        return Database.getQueryLocator(query);
    }

    /** EXECUTE method */
    global void execute(Database.BatchableContext BC, List<sObject> scope) {

        // Bypass irrelevant triggers:
        TriggerHandler.bypass('AccountTriggerHandler');
        TriggerHandler.bypass('ContractTriggerHandler');


        // Get Contracts
        List<Contract> contractsWithoutBankData = (List<Contract>)scope;
        if (contractsWithoutBankData.isEmpty())
            return;

        List<BankData__c> bankDataList = new List<BankData__c>();
        Map<Contract, BankData__c> bankDataByContractMap = new Map<Contract, BankData__c>();

        Map<Id, Set<String>> IBANsByAccount = new Map<Id, Set<String>>();

        for (Contract c : contractsWithoutBankData) {

            // If no BankData exist on the Contract, skip creating BankData record for the contract
            if (c.BankDataFirstname__c == NULL && c.BankDataLastname__c == NULL &&
                c.BankDataSWIFT__c == NULL && c.BankDataIBAN__c == NULL) {

                continue;
            }

            // Put instantiated empty BankData Set for a particular Account
            if(!IBANsByAccount.containsKey(c.AccountId))
                IBANsByAccount.put(c.AccountId, new Set<String>());

            // If the Set of IBANs for the current Contract's Account already contains
            // the BankDataIBAN from the current contract, it means that some of the previous
            // contracts already uses the same BankData - skip creating duplicate BankData record
            if (IBANsByAccount.get(c.AccountId).contains(c.BankDataIBAN__c))
                continue;

            //system.debug('IBANs ' + IBANsByAccount.get(c.AccountId) + ' of Account ' + c.AccountId + ' does not contain ' + c.BankDataIBAN__c);

            // Add new BankData for each occurence of a particular Account amongst the Contracts
            IBANsByAccount.get(c.AccountId).add(c.BankDataIBAN__c);

            // If above condition was not met, create BankData record for the current Contract c
            BankData__c bankData = new BankData__c();
            bankData.Account__c = c.AccountId;
            bankData.FirstName__c = c.BankDataFirstname__c;
            bankData.LastName__c = c.BankDataLastname__c;
            bankData.SWIFT__c = c.BankDataSWIFT__c;
            bankData.IBAN__c = c.BankDataIBAN__c;
            bankData.SepaDate__c = c.SEPADate__c;
            //bankData.SepaReference__c = c.Account.MandateReferenceNumber__c; // mandateRefNum = CustomerNoDatev__c + '0000001'
            bankData.SepaReference__c = c.Account.CustomerNoDatev__c + String.valueOf(IBANsByAccount.get(c.AccountId).size()).leftPad(7, '0');

            //bankDataList.add(bankData);
            bankDataByContractMap.put(c, bankData);

            //if(!bankDataByIBAN.containsKey(c.BankDataIBAN__c))
            //    bankDataByIBAN.put(c.BankDataIBAN__c, bankData);
            //contractByIBAN.put(c.BankDataIBAN__c, c);
        }

        try {
            insert bankDataByContractMap.values();
            //insert bankDataByIBAN.values();

            //update contracts with references to BankData
            for(Contract c : bankDataByContractMap.keySet()) {
                c.BankData__c = bankDataByContractMap.get(c).Id;
            }
            upsert new List<Contract>(bankDataByContractMap.keySet());
            //for(Contract c : contractByIBAN.values()) {
            //    c.BankData__c = bankDataByIBAN.get(c.BankDataIBAN__c).Id;
            //}
            //upsert contractByIBAN.values();
        }
        catch(Exception ex) {
            system.debug(ex.getMessage());
            system.debug(ex.getStackTraceString());
        }

        TriggerHandler.clearBypass('AccountTriggerHandler');
        TriggerHandler.clearBypass('ContractTriggerHandler');
    }

    /** FINISH method */
    global void finish(Database.BatchableContext BC) {
        //LogUtil log = new LogUtil();
        //log.info('ContractBankDatMigrationBatch.finish()', 'Batch completed successfully!');
    }
}