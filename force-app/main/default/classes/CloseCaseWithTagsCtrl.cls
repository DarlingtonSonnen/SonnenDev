/*
 * CloseCaseWithTagsCtrl
 *
 * Controller for Lightning Component "CloseCaseWithTags"
 *
 * v1.0     2018-05-16  Polina Tsuban-Drobot    initial (SOBCRM-1146)
 * v1.1     2018-06-13  Polina Tsuban-Drobot    added restriction of possible Statuses according to Case Record Type (SOBCRM-1212)
 * v1.2     2018-06-22  Polina Tsuban-Drobot    added mandatory condition to add Knowledge articles to cases (SOBCRM-1215)
 * v1.3     2018-07-27  Polina Tsuban-Drobot    added Reporting Category (SOBCRM-1234)
 *
 * @see CloseCaseWithTagsCtrlTest
 */
public class CloseCaseWithTagsCtrl {

    @AuraEnabled public Case caseRecord {get;set;}
    @AuraEnabled public List<Tag> tags {get;set;}
    @AuraEnabled public List<OptionItem> statusOptions {get;set;}
    @AuraEnabled public List<OptionItem> reportingCategoryOptions {get;set;}
    @AuraEnabled public List<String> closedStatuses {get;set;}
    @AuraEnabled public Boolean isKnowledgeLinkageEnabled {get;set;}
    @AuraEnabled public Boolean hasKnowledgeArticlesRelated {get;set;}

    @AuraEnabled public String statusLabel {get;set;}
    @AuraEnabled public String reportingCategoryLabel {get;set;}
    @AuraEnabled public String closedDoneStatusName {get;set;}

    private static final String ERROR_CASE_NOT_FOUND = 'Case with Id = {0} not found.';
    private static final String CASE_OBJ = 'Case';
    private static final String STATUS_FIELD = 'Status';
    private static final String REPORTING_CATEGORY_FIELD = 'Reporting_Category__c';
    private static final String NONE_OPTION = '--None--';
    private static final String VALIDATION_EXCEPTION_KEY_WORD = 'FIELD_CUSTOM_VALIDATION_EXCEPTION';

    @AuraEnabled
    public static CloseCaseWithTagsCtrl initController(Id caseId) {
        CloseCaseWithTagsCtrl ccwtc;
        try {
            ccwtc = new CloseCaseWithTagsCtrl();
            ccwtc.caseRecord = ccwtc.retrieveCaseRecord(caseId);
            ccwtc.statusOptions = ccwtc.retrieveStatusOptions();
            ccwtc.reportingCategoryOptions = ccwtc.retrieveReportingCategoryOptions();
            ccwtc.closedStatuses = ccwtc.retrieveClosedStatuses();
            ccwtc.initializeFieldLabels();
            ccwtc.setKnowledgeLinkageEnabled();
            if (ccwtc.isKnowledgeLinkageEnabled) {
                ccwtc.tags = ccwtc.retrieveTopicsForCase(caseId);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return ccwtc;
    }

    @AuraEnabled
    public static CloseCaseWithTagsCtrl refreshController(String ctrlJSON) {
        CloseCaseWithTagsCtrl ccwtc;
        try {
            ccwtc = (CloseCaseWithTagsCtrl)JSON.deserialize(ctrlJSON, CloseCaseWithTagsCtrl.class);
            ccwtc.caseRecord = ccwtc.retrieveCaseRecord(ccwtc.caseRecord.Id);
            ccwtc.setKnowledgeLinkageEnabled(); // in case RT is changed
            if (ccwtc.isKnowledgeLinkageEnabled) {
                ccwtc.tags = ccwtc.retrieveTopicsForCase(ccwtc.caseRecord.Id);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return ccwtc;
    }

    @AuraEnabled
    public static CloseCaseWithTagsCtrl saveCaseWithTags(String ctrlJSON) {
        CloseCaseWithTagsCtrl ccwtc;
        try {
            ccwtc = (CloseCaseWithTagsCtrl)JSON.deserialize(ctrlJSON, CloseCaseWithTagsCtrl.class);

            update ccwtc.caseRecord;

            if (ccwtc.isKnowledgeLinkageEnabled && new Set<String>(ccwtc.closedStatuses).contains(ccwtc.caseRecord.Status)) {
                ccwtc.saveCaseTags(ccwtc.caseRecord.Id, ccwtc.tags);
            }
        } catch (Exception e) {
            String errorMsg = e.getMessage();
            if (errorMsg.contains(VALIDATION_EXCEPTION_KEY_WORD)){
                errorMsg = errorMsg.substringBetween(VALIDATION_EXCEPTION_KEY_WORD + ', ', ': ');
            }
            throw new AuraHandledException(errorMsg);
        }
        return ccwtc;
    }

    private Case retrieveCaseRecord(Id caseId) {
        List<Case> cases = [
            SELECT  Id,
                    Status,
                    Reporting_Category__c,
                    RecordTypeId,
                    RecordType.DeveloperName
            FROM Case
            WHERE Id = :caseId
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException(String.format(ERROR_CASE_NOT_FOUND, new List<String>{caseId}));
        }

        return cases[0];
    }

    private List<Tag> retrieveTopicsForCase(Id caseId) {
        List<Tag> tagList = new List<Tag>();

        // Get the articles attached to the case
        List<CaseArticle> caseArticles = [
            SELECT KnowledgeArticle.ArticleNumber
            FROM CaseArticle
            WHERE CaseId = :caseId
        ];

        this.hasKnowledgeArticlesRelated = !caseArticles.isEmpty();

        if (!caseArticles.isEmpty()) {
            Set<String> articlesNumbers = new Set<String>();
            for (CaseArticle caseArt : caseArticles) {
                articlesNumbers.add(caseArt.KnowledgeArticle.ArticleNumber);
            }

            // get the articles itself, by ArticleNumber as they are unique
            // (while KnowledgeArticleId is not available for building WHERE condition - SF BUG)
            Map<Id,KnowledgeArticleVersion> knowledgeArticleVersions = new Map<Id,KnowledgeArticleVersion>([
                SELECT Id, Title
                FROM KnowledgeArticleVersion
                WHERE ArticleNumber IN :articlesNumbers
            ]);

            if (!knowledgeArticleVersions.isEmpty()) {
                // retrieve the topics that already exist on case, for setting isChosen field on Tag instance
                List<TopicAssignment> topicAssignmentsOnCase = [
                    SELECT Id, TopicId
                    FROM TopicAssignment
                    WHERE EntityId = :caseId
                ];

                Set<Id> existingTopicsIdSet = new Set<Id>();
                for (TopicAssignment ta : topicAssignmentsOnCase) {
                    existingTopicsIdSet.add(ta.TopicId);
                }

                // retrieve topics from related knowledge articles
                List<TopicAssignment> topicAssignments = [
                    SELECT Id, TopicId, Topic.Name, EntityId
                    FROM TopicAssignment
                    WHERE EntityId IN :knowledgeArticleVersions.keySet()
                ];

                for (TopicAssignment ta : topicAssignments) {
                    tagList.add(new Tag(ta, existingTopicsIdSet.contains(ta.TopicId)));
                }
            }
        }

        return tagList;
    }

    private List<OptionItem> retrieveStatusOptions() {
        List<OptionItem> statusOptions = retrieveOptionsUniversally(STATUS_FIELD);
        return statusOptions;
    }

    private List<OptionItem> retrieveReportingCategoryOptions() {
        List<OptionItem> reportingCategoryOptions = new List<OptionItem>();
        reportingCategoryOptions.add(new OptionItem('', NONE_OPTION));
        reportingCategoryOptions.addAll(retrieveOptionsUniversally(REPORTING_CATEGORY_FIELD));
        return reportingCategoryOptions;
    }

    private List<OptionItem> retrieveOptionsUniversally(String fieldApiName) {
        Map<String,String> resultMap = new Map<String,String>();
        try {
            // workarund for getting session id from lightning component
            // for now we cannot simply use UserInfo.getSessionId() due
            // to security & bug issues. They say it's fixed on Winter'18,
            // but it's already Summer'18 and still nothing =(

            String sessionId;
            if (Test.isRunningTest()) {
                sessionId = 'test';
            } else {
                String content = Page.UserSessionIdForLightningPage.getContent().toString();
                Integer s = content.indexOf('Start_Of_Session_Id') + 'Start_Of_Session_Id'.length();
                Integer e = content.indexOf('End_Of_Session_Id');
                sessionId = content.substring(s, e);
            }

            // do request to SF to get available picklist values for our Case Racord Type
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(System.Url.getSalesforceBaseURL().toExternalForm() +
                '/services/data/v42.0/ui-api/object-info/' + CASE_OBJ + '/picklist-values/' + this.caseRecord.RecordTypeId + '/' + fieldApiName);
            request.setHeader('Authorization', 'OAuth ' + sessionId);
            HttpResponse response = new Http().send(request);

            // parse results and prepare map
            Map<String,Object> responceBodyMap = (Map<String,Object>)JSON.deserializeUntyped(response.getBody());
            List<Object> listOfPicklistItems = (List<Object>)ConstraintValidator.resolvePath(responceBodyMap, 'values');
            for (Object picklistItem : listOfPicklistItems) {
                Map<String,Object> picklistItemAsMap = (Map<String,Object>)picklistItem;
                resultMap.put((String)picklistItemAsMap.get('value'), (String)picklistItemAsMap.get('label'));
            }

        } catch(Exception e) {
            System.debug('Didn\'t manage to get ' + fieldApiName + ' for Case record type "' + this.caseRecord.RecordType.DeveloperName + '". Error is ' + e.getMessage());

            // in case of failure, display all statuses
            List<Schema.PicklistEntry> statusesPle = Schema.getGlobalDescribe()
                .get(CASE_OBJ)
                .getDescribe()
                .fields.getMap()
                .get(fieldApiName)
                .getDescribe()
                .getPicklistValues();
            for (Schema.PicklistEntry picklistItem : statusesPle) {
                resultMap.put(picklistItem.getValue(), picklistItem.getLabel());
            }
        }

        List<OptionItem> optionsList = new List<OptionItem>();
        for (String key : resultMap.keySet()) {
            optionsList.add(new OptionItem(key, resultMap.get(key)));
        }

        return optionsList;
    }

    private List<String> retrieveClosedStatuses() {
        List<CaseStatus> caseStatuses = [
            SELECT Id, ApiName
            FROM CaseStatus
            WHERE IsClosed = TRUE
        ];
        List<String> closedStatuses = new List<String>();
        for (CaseStatus cs : caseStatuses) {
            closedStatuses.add(cs.ApiName);
        }
        return closedStatuses;
    }

    private void initializeFieldLabels() {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(CASE_OBJ).getDescribe().fields.getMap();
        this.statusLabel = fieldMap.get(STATUS_FIELD).getDescribe().getLabel();
        this.reportingCategoryLabel = fieldMap.get(REPORTING_CATEGORY_FIELD).getDescribe().getLabel();
        this.closedDoneStatusName = 'Closed - Done';
    }

    private void setKnowledgeLinkageEnabled() {
        Set<String> allowedRecordTypes = CloseCaseWithTagsRecordTypes__c.getAll().keySet();
        this.isKnowledgeLinkageEnabled = !Test.isRunningTest() ? allowedRecordTypes.contains(this.caseRecord.RecordType.DeveloperName) : true;
    }

    private void saveCaseTags(Id caseRecordId, List<Tag> tags) {
        List<TopicAssignment> tagsToUpsert = new List<TopicAssignment>();
        List<TopicAssignment> tagsToDelete = new List<TopicAssignment>();

        Set<Id> topicsIdToDelete = new Set<Id>();

        for (Tag t : tags) {
            if (t.isChosen) {
                TopicAssignment ta = new TopicAssignment();
                ta.EntityId = caseRecordId;
                ta.TopicId = t.topic.TopicId;
                tagsToUpsert.add(ta);
            } else {
                topicsIdToDelete.add(t.topic.TopicId);
            }
        }

        tagsToDelete = [
            SELECT Id
            FROM TopicAssignment
            WHERE EntityId = :caseRecordId
                AND TopicId IN :topicsIdToDelete
        ];

        upsert tagsToUpsert;
        delete tagsToDelete;
    }

    public class Tag {
        @AuraEnabled public TopicAssignment topic {get;set;}
        @AuraEnabled public Boolean isChosen {get;set;}

        public Tag(TopicAssignment topicAssignment, Boolean isChosen) {
            this.topic = topicAssignment;
            this.isChosen = isChosen;
        }
    }

    public class OptionItem {
        @AuraEnabled public String value {get;set;}
        @AuraEnabled public String label {get;set;}

        public OptionItem(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}