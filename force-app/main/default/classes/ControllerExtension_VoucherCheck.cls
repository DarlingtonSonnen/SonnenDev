/**
 * Controller extension for VF page BonusOverrideNew that overrides 
 * the new and checks for voucher recordtype for the Bonus__c object
 *
 * @version 	1.0.0 	2016-08-17	Oyindamola Aderinwale	Initial
 * @version		1.0.1	2016-08-23	Daniel Stange	Minor Refactoring
 * 
 * @author Oyindamola Aderinwale <damola@die-interaktiven.de>
 * @author Daniel Stange <daniel.stange@die-interaktiven.de>
 * @see	SOBCRM-592	https://interaktiv.jira.com/browse/SOBCRM-592
 * 
 * BUNDLE INFO / DEPENDENCIES:
 * @see Test_VoucherCheck.cls
 * @see BonusOverrideNew.vfp
 **/  
public class ControllerExtension_VoucherCheck {
    
    @testvisible
    private Id currentRecordType;
    
    Set<ID> allowedRecordTypes= new Set<ID>{
        Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Voucher')
    };
    
    public ControllerExtension_VoucherCheck (ApexPages.StandardController controller) {
        
    	currentRecordType=ApexPages.CurrentPage().getParameters().get('RecordType');
    }
    
    public PageReference checkForVoucherRT() {
        
        If(allowedRecordTypes.contains(currentRecordType)){
        
            return new PageReference('/a0f/e?&nooverride=1&RecordType='+currentRecordType);
        }
        
        else {
            
            return NULL;   
        }
    }
    
    public PageReference BackToBonus(){
        
            return new PageReference('/a0f/o').setRedirect(true);
    }
    
    public PageReference CreateVoucher(){
        
            return new PageReference('/a0f/e?&nooverride=1&RecordType='+ Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Voucher'));
    }
}