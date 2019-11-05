@isTest
public class CustomerEmailTemplateHelperTest {
    
    private static Id personAccRecType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();

    @isTest
    public static void canFindEmailTemplateForLanguageAndContry() {
        Id folderId = getFolderId();
        
    	EmailTemplate template = new EmailTemplate(
        	Name = 'de-DE_TestmailEmailCode_xsadsad',
            DeveloperName = 'Testmail_sonnen_112233',
            FolderId = folderId,
            TemplateType = 'text'
        );
        insert template;
        
        Id resultTemplateId = CustomerEmailTemplateHelper.findEmailTemplate('de', 'DE', 'TestmailEmailCode');        
        System.assertEquals(template.Id, resultTemplateId);
        
        resultTemplateId = CustomerEmailTemplateHelper.findEmailTemplate('en', 'DE', 'TestmailEmailCode');
        System.assertEquals(null, null);
        
        resultTemplateId = CustomerEmailTemplateHelper.findEmailTemplate('de', 'CH', 'TestmailEmailCode');
        System.assertEquals(null, null);
    }
    
    @isTest
    public static void canPreferBetterEmailTemplate() {
        Id folderId = getFolderId();
        
    	EmailTemplate template = new EmailTemplate(
        	Name = 'DE_TestmailEmailCode_xsadsad',
            DeveloperName = 'Testmail_sonnen_112233',
            FolderId = folderId,
            TemplateType = 'text'
        );
        insert template;
        
    	EmailTemplate template2 = new EmailTemplate(
        	Name = 'de-DE_TestmailEmailCode_xsadsad',
            DeveloperName = 'Testmail_sonnen_11223344',
            FolderId = folderId,
            TemplateType = 'text'
        );
        insert template2;
        
    	EmailTemplate template3 = new EmailTemplate(
        	Name = 'TestmailEmailCode_xsadsad',
            DeveloperName = 'Testmail_sonnen_11223355',
            FolderId = folderId,
            TemplateType = 'text'
        );
        insert template3;
        
        Contact con = new Contact(
            Language__c = 'de', 
            Account = new Account(
                BillingCountryCode = 'DE'
            )
        );
        
        Id resultTemplateId = CustomerEmailTemplateHelper.findEmailTemplate('de', 'DE', 'TestmailEmailCode');        
        System.assertEquals(template2.Id, resultTemplateId);
        
        delete template2;
        resultTemplateId = CustomerEmailTemplateHelper.findEmailTemplate('de', 'DE', 'TestmailEmailCode');
        System.assertEquals(template.Id, resultTemplateId);
        
        delete template;
        resultTemplateId = CustomerEmailTemplateHelper.findEmailTemplate('de', 'DE', 'TestmailEmailCode');
        System.assertEquals(null, resultTemplateId);
    }
    
    public static Id getFolderId() {
    	return [SELECT Id FROM Folder WHERE AccessType = 'Public' AND Type = 'Email' LIMIT 1].Id;
    }
                        
}