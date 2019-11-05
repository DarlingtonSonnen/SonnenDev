/**
 * InvocableEmailSender_Test
 *
 * Changelog
 * ---------
 *
 * v1.0.0   2018-10-29  Marko Schmalenbach          Initial
 * v1.1.0   2018-10-30  Marko Schmalenbach          Added testing of fieldOnObjectToSetOnSuccess
 * v1.2.0   2018-11-01  Marko Schmalenbach          Added testing of fieldOnObjectToSetResultStringTo
 * v1.2.1   2018-11-26  Marko Schmalenbach          Removed custom fields from Test
 *
 * @see InvocableEmailSender
 * @since 2018-10-29
 * @author Marko Schmalenbach
 */
@IsTest
private class InvocableEmailSender_Test {

    private final static String DEBUG_HEADER = 'InvocableEmailSender_Test.';
    private static User thisUser;

    @IsTest
    static void setup() {

        thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        // To prevent error: "MIXED_DML_OPERATION, DML operation on setup object is not permitted after you have
        // updated a non-setup object (or vice versa)"
        // https://stackoverflow.com/questions/2387475/how-to-avoid-mixed-dml-operation-error-in-salesforce-tests-that-create-users
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs(thisUser) {

            Account oAccount = new Account(
                Name = 'Voidy Inc.'
            );
            insert oAccount;

            Contact oContact = new Contact(
                AccountId = oAccount.Id,
                FirstName = 'Fritz',
                LastName = 'Feldsalat',
                Email    = 'mail@feldsalat.de'
            );
            insert oContact;

            Opportunity oOpportunity = new Opportunity(
                Name = 'Test Opp',
                CloseDate = System.today(),
                RecordTypeId = DiaUtilities.getRecordTypeId('Opportunity', 'WebOrder'),
                StageName = 'Requested',
                AccountId = oAccount.Id
            );
            insert oOpportunity;
        }
    }

    /**
     * Test mail with merge template and Contact as recipient
     */
    @IsTest
    static void testEmailMergeTemplate() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testEmailMergeTemplate() - ';

        setup();

        // Create a template
        EmailTemplate oEmailTemplate = new EmailTemplate(
            IsActive        = true,
            Name            = 'UnitTest InvocableEmailSender',
            DeveloperName   = 'UnitTest_InvocableEmailSender',
            Body            = '{!Opportunity.Id}',
            TemplateType    = 'text',
            FolderId        = UserInfo.getUserId()
        );
        insert oEmailTemplate;

        Contact oContact = [SELECT Id, Email FROM Contact LIMIT 1];

        Id idAccount       = [SELECT Id FROM Account LIMIT 1].Id;
        Id idContact       = oContact.Id;
        Id idOpportunity   = [SELECT Id FROM Opportunity LIMIT 1].Id;

        Datetime dtToSet = System.today().addDays(42);

        // Create request
        InvocableEmailSender.InvocableEmailSenderRequest oRequest = new InvocableEmailSender.InvocableEmailSenderRequest();
        oRequest.toAddress                        = 'test@anywhere.com';
        oRequest.textBody                         = 'This is the content';
        oRequest.ccAddresses                      = 'mail1@test.org  ,,  ,  mail2@test.org';
        oRequest.saveAsActivity                   = true;
        oRequest.apiTemplateName                  = oEmailTemplate.DeveloperName;
        oRequest.whatId                           = idOpportunity;
        oRequest.targetObjectId                   = idContact;
        oRequest.fieldOnObjectToSetOnSuccess      = 'CloseDate=' + dtToSet.format('yyyy-MM-dd'); // Time part must be removed!
        oRequest.fieldOnObjectToSetResultStringTo = 'NextStep';

        //------------------------------------------------
        // Test
        //------------------------------------------------
        List<InvocableEmailSender.InvocableEmailSenderResult> listInvocableEmailSenderResults;

        Test.startTest();

        System.runAs(thisUser) {
            listInvocableEmailSenderResults = InvocableEmailSender.sendEmails(new List<InvocableEmailSender.InvocableEmailSenderRequest>{oRequest});
        }

        Test.stopTest();

        //------------------------------------------------
        // Assertions
        //------------------------------------------------
        System.assertEquals(1, listInvocableEmailSenderResults.size());

        InvocableEmailSender.InvocableEmailSenderResult oSenderResult = listInvocableEmailSenderResults.get(0);
        System.assertEquals(true, oSenderResult.sent);

        // Check fieldOnObjectToSetOnSuccess
        Opportunity oOpportunity = [SELECT NextStep, CloseDate FROM Opportunity WHERE Id = :idOpportunity];
        System.assert(oOpportunity.CloseDate.isSameDay(dtToSet.date()));
        System.assert(String.isNotBlank(oOpportunity.NextStep));

        // Check Activities
        List<Task> listTasks = [
            SELECT AccountId, WhatId, ActivityDate, Type, WhoId
            FROM Task
            WHERE WhatId = :idOpportunity
        ];
        System.assertEquals(1, listTasks.size());

        Task oTask = listTasks.get(0);
        System.assertEquals(idAccount, oTask.AccountId);
        System.assertEquals(idContact, oTask.WhoId);

        List<TaskRelation> listTaskRelations = [
            SELECT AccountId, Id, IsWhat, RelationId, TaskId
            FROM TaskRelation
        ];
        System.assertEquals(2, listTaskRelations.size(), 'Expected 2 TaskRelations');

        for (TaskRelation oTaskRelation : listTaskRelations) {
            if (!oTaskRelation.IsWhat) {
                System.assertEquals(oRequest.targetObjectId, oTaskRelation.RelationId); // Contact
            }
            else if (oTaskRelation.IsWhat) {
                System.assertEquals(idOpportunity, oTaskRelation.RelationId);
            }
        }

        System.debug(DEBUG_HERE + 'listTaskRelations: ' + listTaskRelations);

        // Check Email
        List<EmailMessage> listEmailMessages = [
            SELECT
                ActivityId,
                BccAddress,
                CcAddress,
                FromAddress,
                FromName,
                HasAttachment,
                Id,
                RelatedToId,
                Status,
                Subject,
                TextBody,
                ToAddress
            FROM EmailMessage
        ];

        System.debug(DEBUG_HERE + 'listEmailMessages: ' + JSON.serializePretty(listEmailMessages));
        System.assertEquals(1, listEmailMessages.size());
        EmailMessage oEmailMessage = listEmailMessages.get(0);

        System.assertEquals(oRequest.toAddress, oEmailMessage.ToAddress);
        System.assertEquals(idOpportunity, oEmailMessage.TextBody);
        System.assertEquals(idOpportunity, oEmailMessage.RelatedToId);

        // Bcc
        System.assert(oEmailMessage.CcAddress != null);
        List<String> listBccMails = oEmailMessage.CcAddress.split(';');
        System.assertEquals(2, listBccMails.size());

        // (I) Just call (to say: I love you ...)
        InvocableEmailSender.isComplianceBccEnabled();
    }

    /**
     * Test simple text email
     */
    @IsTest
    static void testEmailSimpleText() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testEmailSimpleText() - ';

        setup();

        Id idOpportunity   = [SELECT Id FROM Opportunity LIMIT 1].Id;

        // Create request
        InvocableEmailSender.InvocableEmailSenderRequest oRequest = new InvocableEmailSender.InvocableEmailSenderRequest();
        oRequest.toAddress             = 'voidy@bogus-family.org ,, , null@voidness.com';
        oRequest.textBody              = '{!Opportunity.Id}';
        oRequest.whatId                = idOpportunity;
        oRequest.treatBodiesAsTemplate = true;

        //------------------------------------------------
        // Test
        //------------------------------------------------
        List<InvocableEmailSender.InvocableEmailSenderResult> listInvocableEmailSenderResults;

        Test.startTest();

        System.runAs(thisUser) {
            listInvocableEmailSenderResults = InvocableEmailSender.sendEmails(new List<InvocableEmailSender.InvocableEmailSenderRequest>{oRequest});
        }

        Test.stopTest();

        //------------------------------------------------
        // Assertions
        //------------------------------------------------
        System.assertEquals(1, listInvocableEmailSenderResults.size());

        InvocableEmailSender.InvocableEmailSenderResult oSenderResult = listInvocableEmailSenderResults.get(0);
        System.assertEquals(true, oSenderResult.sent);

        // Check Activities
        List<Task> listTasks = [
            SELECT AccountId, WhatId, ActivityDate, Type, WhoId
            FROM Task
            WHERE WhatId = :idOpportunity
        ];
        System.assertEquals(1, listTasks.size());
        System.debug(DEBUG_HERE + 'listTasks: ' + listTasks);

        List<TaskRelation> listTaskRelations = [
            SELECT AccountId, Id, IsWhat, RelationId, TaskId
            FROM TaskRelation
        ];

        System.debug(DEBUG_HERE + 'listTaskRelations: ' + listTaskRelations);
        System.assertEquals(1, listTaskRelations.size(), 'Expected 1 TaskRelation');
        TaskRelation oTaskRelation = listTaskRelations.get(0);

        System.assert(oTaskRelation.IsWhat);
        System.assertEquals(idOpportunity, oTaskRelation.RelationId);

        // Check Email
        List<EmailMessage> listEmailMessages = [
            SELECT
                ActivityId,
                BccAddress,
                CcAddress,
                FromAddress,
                FromName,
                HasAttachment,
                Id,
                RelatedToId,
                Status,
                Subject,
                TextBody,
                ToAddress
            FROM EmailMessage
        ];

        System.debug(DEBUG_HERE + 'listEmailMessages: ' + JSON.serializePretty(listEmailMessages));

        System.assertEquals(1, listEmailMessages.size());
        EmailMessage oEmailMessage = listEmailMessages.get(0);

        System.assertEquals(idOpportunity, oEmailMessage.TextBody);
        System.assertEquals(idOpportunity, oEmailMessage.RelatedToId);

        // To
        System.assert(oEmailMessage.ToAddress != null);
        List<String> listToMails = oEmailMessage.ToAddress.split(';');
        System.assertEquals(2, listToMails.size());
    }

    /**
     * Test outcome of a failed sending
     */
    @IsTest
    static void testError() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testError() - ';

        setup();

        Id idOpportunity   = [SELECT Id FROM Opportunity LIMIT 1].Id;

        // Create request
        InvocableEmailSender.InvocableEmailSenderRequest oRequest = new InvocableEmailSender.InvocableEmailSenderRequest();
        oRequest.toAddress                        = 'voidy@bogus-family.org';
        oRequest.whatId                           = idOpportunity;
        oRequest.treatBodiesAsTemplate            = true;
        oRequest.fieldOnObjectToSetResultStringTo = 'NextStep';

        DescribeFieldResult oDescribeFieldResult = Schema.getGlobalDescribe().get('Opportunity').getDescribe().fields.getMap().get(oRequest.fieldOnObjectToSetResultStringTo).getDescribe();
        Integer iMaxLength = oDescribeFieldResult.getLength();

        InvocableEmailSender.TEST_ERROR_MESSAGE = 'e'.repeat(iMaxLength+1);
        System.assert(InvocableEmailSender.TEST_ERROR_MESSAGE.length() > iMaxLength);

        //------------------------------------------------
        // Test
        //------------------------------------------------
        List<InvocableEmailSender.InvocableEmailSenderResult> listInvocableEmailSenderResults;

        Test.startTest();

        System.runAs(thisUser) {
            listInvocableEmailSenderResults = InvocableEmailSender.sendEmails(new List<InvocableEmailSender.InvocableEmailSenderRequest>{oRequest});
        }

        Test.stopTest();

        //------------------------------------------------
        // Assertions
        //------------------------------------------------
        System.assertEquals(1, listInvocableEmailSenderResults.size());

        InvocableEmailSender.InvocableEmailSenderResult oSenderResult = listInvocableEmailSenderResults.get(0);
        System.assertEquals(false, oSenderResult.sent);

        Opportunity oOpportunity = [SELECT NextStep FROM Opportunity WHERE Id = :idOpportunity];
        System.assert(String.isNotBlank(oOpportunity.NextStep));
        System.assertEquals(iMaxLength, oOpportunity.NextStep.length());
    }
}