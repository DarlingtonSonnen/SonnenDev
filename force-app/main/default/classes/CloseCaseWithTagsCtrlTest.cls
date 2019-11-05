/**
 * CloseCaseWithTagsCtrlTest
 *
 * Tests for the controller of Lightning Component "CloseCaseWithTags"
 *
 * v1.1     2018-05-24  Polina Tsuban-Drobot        initial (SOBCRM-1146)
 * v1.2     2018-06-13  Polina Tsuban-Drobot        added restriction of possible Statuses according to Case Record Type (SOBCRM-1212)
 * v1.3     2018-06-25  Polina Tsuban-Drobot        execute article publishing from test user (SOBCRM-1224)
 * v1.4     2018-08-31  Polina Tsuban-Drobot        made Knowledge objects unique in context of names (SOBCRM-1252)
 *
 * @see CloseCaseWithTagsCtr
 */
@isTest
public class CloseCaseWithTagsCtrlTest {

    @testSetup
    static void testSetup() {
        Case cs = new Case(Status = 'New', Subject = 'CloseCaseWithTagsCtrl');
        insert cs;

        Knowledge__kav a = new Knowledge__kav(Title = 'CloseCaseWithTagsCtrl', Summary = 'CloseCaseWithTagsCtrl', URLName = 'CloseCaseWithTagsCtrl');
        insert a;

        //retrieve master article Id created on Knowledge__kav record insertion
        //in order to get the KnowledgeArticleId
        a = [SELECT KnowledgeArticleId, ArticleNumber FROM Knowledge__kav WHERE Id = :a.Id];

        User u = new User();
        u.FirstName = 'user Name';
        u.Email = 'email@mailforspam.com';
        u.Username = 'email@mailforspam.com';
        u.LastName = 'last name 1';
        u.Alias = 'alias 1';
        u.CommunityNickname = 'comm nick 1';
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey = 'UTF-8';
        u.ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        u.LanguageLocaleKey = 'en_US';
        u.UserPermissionsKnowledgeUser = true;
        insert u;

        System.runAs(u) {
            KbManagement.PublishingService.publishArticle(a.KnowledgeArticleId, true);
        }

        KnowledgeArticleVersion knowledgeArticleVersion = [
            SELECT Id, Title
            FROM KnowledgeArticleVersion
            WHERE ArticleNumber = :a.ArticleNumber
        ];

        List<Topic> topics = new List<Topic>();
        for (Integer i = 0; i < 5; i++) {
            topics.add(new Topic(Name = 'CloseCaseWithTagsCtrl ' + i));
        }
        insert topics;

        List<TopicAssignment> topicAssignments = new List<TopicAssignment>();
        for (Topic t : topics) {
            topicAssignments.add(new TopicAssignment(EntityId = knowledgeArticleVersion.Id, TopicId = t.Id));
        }
        topicAssignments.add(new TopicAssignment(EntityId = cs.Id, TopicId = topics[0].Id));
        insert topicAssignments;

        CaseArticle caseArt = new CaseArticle(CaseId = cs.Id, KnowledgeArticleId = a.KnowledgeArticleId);
        insert caseArt;
    }

    @isTest
    static void testInitComponent() {
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        Test.setMock(HttpCalloutMock.class, new MockResponseGenerator());
        CloseCaseWithTagsCtrl ctrl = CloseCaseWithTagsCtrl.initController(cs.Id);

        Test.stopTest();

        System.assertNotEquals(null, ctrl.caseRecord);
        System.assertNotEquals(null, ctrl.tags);
        System.assertNotEquals(null, ctrl.statusOptions);
        System.assertNotEquals(null, ctrl.closedStatuses);
    }

    @isTest
    static void testRefreshComponent() {
        Case cs = [SELECT Id FROM Case LIMIT 1];

        CloseCaseWithTagsCtrl ctrl = CloseCaseWithTagsCtrl.initController(cs.Id);

        ctrl = CloseCaseWithTagsCtrl.refreshController(JSON.serialize(ctrl));

        System.assertNotEquals(null, ctrl.caseRecord);
        System.assertNotEquals(null, ctrl.tags);
        System.assertNotEquals(null, ctrl.statusOptions);
        System.assertNotEquals(null, ctrl.closedStatuses);
    }

    @isTest
    static void testSaveCaseWithTags() {

        Case cs = [SELECT Id FROM Case LIMIT 1];

        CloseCaseWithTagsCtrl ctrl = CloseCaseWithTagsCtrl.initController(cs.Id);
        ctrl.caseRecord.Status = 'Closed - Done';

        ctrl = CloseCaseWithTagsCtrl.saveCaseWithTags(JSON.serialize(ctrl));

        cs = [SELECT Id, Status FROM Case WHERE Id = :cs.Id];
        System.assertEquals(ctrl.caseRecord.Status, cs.Status);
    }

    public class MockResponseGenerator implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            if (!req.getEndpoint().startsWith(System.Url.getSalesforceBaseURL().toExternalForm() +
                '/services/data/v42.0/ui-api/object-info/Case/picklist-values/')) {

                throw new CalloutException('MockResponseGenerator doesn\'t handle this endpoint: ' + req.getEndpoint());
            }

            HttpResponse resp = new HttpResponse();
            resp.setHeader('Content-Type', 'application/json');
            resp.setStatus('OK');
            resp.setStatusCode(200);
            resp.setBody('{"controllerValues":{},"defaultValue":{"attributes":null,"label":"New","validFor":[],"value":"New"},"eTag":"8b20f985c28a1b115cc98cadebd6fe3d","url":"/services/data/v42.0/ui-api/object-info/Case/picklist-values/01224000000B1EWAA0/Status","values":[{"attributes":null,"label":"New","validFor":[],"value":"New"},{"attributes":null,"label":"Open","validFor":[],"value":"Open"},{"attributes":null,"label":"Closed - Done","validFor":[],"value":"Closed - Done"},{"attributes":null,"label":"Closed - Canceled","validFor":[],"value":"Closed - Canceled"},{"attributes":null,"label":"Closed - Duplicate","validFor":[],"value":"Closed - Duplicate"},{"attributes":null,"label":"Closed - No Reaction by Customer","validFor":[],"value":"Closed - No Reaction by Customer"},{"attributes":null,"label":"Closed - Not our Responsibility","validFor":[],"value":"Closed - Not our Responsibility"},{"attributes":null,"label":"Closed - Not Reproductible","validFor":[],"value":"Closed - Not Reproductible"},{"attributes":null,"label":"Closed - Not solvable","validFor":[],"value":"Closed - Not solvable"},{"attributes":null,"label":"Closed - Out of Scope","validFor":[],"value":"Closed - Out of Scope"},{"attributes":null,"label":"Closed - Spam","validFor":[],"value":"Closed - Spam"},{"attributes":null,"label":"Observe","validFor":[],"value":"Observe"},{"attributes":null,"label":"Resubmission","validFor":[],"value":"Resubmission"},{"attributes":null,"label":"Waiting for Development","validFor":[],"value":"Waiting for Development"},{"attributes":null,"label":"Waiting for internal processing","validFor":[],"value":"Waiting for internal processing"},{"attributes":null,"label":"Waiting for Repair","validFor":[],"value":"Waiting for Repair"},{"attributes":null,"label":"Waiting for Reply by Customer","validFor":[],"value":"Waiting for Reply by Customer"}]}');
            return resp;
        }
    }
}