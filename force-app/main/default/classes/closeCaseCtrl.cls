/**
 * Created by a.romero on 07/08/2019.
 *
 * Controller for the LWC closeCase related with the closeCase Aura Component
 */

public with sharing class closeCaseCtrl {

    @AuraEnabled(Cacheable=true)
    public static List<String> getClosedStatus() {
        List<String> closedStatus = new List<String>();
        for(CaseStatus cs: [SELECT Id, ApiName FROM CaseStatus WHERE IsClosed = TRUE]){
            closedStatus.add(cs.ApiName);
        }
        return closedStatus;
    }

    @AuraEnabled
    public static Boolean isArticleRelated(Id caseId) {
        system.debug('CASE ID: ' + caseId);
        List<CaseArticle> caseArticles = [
                SELECT KnowledgeArticle.ArticleNumber
                FROM CaseArticle
                WHERE CaseId = :caseId
        ];

        return  !caseArticles.isEmpty();
    }
}