/**
 * Created by m.muchow on 15.11.2018.
 * Update 17.12.2018 - M.Muchow - Case for no asset / no stockitem should only creatd during update and not on insert
 * Update 09.01.2019 - M.Muchow - replaced Case creation for No Asset but Stockitem available with Apex Class to convert Stockitem
 * Update 15.10.2019 - M.Muchow - implemented Active Switch
 *                              - added new fields to support the new Global Service App
 */

public class MonitoringeServicesTriggerHandler extends TriggerHandler {

    //beforeInsert
    public override void beforeInsert() {
        this.searchAsset();
    }

    //beforeUpdate
    public override void beforeUpdate() {
        this.searchAsset();
    }

    //search Asset or Stockitem
    public void searchAsset() {

        TriggerMonitoringeServices__mdt triggerSettings = [SELECT Active__c FROM TriggerMonitoringeServices__mdt WHERE Label = 'search Asset' LIMIT 1];

        if (triggerSettings.Active__c == true || Test.isRunningTest()) {

            List<MonitoringeServices__c> listMonitoringeServices = (List<MonitoringeServices__c>) Trigger.new;
            MonitoringeServices__c oldMonitoringeServices = new MonitoringeServices__c();
            String newLine = System.Label.NewLine;

            for (MonitoringeServices__c monitoringeServices : listMonitoringeServices) {
                if (Trigger.isUpdate && Trigger.isBefore) {
                    oldMonitoringeServices = (MonitoringeServices__c)Trigger.oldMap.get(monitoringeServices.Id);
                }
                List<Contract> contractsToUpdate = new List<Contract>();
                if (!monitoringeServices.RestartMonitoring__c && oldMonitoringeServices.BatteryID__c != monitoringeServices.BatteryID__c) {
                    String assetNumber = monitoringeServices.BatteryID__c;
                    Id contractId = monitoringeServices.Contract__c;
                    if (assetNumber != null && assetNumber != '') {
                        List<Asset> listAssets = [SELECT Id, AccountId, Account.Name FROM Asset WHERE SerialNumber = :assetNumber];
                        List<Contract> listContracts = [SELECT AccountId, Account.Name, Asset__c, BatterySerialNumber__c, CustomerSignedId FROM Contract WHERE Id = :contractId];
                        system.debug('listContracts '+listContracts);
                        List<StockItem__c> listStockItems = [SELECT Id FROM StockItem__c WHERE SerialNumber__c = :assetNumber];

                        // Asset available and already linked to customer and to contract
                        if (!listAssets.isEmpty() && listAssets[0].AccountId == listContracts[0].AccountId && listContracts[0].Asset__c == listAssets[0].Id) {
                            monitoringeServices.Asset__c = listAssets[0].Id;
                        }
                        // Asset available and already linked to customer and asset on contract is empty
                        if (!listAssets.isEmpty() && listAssets[0].AccountId == listContracts[0].AccountId && listContracts[0].Asset__c == null) {
                            monitoringeServices.Asset__c = listAssets[0].Id;
                            listContracts[0].Asset__c = listAssets[0].Id;
                            listContracts[0].BatterySerialNumber__c = assetNumber;
                            contractsToUpdate.add(listContracts[0]);
                        }
                        // Asset available and already linked to customer but contract has another asset linked
                        if (!listAssets.isEmpty() && listAssets[0].AccountId == listContracts[0].AccountId && listContracts[0].Asset__c != null && listContracts[0].Asset__c != listAssets[0].Id) {
                            eServicesMonitoringSettings__mdt caseMeta = [SELECT CaseOwnerId__c, CaseRecordTypeId__c, CaseSubject__c, CaseStatus__c, CaseCategory__c, CaseDescription__c, CaseSubcategory__c, CaseOrigin__c, CaseCountry__c FROM eServicesMonitoringSettings__mdt WHERE DeveloperName = 'TriggerDifferentAssetOnContract'];
                            monitoringeServices.Asset__c = listAssets[0].Id;
                            String urlAsset = System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + listAssets[0].Id;
                            String urlConAsset = System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + listContracts[0].Asset__c;
                            String caseDescription = caseMeta.CaseDescription__c.replace('LINEBREAK',newLine.replace('-',''));
                            caseDescription = caseDescription.replace('LINK1',urlAsset);
                            caseDescription = caseDescription.replace('LINK2',urlConAsset);
                            Case newCase = new Case(RecordTypeId = caseMeta.CaseRecordTypeId__c, OwnerId = caseMeta.CaseOwnerId__c, AccountId = listContracts[0].AccountId, Contract__c = contractId, Description = caseDescription, Status = caseMeta.CaseStatus__c, Subject = caseMeta.CaseSubject__c, Category__c = caseMeta.CaseCategory__c, Subcategory__c = caseMeta.CaseSubcategory__c, Origin = caseMeta.CaseOrigin__c, Country__c = caseMeta.CaseCountry__c);
                            system.debug('test '+newCase);
                            insert newCase;
                        }
                        // Asset available but linked to another account
                        if (!listAssets.isEmpty() && listAssets[0].AccountId != listContracts[0].AccountId) {
                            eServicesMonitoringSettings__mdt caseMeta = [SELECT CaseOwnerId__c, CaseRecordTypeId__c, CaseSubject__c, CaseStatus__c, CaseCategory__c, CaseDescription__c, CaseSubcategory__c, CaseOrigin__c, CaseCountry__c FROM eServicesMonitoringSettings__mdt WHERE DeveloperName = 'TriggerAssetLinkedToAnotherAccount'];
                            String urlAsset = System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + listAssets[0].Id;
                            String urlActualAccount = System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + listContracts[0].AccountId;
                            String urlOtherAccount = System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + listAssets[0].AccountId;
                            String caseDescription = caseMeta.CaseDescription__c.replace('LINEBREAK',newLine.replace('-',''));
                            caseDescription = caseDescription.replace('ASSETNUMBER',assetNumber);
                            caseDescription = caseDescription.replace('LINK1',urlAsset);
                            if (listContracts[0].Account.Name != null || listContracts[0].Account.Name != '') {
                                caseDescription = caseDescription.replace('ACCOUNTNAME1',listContracts[0].Account.Name);
                            } else {
                                caseDescription = caseDescription.replace('ACCOUNTNAME1', '');
                            }
                            caseDescription = caseDescription.replace('LINK2',urlActualAccount);
                            if (listAssets[0].Account.Name != null || listAssets[0].Account.Name != '') {
                                caseDescription = caseDescription.replace('ACCOUNTNAME2',listAssets[0].Account.Name);
                            } else {
                                caseDescription = caseDescription.replace('ACCOUNTNAME2','');
                            }
                            caseDescription = caseDescription.replace('LINK3',urlOtherAccount);
                            Case newCase = new Case(RecordTypeId = caseMeta.CaseRecordTypeId__c, OwnerId = caseMeta.CaseOwnerId__c, AccountId = listContracts[0].AccountId, Contract__c = contractId, Description = caseDescription, Status = caseMeta.CaseStatus__c, Subject = caseMeta.CaseSubject__c, Category__c = caseMeta.CaseCategory__c, Subcategory__c = caseMeta.CaseSubcategory__c, Origin = caseMeta.CaseOrigin__c, Country__c = caseMeta.CaseCountry__c);
                            insert newCase;
                        }
                        // No Asset but Stockitem available, calling extension class to fill Stockitem and to convert to asset
                        if (listAssets.isEmpty() && !listStockItems.isEmpty()) {
                            Id assetId = MonitoringeServicesStockItemController.callConvertStockItem(listContracts[0].CustomerSignedId, contractId, listStockItems[0].Id);
                            monitoringeServices.Asset__c = assetId;
                            listContracts[0].Asset__c = assetId;
                            listContracts[0].BatterySerialNumber__c = assetNumber;
                            contractsToUpdate.add(listContracts[0]);
                        }
                        // No Asset and no Stockitem available
                        if (Trigger.isUpdate && Trigger.isBefore) {
                            if (listAssets.isEmpty() && listStockItems.isEmpty()) {
                                eServicesMonitoringSettings__mdt caseMeta = [SELECT CaseOwnerId__c, CaseRecordTypeId__c, CaseSubject__c, CaseStatus__c, CaseCategory__c, CaseDescription__c, CaseSubcategory__c, CaseOrigin__c, CaseCountry__c FROM eServicesMonitoringSettings__mdt WHERE DeveloperName = 'TriggerNoAssetNoStockitemAvailable'];
                                String caseDescription = caseMeta.CaseDescription__c.replace('ASSETNUMBER', assetNumber);
                                Case newCase = new Case(RecordTypeId = caseMeta.CaseRecordTypeId__c, OwnerId = caseMeta.CaseOwnerId__c, AccountId = listContracts[0].AccountId, Contract__c = contractId, Description = caseDescription, Status = caseMeta.CaseStatus__c, Subject = caseMeta.CaseSubject__c, Subcategory__c = caseMeta.CaseSubcategory__c, Origin = caseMeta.CaseOrigin__c, Country__c = caseMeta.CaseCountry__c);
                                insert newCase;
                            }
                        }
                        if (contractsToUpdate != null && !contractsToUpdate.isEmpty()) {
                            Database.update(contractsToUpdate);
                        }
                    }
                }
            }
        }
    }
}