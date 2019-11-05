/* By Bartosz Jarmolinski
    * code coverage by TermsAndConditionsEndpoint_Testv2
    *
    * Version 2.0 (2018-09-12) by Bartosz
    * - added country parameter
    * - added language parameter
    * - added 400 code response if any of the parameter is not present
 */


@RestResource (urlMapping='/GetDocument/v2/*')
global with sharing class TermsAndConditionsEndpointv2 {
    
    @HttpGet
    global static String GetDocument() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String bodyString; // response string

        String type = req.params.get('type');
        String country = req.params.get('country');
        String language = req.params.get('language');

        System.debug(type);
        System.debug(country);
        System.debug(language);

        if (String.isBlank(type) || String.isBlank(country) || String.isBlank(language)) {
            bodyString = 'One or more parameters are missing in the request query: type, country or language';
            res.statusCode = 400;
            return bodyString;
        }

        Id parentId = [SELECT Id FROM TermsAndConditions__c WHERE Type__c = :type AND Country__c = :country AND Language__c = :language
                        AND Current__c = true LIMIT 1].Id;

        System.debug(parentId);
        Attachment doc = [SELECT Body FROM Attachment WHERE ParentId = :parentId LIMIT 1];

        if (doc != null) {
            bodyString = EncodingUtil.base64Encode(doc.Body);
        } else {
            res.statusCode = 400;
            bodyString = 'Document not found';
        }

        return bodyString;
    }
}