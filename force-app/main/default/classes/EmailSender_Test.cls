/**
 * EmailSender
 *
 * --- Changelog
 *
 * v 1.0 Igor Savchenko 2018-01-16 SOBCRM-1127
 *
 * @version 1.0
 */
@IsTest
public class EmailSender_Test {

    @testSetup
    static void setup() {
        EmailTemplate et = new EmailTemplate();
        et.isActive = true;
        et.Name = 'emailTemplate';
        et.DeveloperName = 'emailTemplate';
        et.TemplateType = 'text';
        et.FolderId = UserInfo.getUserId();

        try {
            insert et;
        } catch (Exception e) {

        }
    }

    @IsTest
    static void testEmailSender() {
        Test.startTest();

            Account a = new Account();
            a.LastName = 'AccountLastName';
            insert a;

            Contact c = new Contact();
            c.FirstName = 'ContactFirstName';
            c.LastName = 'ContactLastName';
            insert c;

            Contract cr = new Contract();
            RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Contract' And DeveloperName = 'CommunityWithFlatOption'];
            cr.RecordTypeId = rt.Id;
            cr.Type__c = 'sonnenbatterieHome-IT';
            cr.AccountId = a.Id;
            insert cr;

            EmailSender.SendEmailRequest emailRequest = new EmailSender.SendEmailRequest();
            emailRequest.contactId = null;
            emailRequest.contractId = null;
            emailRequest.emailAddress = null;
            emailRequest.emailTemplate = null;
            emailRequest.emailAddressFrom = null;

            EmailSender.sendEmail(new EmailSender.SendEmailRequest[]{emailRequest});

            emailRequest.contactId = c.Id;
            EmailSender.sendEmail(new EmailSender.SendEmailRequest[]{emailRequest});

            emailRequest.contractId = cr.Id;
            EmailSender.sendEmail(new EmailSender.SendEmailRequest[]{emailRequest});

            emailRequest.EmailAddress = 'email@mailforspam.com';
            EmailSender.sendEmail(new EmailSender.SendEmailRequest[]{emailRequest});

            emailRequest.emailTemplate = 'emailTemplate';
            EmailSender.sendEmail(new EmailSender.SendEmailRequest[]{emailRequest});

            OrgWideEmailAddress owAddr = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress LIMIT 1];

            emailRequest.emailAddressFrom = owAddr.Address;
            EmailSender.sendEmail(new EmailSender.SendEmailRequest[]{emailRequest});

            Case[] createdCases = [SELECT Id FROM Case];

            System.assertEquals(true, createdCases.size() >= 3);

        Test.stopTest();
    }

}