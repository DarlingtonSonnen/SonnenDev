/*
* Created by Bartosz Jarmolinski on 02/07/2018
* - findSerialNumber - the methods prevents creation of stock item if there is already an asset or another stock item with the same serial number
*
*  Added method by Antonio Romero on 14/08/2019
* - relateCaseAsset - the method links the related cases of the stock item with the asset of the stock item
*
*  test coverage: StockItemTriggerHandlerTest
*
*/

public class StockItemTriggerHandler extends TriggerHandler {


	public override void beforeInsert() {
		this.findSerialNumber();
	}

	public override void beforeUpdate() {
		this.findSerialNumber();
	}

	public override void afterUpdate(){
		this.relateCaseAsset();
	}

	private void relateCaseAsset() {

		TriggerStockItem__mdt triggerSettings = [SELECT Active__c FROM TriggerStockItem__mdt WHERE Label = 'relate Case Asset' LIMIT 1];

		if (triggerSettings.Active__c == true || Test.isRunningTest()) {

			Map<Id, StockItem__c> siOldMap = (Map<Id, StockItem__c>) Trigger.oldMap;
			Map<Id, StockItem__c> siNewMap = (Map<Id, StockItem__c>) Trigger.newMap;
			Map<Id, Id> stockAssetMap = new Map<Id, Id>();
			List<Case> updCases = new List<Case>();
			// Record Type CONVERTED
			Id converted = Schema.SObjectType.StockItem__c.getRecordTypeInfosByName().get('Converted').getRecordTypeId();
			//System.debug('converted id: '+ converted);
			for (StockItem__c si : [SELECT Id,Asset__c,RecordTypeId FROM StockItem__c WHERE Id IN:siNewMap.keySet()]) {
				if (siNewMap.get(si.Id).RecordTypeId != siOldMap.get(si.Id).RecordTypeId && siNewMap.get(si.Id).RecordTypeId == converted) {
					stockAssetMap.put(si.Id, si.Asset__c);
				}
			}
			System.debug('stock item map: ' + stockAssetMap);

			for (Case c : [SELECT Id, AssetId,StockItem__c FROM Case WHERE StockItem__c IN:stockAssetMap.keySet()]) {
				c.AssetId = stockAssetMap.get(c.StockItem__c);
				updCases.add(c);
			}
			System.debug('updCases: ' + updCases);

			if (updCases.size() > 0) {
				update updCases;
			}
		}
	}

	private void findSerialNumber() {

		TriggerStockItem__mdt triggerSettings = [SELECT Active__c FROM TriggerStockItem__mdt WHERE Label = 'find Serial Number' LIMIT 1];

		if (triggerSettings.Active__c == true || Test.isRunningTest()) {

			List<StockItem__c> triggerNew = (List<StockItem__c>) Trigger.new;
			List<StockItem__c> stockItems = new List<StockItem__c>();
			Map<Id, StockItem__c> siOldMap = (Map<Id, StockItem__c>) Trigger.oldMap;
			Map<Id, StockItem__c> siNewMap = (Map<Id, StockItem__c>) Trigger.newMap;
			Set<String> serialNumbers = new Set<String>(); // stock item serial numbers
			Map<Id, String> serialNumMap = new Map<Id, String>(); // stock item serial numbers as value, stock item Id as key

			// run logic for all stock items in
			if (Trigger.isInsert) {
				for (StockItem__c si : triggerNew) {
					if (!String.isBlank(si.SerialNumber__c)) {
						stockItems.add(si);
					}
				}
			} else if (Trigger.isUpdate) {
				for (Id i : siNewMap.keySet()) {
					if (siNewMap.get(i).SerialNumber__c != siOldMap.get(i).SerialNumber__c && !String.isBlank(siNewMap.get(i).SerialNumber__c)) {
						stockItems.add(siNewMap.get(i));
					}
				}
			}

			for (StockItem__c si : stockItems) {
				serialNumMap.put(si.Id, si.SerialNumber__c);
			}

			// find assets with the serial numbers
			List<Asset> assets = [SELECT Id, SerialNumber FROM Asset WHERE SerialNumber IN:serialNumMap.values() AND Id != NULL];
			List<StockItem__c> existingStockItems = [SELECT Id, SerialNumber__c FROM StockItem__c WHERE SerialNumber__c IN:serialNumMap.values() AND Id != NULL];
			System.debug('existingStockItems: ' + existingStockItems);

			if (assets.size() != 0) {

				for (Asset a : assets) {
					serialNumbers.add(a.SerialNumber);
				}
				stockItems[0].SerialNumber__c.addError('Unable to save the stock item because assets with these serial numbers already exist: ' + serialNumbers);

			} else if (existingStockItems.size() != 0) {

				for (StockItem__c si : existingStockItems) {
					serialNumbers.add(si.SerialNumber__c);
				}
				stockItems[0].SerialNumber__c.addError('Unable to save the stock item because other stock items with the same serial numbers already exist: ' + serialNumbers);
			}
		}
	}
}