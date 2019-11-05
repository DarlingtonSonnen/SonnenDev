/**
 * Created by m.muchow on 13.05.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class ConvertStockItemJunction {
    public static void createJunction(Map<Id, String> masterMap, Map<Id, String> slaveMap) {
        List<ComponentJunction__c> cJunctionList = new List<ComponentJunction__c>();
        Id masterId;
        for (Id masterIdKey : masterMap.keySet()) {
            masterId = masterIdKey;
        }
        for (Id slaveId : slaveMap.keySet()) {
            ComponentJunction__c cJunction = new ComponentJunction__c();
            cJunction.Name = '#'+masterMap.get(masterId)+' (Master) - '+'#'+slaveMap.get(slaveId)+' (Slave)';
            cJunction.MasterComponent__c = masterId;
            cJunction.SlaveComponent__c = slaveId;
            cJunctionList.add(cJunction);
        }
        insert cJunctionList;
    }

    public static void deleteJunction(String oldMasterSerial) {
        List<ComponentJunction__c> cmpJList = new List<ComponentJunction__c>();
        List<Component__c> componentList = [SELECT Id, (SELECT Id FROM ComponentJunctionsSlave__r) FROM Component__c WHERE SerialNumber__c =: oldMasterSerial];
        for (Component__c cmp : componentList) {
            cmpJList = cmp.ComponentJunctionsSlave__r;
        }
        delete cmpJList;
    }
}