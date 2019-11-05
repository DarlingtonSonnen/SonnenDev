@isTest
private class BackToSalesOperation_Test {
	
	@isTest 
    static void testController() {
    
        Map<String,String> recordTypesOpportunity = SonnenbatterieConstants.getRecordTypeIdsByObjectName('Opportunity');
        
        // Create Opportunity
        Opportunity opportunity = new Opportunity(
            Name = 'Test',
        	RecordTypeId = recordTypesOpportunity.get('DirectSales'),
            StageName = 'Open',
            CloseDate = System.today()
        );
        insert opportunity;
                
        ApexPages.StandardController standardController = new ApexPages.StandardController(opportunity);
        BackToSalesOperationController controller = new BackToSalesOperationController(standardController);
        
        controller.getReasonSelection();    
                
        Test.startTest();
        
        controller.selection = 'Closed Lost - Other';
        controller.save();        
        List<Task> createdTasks = [SELECT Id FROM Task];        
        System.assert(createdTasks.isEmpty(), 'Task should not be created due to missing reason description');
        
        controller.selection = 'Closed Lost - Other';
        controller.descField = 'My funny description';
        controller.save();    
        
        createdTasks = [SELECT Id, Subject, Status, WhatId FROM Task];        
        System.assertEquals(1, createdTasks.size(), 'Expect one task');
        Task createdTask = createdTasks.get(0);
        
        System.assertEquals(controller.selection, createdTask.Subject);
        System.assertEquals(opportunity.Id, createdTask.WhatId);
        
        opportunity = [SELECT Id, StageName, RecordTypeId FROM Opportunity WHERE Id = :opportunity.Id];
        
        System.assertEquals(recordTypesOpportunity.get('Order'), opportunity.RecordTypeId, 'Expected RecordType to be "Order" (= Partner Sales)');
        System.assertEquals('Open', opportunity.StageName, 'Expected StageName to be "Open"');
        
        Test.stopTest();        
    }        
}