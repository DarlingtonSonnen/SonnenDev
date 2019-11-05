/**
 * Test Class to verify basic functionality of the new button override of the Bonus__c object
 *
 * @version 	1.0.0 	2016-08-23	Daniel Stange	Minor Refactoring
 * @author Daniel Stange <daniel.stange@die-interaktiven.de>
 * 
 * @see	SOBCRM-611	https://interaktiv.jira.com/browse/SOBCRM-611
 * 
 * BUNDLE INFO:
 * @see ControllerExtension_VoucherCheck.cls
 * @see BonusOverrideNew.vfp
 **/

@isTest
private class Test_VoucherCheck {
    
    // if the request to create a new Bonus__c contains the 'voucher' recordtype, 
    // then the request should be routed to a given non-null page reference
    @isTest private static void test_bonusCreationWithVoucher() {
         
        Test.startTest();
        PageReference pr = new PageReference('BonusOverrideNew'); 
        pr.getParameters().put('RecordType', Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Voucher'));
        Test.setCurrentPageReference(pr);
        
		ApexPages.StandardController stdBonus = new ApexPages.StandardController(new Bonus__c());
        ControllerExtension_VoucherCheck vc = new ControllerExtension_VoucherCheck(stdBonus);
        vc.currentRecordType = Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Voucher');
        vc.checkForVoucherRT();
        
        System.assertNotEquals(NULL, vc.checkForVoucherRT());
        
        Test.stopTest();
    }
    
    // else if the request to create a new Bonus__c does not contain the 'voucher' recordtype, 
    // then the request should be routed to a NULL page reference to display a warning and offer a selection
    
    @isTest private static void test_bonusCreationWithoutVoucher() {
        
        Test.startTest();
        
        PageReference pr = new PageReference('BonusOverrideNew'); 
        Test.setCurrentPageReference(pr);
        
        ApexPages.StandardController stdBonus = new ApexPages.StandardController(new Bonus__c());
        ControllerExtension_VoucherCheck vc = new ControllerExtension_VoucherCheck(stdBonus);
        
        System.assertEquals(NULL, vc.checkForVoucherRT());
        
        Test.stopTest();
        
    }
    
    @isTest private static void test_pushTheButtons() {
        
        Test.startTest();
        
        PageReference pr = new PageReference('BonusOverrideNew'); 
        Test.setCurrentPageReference(pr);
        
        ApexPages.StandardController stdBonus = new ApexPages.StandardController(new Bonus__c());
        ControllerExtension_VoucherCheck vc = new ControllerExtension_VoucherCheck(stdBonus);
        
        System.assertNotEquals(NULL, vc.CreateVoucher());
        
        Test.stopTest();
        
    }
    
    @isTest private static void test_pushBackButton() {
        
        Test.startTest();
        
        PageReference pr = new PageReference('BonusOverrideNew'); 
        Test.setCurrentPageReference(pr);
        
        ApexPages.StandardController stdBonus = new ApexPages.StandardController(new Bonus__c());
        ControllerExtension_VoucherCheck vc = new ControllerExtension_VoucherCheck(stdBonus);
        
        System.assertNotEquals(NULL, vc.BackToBonus());
        
        Test.stopTest();
        
    }
    

}