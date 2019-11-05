/**
 * Created by m.muchow on 11.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 * - Update 02.07.2019 MMuchow
 * - changed line 59 from normal insert to Database.insert(newLog, false) to insert log even if whole process is failing
 */
@RestResource(UrlMapping='/assetEndpointAPI/*')
global with sharing class AssetEndpointV3 {

    @HttpPost
    global static void handlePost() {
        // handle POST request
        RestRequest caRequest = RestContext.request;

        // create String from request
        Blob body = caRequest.requestBody;
        String sRequestAsJSON = body.toString();

        try {
            // assign String to private String
            AssetEndpointV3.assetProcessor aAssetProcessor = new AssetEndpointV3.assetProcessor(sRequestAsJSON);
            // process request
            aAssetProcessor.process();
            // create log for every JSON from CA
            createLog(sRequestAsJSON, '');
        } catch(Exception e) {
            // create log for every JSON from CA
            createLog(sRequestAsJSON, e.getMessage());
        }
    }

    global class assetProcessor {
        private String sRequestJSON;
        private Map<String, Object> requestMap = new Map<String, Object>();
        private Id assetId;

        public assetProcessor(String requestString) {
            this.sRequestJSON = requestString;
        }

        public void process() {
            // clean up JSON
            this.sRequestJSON = this.sRequestJSON.removeStart('[');
            this.sRequestJSON = this.sRequestJSON.removeEnd(']');
            // deserialize JSON to map
            this.requestMap = (Map<String, Object>) JSON.deserializeUntyped(this.sRequestJSON);
            // call class to process request
            this.assetId = AssetEndpointRiverbox.createRiverbox(this.requestMap, this.sRequestJSON);
            // call class to check if cases needs to be created
            if (this.assetId != null) {
                AssetEndpointCases.checkForCases(this.requestMap, this.assetId);
            }
        }
    }

    private static void createLog(String sRequestAsJSON, String error) {
        Log__c newLog = new Log__c();

        if (String.isBlank(error)) {
            newLog.Message__c = sRequestAsJSON;
        } else if (String.isNotBlank(error)) {
            newLog.Message__c = 'Error: '+error+'\n'+'\n'+sRequestAsJSON;
        }
        newLog.Origin__c = 'Commissioning Assistant';
        newLog.Timestamp__c = Datetime.now();

        Database.insert(newLog, false) ;
    }
}