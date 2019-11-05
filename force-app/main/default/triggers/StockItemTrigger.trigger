trigger StockItemTrigger on StockItem__c (before insert, before update, after update) {
	new StockItemTriggerHandler().run();
}