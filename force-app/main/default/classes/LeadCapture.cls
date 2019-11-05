/**
 * Lead capture REST API
 *
 * v1.2.0   2018-07-06  Marko Schmalenbach          SOBCRM-1230
 *                                                  - Added rollback possibility with GET parameter "preventPersistence"
 *                                                  - Added return of created Lead
 * v1.3.0   2018-07-06  Marko Schmalenbach          Added proper HTTP status on failure (SOBCRM-1236)
 *
 * @see LeadCaptureTests
 */
@RestResource(urlMapping='/lead')

global with sharing class LeadCapture {

    @HttpPost
    global static Response createLead() {

        final String DEBUG_HERE = 'LeadCapture.createLead() - ';
        Savepoint eineSchritteSuruck = Database.setSavepoint();

        Response oResponse = new Response();
        RestRequest oRestRequest = RestContext.request;

        Boolean bPreventPersistence = (oRestRequest.params.get('preventPersistence') == '1');
        System.debug(DEBUG_HERE + 'PERSISTENCE: ' + (bPreventPersistence ? 'OFF' : 'ON'));

        try {

            Blob body = oRestRequest.requestBody;
            String bodyString = body.toString();

            Lead oLead = (Lead)JSON.deserialize(bodyString,Lead.class);

        	if (oLead.hasNewsletterService__c == true) {
        		oLead.NewsletterOptIn__c = 'Yes';
        		oLead.OptInDate__c       = Date.today();
        		oLead.OptInSource__c     = 'Web: Contact Form';
        	}

        	insert oLead;

            oResponse.leadid     = oLead.Id;
            oResponse.status     = 'Success';
            oResponse.message    = 'Lead was created with Salesforce Lead.Id ' + oLead.Id;
            oResponse.leadObject = oLead;
        }
        catch (Exception e) {

            oResponse.status  = 'Failure';
            oResponse.message = e.getMessage();

            RestContext.response.statusCode = 500;
        }

        if (bPreventPersistence) {

            Database.rollback(eineSchritteSuruck);
            oResponse.message += ' - nothing stored: preventPersistence active';
            System.debug(DEBUG_HERE + 'Rollback performed');
        }

        return oResponse;
    }

    global class Response {
        public String status;
        public String message;
        public String leadid;
        public Lead leadObject;
    }
}