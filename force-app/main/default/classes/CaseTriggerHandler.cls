/**
 * Case Trigger Handler
 *
 * Changelog
 * ---------
 * v1.0.0   ?           Igor Savchenko          Initial version (SOBCRM-1038)
 * v1.1.0   2018-01-29  Bartosz Jarmolinski     Added logic for new RecordType = Technical Support Problem: variable
 *                                              problemRecordTypeID2 and Scenario 1.1
 * v1.2.0   2018-06-25  Alexey Yamaev           Administration of Error cases (SOBCRM-1195, SOBCRM-1225)
 * v1.2.1   2018-07-24  Marko Schmalenbach      Fixed error case logic to compare Subject (SOBCRM-1237)
 * v1.2.2	2018-07-26	Bartosz Jarmolinski		added 'if (!incident.IsClosed)' to scenario 1.0 and 1.1 
 * 												to prevent reopenning closed Tech Support Cases
 *
 * v1.3     2019-08-23  Michael Muchow          Added TriggerCase_mdt to disable processes in Live system
 * v1.3.1   2019-08-29  Antonio Romero          Refactor fillCaseInformation
 * v1.3.2   2019-09-13  Michael Muchow          remove of Method copySolutionsToRelatedIncidentsAndOpenIncidents(), is replaced by Method attachArticlesToChildCases()
 *                                              remove of Helpermethods filterSObjects(), getAllNeededCases(), getAllNeededSolutions()
 *                                              remove of fillCaseInformationRefactor(), switching back to old Method fillCaseInformation()
 *                                              remove of Method CaseTriggerHandler() for creating trigger.New Array
 *                                              added trigger.New List handling to Method to switch from old trigger.New Array
 * 
 * @see CaseTriggerTest
 */
public class CaseTriggerHandler extends TriggerHandler {

    public override void beforeInsert() {
        this.fillCaseInformation();
        this.breakEmailLoop();
    }

    public override void afterUpdate() {
        this.attachArticlesToChildCases();
    }

    public override void afterInsert() {
    }

    public override void beforeUpdate() {
    }

    /**
     * Adjust Case information according to configurations in
     * custom metadata ErrorCaseInformation__mdt
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-1195
     * @see https://interaktiv.jira.com/browse/SOBCRM-1237
     */

    private void fillCaseInformation() {
        TriggerCase__mdt triggerSettings = [SELECT Active__c FROM TriggerCase__mdt WHERE Label = 'fill Case Information' LIMIT 1];

        if (triggerSettings.Active__c == true || Test.isRunningTest()) {

            List<Case> triggerNewCaseList = (List<Case>) Trigger.new;

            final String DEBUG_HERE = 'CaseTriggerHandler.fillCaseInformation() - ';

            List<ErrorCaseInformation__mdt> errorCaseInfoList = [
                    SELECT MasterLabel, Subject__c, Category__c, Owner__c, Type__c, RecordType__c, Status__c, Country__c, Priority__c, Origin__c, Subcategory__c
                    FROM ErrorCaseInformation__mdt
            ];

            Map<String, ErrorCaseInformation__mdt> mapErrorCaseInformationBySubject = new Map<String, ErrorCaseInformation__mdt>();

            for (ErrorCaseInformation__mdt errorCaseInfo : errorCaseInfoList) {
                mapErrorCaseInformationBySubject.put(errorCaseInfo.Subject__c, errorCaseInfo);
            }

            Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
            Map<String, Schema.SObjectField> caseFieldMap = Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();

            Map<Id, List<Case>> mapOwnerIdToCases = new Map<Id, List<Case>>();

            ErrorCaseInformation__mdt oErrorCaseInfo;

            String sSObjectUserPrefix = User.SObjectType.getDescribe().getKeyPrefix();
            String sSObjectGroupPrefix = Group.SObjectType.getDescribe().getKeyPrefix();

            for (Case oCase : triggerNewCaseList) {

                if (String.isBlank(oCase.Subject)) {
                    continue;
                }

                // Get configuration by Case Subject
                oErrorCaseInfo = mapErrorCaseInformationBySubject.get(oCase.Subject);

                if (oErrorCaseInfo != null) {

                    System.debug(DEBUG_HERE + 'Found matching ErrorCaseInformation__mdt ' + oErrorCaseInfo + ' by Subject for Case: ' + JSON.serializePretty(oCase.getPopulatedFieldsAsMap()));

                    if (!String.isBlank(oErrorCaseInfo.Type__c)) {
                        String type = getValidCasePicklistValue('Type', oErrorCaseInfo.Type__c, caseFieldMap);
                        if (type != null) {
                            System.debug(DEBUG_HERE + 'Set Type: ' + type);
                            oCase.Type = type;
                        }
                    }

                    if (!String.isBlank(oErrorCaseInfo.Category__c)) {
                        String category = getValidCasePicklistValue('Category__c', oErrorCaseInfo.Category__c, caseFieldMap);
                        if (category != null) {
                            System.debug(DEBUG_HERE + 'Set Category__c: ' + category);
                            oCase.Category__c = category;
                        }
                    }

                    String sId15 = '';

                    // if errorCaseInfo.Owner__c exists and ID is valid we add Id to List and then will check if it related to real User/Queue
                    if (!String.isBlank(oErrorCaseInfo.Owner__c)) {


                        if ((oErrorCaseInfo.Owner__c instanceof Id)
                                && !String.isBlank(sId15 = oErrorCaseInfo.Owner__c.substring(0, 15)) // convert to 15-digit ID
                                && (sId15.startsWith(sSObjectUserPrefix) || sId15.startsWith(sSObjectGroupPrefix))) {

                            if (!mapOwnerIdToCases.containsKey(sId15)) {
                                mapOwnerIdToCases.put(sId15, new List<Case>());
                            }

                            mapOwnerIdToCases.get(sId15).add(oCase);
                            System.debug(DEBUG_HERE + 'Added Owner__c ID ' + sId15 + ' for later check');
                        } else {
                            System.debug(DEBUG_HERE + 'Invalid ID for OwnerId from ErrorCaseInformation__mdt: ' + oErrorCaseInfo.Owner__c);
                        }
                    }

                    // added new fields and values based on new Global Service App, static Values from Metadata and not "dynamic" like the other ones
                    oCase.Status = oErrorCaseInfo.Status__c;
                    oCase.Country__c = oErrorCaseInfo.Country__c;
                    oCase.Priority = oErrorCaseInfo.Priority__c;
                    oCase.Origin = oErrorCaseInfo.Origin__c;
                    oCase.Subcategory__c = oErrorCaseInfo.Subcategory__c;

                    if (!String.isBlank(oErrorCaseInfo.RecordType__c) && rtMap.get(oErrorCaseInfo.RecordType__c) != null) {
                        oCase.RecordTypeId = rtMap.get(oErrorCaseInfo.RecordType__c).getRecordTypeId();
                        System.debug(DEBUG_HERE + 'Set RecordTypeId: ' + oCase.RecordTypeId);
                    }
                }
            }

            if (!mapOwnerIdToCases.isEmpty()) {

                Map<Id, User> mapUsers = new Map<Id, User>([SELECT Id FROM User WHERE Id IN :mapOwnerIdToCases.keySet()]);
                Map<Id, Group> mapGroups = new Map<Id, Group>([SELECT Id FROM Group WHERE Type = 'Queue' AND Id IN :mapOwnerIdToCases.keySet()]);

                // Set found User/Group IDs to the corresponding Cases
                for (Id sUserOrGroupId : mapOwnerIdToCases.keySet()) {

                    List<Case> listCases = mapOwnerIdToCases.get(sUserOrGroupId);

                    // User/Group ID not found
                    if (!mapUsers.containsKey(sUserOrGroupId) && !mapGroups.containsKey(sUserOrGroupId)) {
                        System.debug(DEBUG_HERE + 'User or group ID ' + sUserOrGroupId + ' could not be found and therefore won\'t be set for these cases: ' + listCases);
                        continue;
                    }

                    for (Case oCase : listCases) {
                        oCase.OwnerId = sUserOrGroupId;
                        System.debug(DEBUG_HERE + 'Set OwnerId ' + oCase.OwnerId + ' for Case');
                    }
                }
            }

            System.debug(DEBUG_HERE + 'Cases: ' + JSON.serializePretty(triggerNewCaseList));
        }
    }

    private String getValidCasePicklistValue(String fieldName, String value, Map<String, Schema.SObjectField> caseFieldMap) {
        Schema.SObjectField field = caseFieldMap.get(fieldName);
        if (field != null) {
            for (Schema.PickListEntry s : field.getDescribe().getPicklistValues()) {
                if (s.getValue() == value || s.getLabel() == value) {
                    return s.getValue();
                }
            }
        }
        return null;
    }

    /**
     * Method to Break Out Of Office Email Loop
     * sets checkbox on duplicate case to prevent Case Notification Email
     * Test Class CaseTriggerHandlerBreakEmailLoopTest()
     */
    private void breakEmailLoop() {
        //get Custom Metadata for Method
        TriggerCase__mdt triggerSettings = [SELECT Active__c FROM TriggerCase__mdt WHERE Label = 'break Email Loop' LIMIT 1];

        // check if Method is active in Custom Metadata
        if (triggerSettings.Active__c == true || Test.isRunningTest()) {
            List<Case> triggerNewCaseList = (List<Case>) Trigger.new;

            // initialize Map & Set
            Map<String, Case> caseMap = new Map<String, Case>();
            Set<String> suppliedEmailSet = new Set<String>();

            // loop trough Records from Trigger.new
            for (Case mapCase : triggerNewCaseList) {
                // check if SuppliedEmail and correct Case Origin is given
                // put data into Map and Set
                if (String.isNotBlank(mapCase.SuppliedEmail) && mapCase.Origin == 'Email') {
                    caseMap.put(mapCase.SuppliedEmail, mapCase);
                    suppliedEmailSet.add(mapCase.SuppliedEmail);
                }
            }
            // check if data was put in Map and Set
            // loop trough Cases with the same SuppliedEmail, Case Origin and Cases which are created in the last 5 Minutes
            // if duplicate Case was found set checkbox to break Email Loop
            if (!caseMap.isEmpty() && !suppliedEmailSet.isEmpty()) {
                for (Case checkCase : [SELECT Id, Subject, Description, SuppliedEmail FROM Case WHERE SuppliedEmail IN:suppliedEmailSet AND CreatedDate >= :Datetime.now().addMinutes(-5) AND Case.Origin = 'Email']) {
                    if (checkCase.Subject == caseMap.get(checkCase.SuppliedEmail).get('Subject') && checkCase.Description == caseMap.get(checkCase.SuppliedEmail).get('Description') && checkCase.Id != caseMap.get(checkCase.SuppliedEmail).get('Id')) {
                        Case updateCase = caseMap.get(checkCase.SuppliedEmail);
                        updateCase.BreakLoop__c = true;
                        updateCase.Status = 'Closed - Duplicate';
                    }
                }
            }
        }
    }

    private void attachArticlesToChildCases() {
        //get Custom Metadata for Method
        TriggerCase__mdt triggerSettings = [SELECT Active__c FROM TriggerCase__mdt WHERE Label = 'attach articles to child' LIMIT 1];

        // check if Method is active in Custom Metadata
        if (triggerSettings.Active__c == true || Test.isRunningTest()) {
            List<Case> triggerNewCaseList = (List<Case>) Trigger.new;

            Id technicalRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Technical Support Case').getRecordTypeId();
            Id eServiceRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('eServices').getRecordTypeId();
            Id QueueID = [SELECT Queue.Id, Queue.Name, Queue.Type FROM QueueSobject WHERE Queue.Type = 'Queue' AND Queue.Name = '2nd level support' LIMIT 1].Queue.Id;

            String CaseType = 'Problem';
            Set<Id> ParentCaseIds = new Set<Id>();
            Map<Id, String> mapParentArticles = new Map<Id, String>();
            List<CaseArticle> childCaseArticlesToInsert = new List<CaseArticle>();
            List<Case> childCasesToUpdate = new List<Case>();
            

            //Get the ids of the parent cases
            for (Case oCase : triggerNewCaseList) {
                Case oldMap = (Case) Trigger.oldMap.get(oCase.Id);
                if (oCase.RecordTypeId == technicalRecordTypeId && oCase.Type == CaseType && oCase.Status.contains('Closed') && !oldMap.Status.contains('Closed')) {
                    mapParentArticles.put(oCase.Id, oCase.Status);
                    ParentCaseIds.add(oCase.Id);
                } else if (oCase.RecordTypeId == eServiceRecordTypeId && oCase.Status.contains('Closed') && !oldMap.Status.contains('Closed')) {
                    mapParentArticles.put(oCase.Id, oCase.Status);
                    ParentCaseIds.add(oCase.Id);
                }
            }

            //Get articles related to the parent case
            List<CaseArticle> caseArticles = [SELECT CaseId, KnowledgeArticleId FROM CaseArticle WHERE CaseId IN :ParentCaseIds];
            List<Case> childCases = [SELECT Id, ParentId, Subject, Status, RecordTypeId FROM Case WHERE ParentId IN :ParentCaseIds];

            for (Case childCase : childCases) {
                //Attach article to child cases and update status of child for 'Technical Support case' and eServices record type
                if (childCase.RecordTypeId == technicalRecordTypeId || childCase.RecordTypeId == eServiceRecordTypeId) {
                    for (CaseArticle ca : caseArticles) {
                        if (ca.CaseId == childCase.ParentId) {
                            CaseArticle childCaseArticle = ca.clone();
                            childCaseArticle.CaseId = childCase.Id;
                            childCaseArticlesToInsert.add(childCaseArticle);
                        }
                    }
                    // Change the status of the Child Case to Open WHEN Child case is not closed and parent case status is closed - Done
                    if (mapParentArticles.get(childCase.ParentId) == 'Closed - Done') {
                        if (childCase.Status != 'Closed - Done' && childCase.Status != 'Closed - Cancelled' && childCase.Status != 'Closed - Duplicate') {
                            childCase.Status = 'Open';
                        }
                    }

                    //Update the case owner of child cases when parent is closed for cases with 'eServices' record type and attach articles from the parent case
                    if (childCase.RecordTypeId == eServiceRecordTypeId) {
                        childCase.OwnerId = QueueID;
                    }
                    childCasesToUpdate.add(childCase);
                }
            }


            if (childCasesToUpdate.size() > 0) {
                update childCasesToUpdate;
            }

            if (childCaseArticlesToInsert.size() > 0) {
                insert childCaseArticlesToInsert;
            }
        }
    }
}