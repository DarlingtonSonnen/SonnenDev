@isTest
public class TermsAndConditionsEndpoint_Testv2 {

    @testSetup
    static void createTestData() { 
        
        // call picklist method in order to get dynamic picklist values
        //List<String> typeOptions = getPickListValuesIntoList();
        List<String> typeOptions = new List<String>{'General TnC', 'Privacy policy'};

        // create terms and conditions with specific type
        List<TermsAndConditions__c> tnList = new List<TermsAndConditions__c>();
        TermsAndConditions__c tnc = new TermsAndConditions__c(Name='Tnc1', Type__c = typeOptions[0], Country__c = 'DE', Language__c = 'DE', Current__c = true);
        TermsAndConditions__c tn1 = new TermsAndConditions__c(Name='Tnc2', Type__c = typeOptions[1], Country__c = 'DE', Language__c = 'DE', Current__c = true);
        
        tnList.add(tnc);
        tnlist.add(tn1);
        insert tnList;
        
        System.debug(tnc);
        // create attachments
        List<Attachment> attList = new List<Attachment>();
        String s = 'Attachment body';
        
        Attachment att = new Attachment();
        att.Name = 'General terms and conditions';
        att.Body = Blob.valueOf(s);
        att.ParentId = tnc.Id;
        attList.add(att);
        
        Attachment at1 = new Attachment();
        at1.Name = 'TnC Duplicate';
        at1.Body = Blob.valueOf(s);
        at1.ParentId = tnc.Id;
        attList.add(at1);
        
        Attachment at2 = new Attachment();
        at2.Name = 'Privacy policy';
        at2.Body = Blob.valueOf(s);
        at2.ParentId = tn1.Id;
        attList.add(at2);
        insert attList;
    }
    
    @isTest
    static void testMethod1() {

        List<String> typeOptions = new List<String>{'General TnC', 'Privacy policy'};
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'GET';
        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/GetDocument/v2';
        req.params.put('type', typeOptions[0]);
        req.params.put('country', 'DE');
        req.params.put('language', 'DE');

        System.debug(req.requestURI);
        RestContext.request = req;
        RestContext.response = res;

        String type = req.params.get('type');
        String country = req.params.get('country');
        String language = req.params.get('language');

        Id parentId = [SELECT Id FROM TermsAndConditions__c WHERE Type__c = :type AND Country__c = :country AND Language__c = :language AND Current__c = true LIMIT 1].Id;
        Attachment a = [SELECT Body FROM Attachment WHERE ParentId = :parentId LIMIT 1];

        String bodyString = TermsAndConditionsEndpointv2.GetDocument();
        Blob b = EncodingUtil.base64Decode(bodyString);
        System.assertEquals(b, a.Body);
    }

    @isTest
    static void testMethod2() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'GET';
        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/GetDocument/v2';
        req.params.put('type', 'General TnC');
        req.params.put('language', 'DE');

        System.debug(req.requestURI);
        RestContext.request = req;
        RestContext.response = res;

        String bodyString = TermsAndConditionsEndpointv2.GetDocument();
        System.assertEquals(400, res.statusCode);
    }
}