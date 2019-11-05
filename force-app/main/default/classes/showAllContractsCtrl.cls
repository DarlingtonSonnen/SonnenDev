/**
 * Created by a.romero on 11/09/2019.
 */

public with sharing class showAllContractsCtrl {
    @AuraEnabled
    public static List<Contract> getContracts(String accountId) {
        List<Contract> contracts = new List<Contract>();
        system.debug(accountId);
        for(Contract cs: [SELECT Id,ContractNumber,Status,RecordType.Name,RecordTypeId  FROM Contract WHERE AccountId =: accountId]){
            contracts.add(cs);
        }
        system.debug(contracts);
        return contracts;
    }
}