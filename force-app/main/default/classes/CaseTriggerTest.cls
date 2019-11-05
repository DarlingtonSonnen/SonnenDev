/**
 * Case Trigger Tests
 *
 * Changelog
 * ---------
 * v1.0.0   ?           Igor Savchenko          Initial version (SOBCRM-1038)
 * v1.1.0   2018-01-31  Michael Muchow          Added tests for Scenario 1.1
 * v1.2.0   2018-07-24  Marko Schmalenbach      Fixed error case logic to compare Subject (SOBCRM-1237)
 * v1.3.0   2019-09-13  Michael Muchow          Removed not needed tests
 *
 * @see CaseTriggerHandler
 */
@isTest
public class CaseTriggerTest {

    @testSetup
    static void testSetup() {
        Id incidentRecordTypeID = Schema.Sobjecttype.Case.getRecordTypeInfosByName().get('Technical Support Case').getRecordTypeId();
        Id eServiceRecordTyId = Schema.Sobjecttype.Case.getRecordTypeInfosByName().get('eServices').getRecordTypeId();
        
        Knowledge__kav knowledgeArticleK = new Knowledge__kav(Title='Unit Test');
        knowledgeArticleK.UrlName = 'urlname';
        insert knowledgeArticleK;
        KnowledgeArticle[] knowledgeArticle = [SELECT Id FROM KnowledgeArticle];
       
        Case parentCase = new Case();
        parentCase.Subject = 'Parent technical case';
        parentCase.RecordTypeId =incidentRecordTypeID;
        parentCase.Status = 'Open';
        parentCase.ReportingCategory__c = 'Human Failure';
        parentCase.Type='Problem';
        insert parentCase;

        Case ChildCase = new Case();
        ChildCase.ParentId = parentCase.id;
        ChildCase.RecordTypeId = incidentRecordTypeID;
        childCase.Status = 'New';
        insert ChildCase;

        Case parentCaseServices = new Case();
        parentCaseServices.Subject = 'Parent Service case';
        parentCaseServices.RecordTypeId =eServiceRecordTyId;
        parentCaseServices.Status = 'Open';
        parentCaseServices.ReportingCategory__c = 'Human Failure';
        parentCaseServices.Type='Problem';
        insert parentCaseServices;

        Case ChildCaseServices = new Case();
        ChildCaseServices.ParentId = parentCaseServices.id;
        ChildCaseServices.RecordTypeId = eServiceRecordTyId;
        ChildCaseServices.Status = 'New';
        insert ChildCaseServices;

        CaseArticle articleToAttach = new CaseArticle();
        articleToAttach.CaseId = parentCase.Id;
        articleToAttach.KnowledgeArticleId = knowledgeArticle.get(0).Id;
        insert articleToAttach;

        CaseArticle articleToAttachService = new CaseArticle();
        articleToAttachService.CaseId = parentCaseServices.Id;
        articleToAttachService.KnowledgeArticleId = knowledgeArticle.get(0).Id;
        insert articleToAttachService;

        Group testGroup  = new Group(Name='2nd level support', Type='Queue');
        insert testGroup ;

        System.runAs(new User(Id=UserInfo.getUserId())) {
            QueuesObject testQueue = new QueuesObject(QueueID = testGroup.id, SObjectType = 'Case');
            insert testQueue;
        }
    }

    @isTest
    static void fillCaseInformationTest() {
        
        final String DEBUG_HERE = 'CaseTriggerTest.fillCaseInformationTest() - ';

        Map<String, Schema.RecordTypeInfo> mapCaseRecordTypeByDeveloperName = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

        // Custom metadata cannot be create in UnitTest so we expect at least two
        // with Developername "UnitTestSuccess" and "UnitTestFail"
        String sUnitTestSuccessApiName = 'UnitTestSuccess';
        String sUnitTestFailApiName = 'UnitTestFail';

        List<ErrorCaseInformation__mdt> listErrorCaseInformation = [
            SELECT MasterLabel, DeveloperName, Subject__c, Category__c, Owner__c, Type__c, RecordType__c, Status__c, Country__c, Priority__c, Origin__c, Subcategory__c
            FROM ErrorCaseInformation__mdt
            WHERE DeveloperName IN(:sUnitTestSuccessApiName, :sUnitTestFailApiName)
        ];
        System.assert(
            listErrorCaseInformation.size() == 2,
            'Expected at least two ErrorCaseInformation__mdt with Developername "' + sUnitTestSuccessApiName + '" and "' + sUnitTestFailApiName + '"'
        );

        Map<String, ErrorCaseInformation__mdt> mapErrorCaseInformationByDeveloperName = new Map<String, ErrorCaseInformation__mdt>();

        // Check if all info is available
        for (ErrorCaseInformation__mdt oErrorCaseInformation : listErrorCaseInformation) {
            System.assert(oErrorCaseInformation.Subject__c != null, 'Expect Subject__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.RecordType__c != null, 'Expect valid RecordType__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Category__c != null, 'Expect valid Category__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Type__c != null, 'Expect valid Type__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Owner__c != null, 'Expect valid Owner__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Status__c != null, 'Expect valid Status__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Country__c != null, 'Expect valid Country__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Priority__c != null, 'Expect valid Priority__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Origin__c != null, 'Expect valid Origin__c to be set on UnitTest ErrorCaseInformation__mdt');
            System.assert(oErrorCaseInformation.Subcategory__c != null, 'Expect valid Subcategory__c to be set on UnitTest ErrorCaseInformation__mdt');

            if (oErrorCaseInformation.DeveloperName == sUnitTestSuccessApiName) {
                mapErrorCaseInformationByDeveloperName.put(sUnitTestSuccessApiName, oErrorCaseInformation);
            }
            else if (oErrorCaseInformation.DeveloperName == sUnitTestFailApiName) {
                mapErrorCaseInformationByDeveloperName.put(sUnitTestFailApiName, oErrorCaseInformation);
            }
        }

        Test.startTest();
        List<Case> listCases = new List<Case>{
            new Case(
                Subject     = mapErrorCaseInformationByDeveloperName.get(sUnitTestSuccessApiName).Subject__c,
                Description = 'Success Test'
            ),
            new Case(
                Subject     = mapErrorCaseInformationByDeveloperName.get(sUnitTestFailApiName).Subject__c,
                Description = 'Fail Test'
            )
        };
        insert listCases;
        Test.stopTest();

        List<Case> listCasesCheck = [
            SELECT Id, Subject, Type, Category__c, OwnerId, RecordTypeId, Status, Country__c, Priority, Origin, Subcategory__c
            FROM Case
            WHERE Id IN :listCases
        ];

        System.debug(DEBUG_HERE + 'Cases after creation: ' + JSON.serializePretty(listCasesCheck));

        for (Case oCase : listCasesCheck) {

            String sUnitTestApiName;

            // Success
            if (oCase.Id == listCases.get(0).Id) {
                sUnitTestApiName = sUnitTestSuccessApiName;
            }
            // Failure
            else {
                sUnitTestApiName = sUnitTestFailApiName;
            }

            ErrorCaseInformation__mdt oErrorCaseInformation = mapErrorCaseInformationByDeveloperName.get(sUnitTestApiName);
            System.assertEquals(oCase.Type, oErrorCaseInformation.Type__c);
            System.assertEquals(oCase.Category__c, oErrorCaseInformation.Category__c);
            System.assertEquals(oCase.RecordTypeId, mapCaseRecordTypeByDeveloperName.get(oErrorCaseInformation.RecordType__c).recordTypeId);
            System.assertEquals(oCase.Status, oErrorCaseInformation.Status__c);
            System.assertEquals(oCase.Country__c, oErrorCaseInformation.Country__c);
            System.assertEquals(oCase.Priority, oErrorCaseInformation.Priority__c);
            System.assertEquals(oCase.Origin, oErrorCaseInformation.Origin__c);
            System.assertEquals(oCase.Subcategory__c, oErrorCaseInformation.Subcategory__c);

            String sErrorCaseOwner = oErrorCaseInformation.Owner__c.length() > 15 ? oErrorCaseInformation.Owner__c.substring(0, 15) : oErrorCaseInformation.Owner__c;

            if (sUnitTestApiName == sUnitTestSuccessApiName) {
                System.assertEquals(oCase.OwnerId, sErrorCaseOwner);
            }
            else {
                System.assertNotEquals(oCase.OwnerId, sErrorCaseOwner);
            }
        }
    }

    @isTest
    static void changeStatusChildCase() {

        test.startTest();
        Case ParentCase = [SELECT Id, Status, Subject FROM Case where Subject='Parent Service case'];
        ParentCase.Status = 'Closed - Done';
        update ParentCase;
        test.stopTest();

        Case childCase = [SELECT Id, Status, Subject, LinkKnowledgebase__c FROM Case where ParentId=:ParentCase.Id];
        System.assertEquals('Open', ChildCase.Status);
    }

    @isTest
    static void attachArticleToTechnicalCase() {

        test.startTest();
        Case ParentCase = [SELECT Id, Status, Subject FROM Case where Subject='Parent technical case'];
        ParentCase.Status = 'Closed - Done';
        update ParentCase;
        test.stopTest();

        Case childCase = [SELECT Id, Status, Subject, LinkKnowledgebase__c FROM Case where ParentId=:ParentCase.Id];
        System.assertEquals(ChildCase.LinkKnowledgebase__c != null, true);
        System.assertEquals('Open', ChildCase.Status);
    }

    @isTest
    static void attachArticleToServiceCase() {

        test.startTest();
        Id QueueID = [Select Queue.Id, Queue.Name, Queue.Type from QueueSObject WHERE Queue.Type = 'Queue' AND Queue.Name = '2nd level support' Limit 1].Queue.Id;
        Case ParentCase = [SELECT Id, Status, Subject FROM Case where Subject='Parent Service case'];
        ParentCase.Status = 'Closed - Done';
        update ParentCase;
        test.stopTest();

        Case childCase = [SELECT Id, Status, Subject, LinkKnowledgebase__c, OwnerId FROM Case where ParentId=:ParentCase.Id];
        System.assertEquals(ChildCase.LinkKnowledgebase__c != null, true);
        System.assertEquals(QueueID, ChildCase.OwnerId);
    }
}