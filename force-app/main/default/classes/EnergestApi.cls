/**
 * Energest API
 *
 * v1.0.0   2019-02-28  Marko Schmalenbach          Initial
 *
 * @see https://interaktiv.jira.com/browse/SOBCRM-1321
 */
public without sharing class EnergestApi {

    private static final String DEBUG_HEADER = 'EnergestApi.';

    private static final Integer SERVER_SEC_OFFSET = 60;

    @TestVisible
    private static Map<String, GeneralSetting__mdt> mapSettings;

    public static final String API_HOST    = (String)getSetting('EnergestApiHost', 'TextValue__c', true);
    public static final String API_SECRET  = (String)getSetting('EnergestApiSecret', 'TextValue__c', true);
    public static final String RESELLER_ID = (String)getSetting('EnergestResellerId', 'TextValue__c', true);

    public String lastError { get; private set; }

    //====================================================================================
    // Endpoints
    //====================================================================================
    /**
     * API query POD list
     *
     * @param updatedAfterTimestamp
     * @param pageNumber
     * @param rowsPerPage
     *
     * @return
     */
    public EnergestApi.Response apiGetPodList(Long updatedAfterTimestamp, Integer pageNumber, Integer rowsPerPage) {

        final String DEBUG_HERE = DEBUG_HEADER + 'apiGetPodList() - ';

        if (pageNumber == null) {
            pageNumber = 1;
        }
        if (rowsPerPage == null) {
            rowsPerPage = 50;
        }

        String sUrl = API_HOST + '/api/sonnenV1/' + RESELLER_ID + '/pointsofdeliveryextl/' + updatedAfterTimestamp + '/?pagenumber=' + pageNumber + '&rowsperpage=' + rowsPerPage;
        System.debug(DEBUG_HERE + 'Callout to ' + sUrl);

        Payload oPayload = new Payload();
        oPayload.updated_Date = updatedAfterTimestamp;

        EnergestApi.Response oResponse;

        try {

            oResponse = this.callout(sUrl, oPayload, 'GET');

            System.debug(DEBUG_HERE + 'Response: ' + oResponse);

            if (oResponse.success) {

                List<Object> listObjects = (List<Object>)JSON.deserializeUntyped(oResponse.body);
                //List<EnergestEntityPod.EnergestPod> listSourcePods = (List<EnergestEntityPod.EnergestPod>)JSON.deserialize(oResponse.body, List<EnergestEntityPod.EnergestPod>.class);

                List<EnergestEntityPod> listEnergestEntityPods = new List<EnergestEntityPod>();

                if (!listObjects.isEmpty()) {
                    for (Object oObject : listObjects) {
                        EnergestEntityPod oEnergestEntityPod = new EnergestEntityPod(JSON.serialize(oObject));
                        listEnergestEntityPods.add(oEnergestEntityPod);
                    }
                }

                oResponse.result = listEnergestEntityPods;
            }
        }
        catch (Exception e) {
            this.handleException(e);
        }

        return oResponse;
    }

    //====================================================================================
    // Helper
    //====================================================================================
    /**
     * Get a setting
     *
     * @param developerName
     * @param fieldName
     * @param required
     *
     * @return
     */
    private static Object getSetting(String developerName, String fieldName, Boolean required) {

        if (mapSettings == null) {

            mapSettings = new Map<String, GeneralSetting__mdt>();

            for (GeneralSetting__mdt oSetting : [SELECT DeveloperName, BooleanValue__c, TextValue__c FROM GeneralSetting__mdt WHERE DeveloperName LIKE 'Energest%']) {
                mapSettings.put(oSetting.DeveloperName, oSetting);
            }
        }

        if (required && (!mapSettings.containsKey(developerName) || (fieldName == 'TextValue__c' && String.isBlank(mapSettings.get(developerName).TextValue__c)))) {
            throw new EnergestApiException('Setting "' + developerName + '" is empty');
        }

        GeneralSetting__mdt oSetting = mapSettings.get(developerName);

        return oSetting.get(fieldName);
    }

    /**
     * Handle an exception
     *
     * @param e
     */
    private void handleException(Exception e) {
        this.lastError = e.getMessage() + ' (' + e.getStackTraceString() + ')';
    }

    //====================================================================================
    // Communication
    //====================================================================================
    /**
     * Make a callout
     *
     * @param url
     * @param method
     */
    public EnergestApi.Response callout(String url, Payload oPayload, String method) {

        final String DEBUG_HERE = DEBUG_HEADER + 'callout() - ';

        // Create JWT
        String sJwt = EnergestApi.generateJwt(oPayload);

        Map<String, String> mapHeaders = new Map<String, String>();
        mapHeaders.put('jwt', sJwt);

        RESTClient oRestClient = new RESTClient(url, method, mapHeaders);

        return new EnergestApi.Response(oRestClient.response);
    }

    /**
     * Generate a JSON Web Token with payload
     *
     * @return
     */
    private static String generateJwt(EnergestApi.Payload payload) {

        final String DEBUG_HERE = DEBUG_HEADER + 'generateJwt() - ';
        List<String> listJwtParts = new List<String>();

        //--------------------------------
        // Header
        //--------------------------------
        Map<String, String> mapHeader = new Map<String, String>{
            'alg' => 'HS256'
        };
        String sHeaderJson = JSON.serialize(mapHeader);
        listJwtParts.add(base64UrlEncode(Blob.valueOf(sHeaderJson)));

        //--------------------------------
        // Body
        //--------------------------------
        Map<String, Object> mapClaims = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(payload, true));

        // Onboard JWT for generation of "jti" and "iat"
        Auth.JWT oJwt = new Auth.JWT();
        Map<String, Object> mapClaimsStandard = (Map<String, Object>)JSON.deserializeUntyped(oJwt.toJSONString());
        mapClaims.put('jti', mapClaimsStandard.get('jti'));
        mapClaims.put('iat', Integer.valueOf(mapClaimsStandard.get('iat')) - SERVER_SEC_OFFSET);

        String sPayloadJson = JSON.serialize(mapClaims, true);
        System.debug(DEBUG_HERE + 'Payload: ' + sPayloadJson);

        listJwtParts.add(base64UrlEncode(Blob.valueOf(sPayloadJson)));

        //--------------------------------
        // Signature
        //--------------------------------
        Blob blobSignature = Crypto.generateMac(
            'hmacSHA256',
            Blob.valueOf(String.join(listJwtParts, '.')),
            Blob.valueOf(API_SECRET)
        );
        listJwtParts.add(base64UrlEncode(blobSignature));
        String sJwt = String.join(listJwtParts, '.');

        System.debug(DEBUG_HERE + 'JWT: ' + sJwt);

        return sJwt;
    }

    /**
     * Encode base64
     *
     * @param input
     *
     * @return
     */
    private static String base64UrlEncode(Blob input){

        String output = EncodingUtil.base64Encode(input);

        output = output.replace('+', '-');
        output = output.replace('/', '_');

        while ( output.endsWith('=')){
            output = output.substring(0,output.length()-1);
        }
        return output;
    }

    /**
     * API Payload
     */
    private class Payload {

        public Long reseller_id {
            get {
                if (reseller_id == null) {
                    reseller_id = Long.valueOf(EnergestApi.RESELLER_ID);
                }
                return reseller_id;
            }
            set;
        } // always

        public String pod_Id { get; set; } //same as Pods_Extended parameter (null for other APIs)

        public Long updated_Date { get; set; } //timestamp, same as Pods_List parameter (null for other APIs)
    }

    /**
     * Response
     */
    public class Response {

        public Boolean success { get; private set; }
        public String body { get; private set; }
        public HttpResponse responseHttp { get; private set; }

        public Object result;

        public Response(HttpResponse httpResponse) {

            this.success = (httpResponse.getStatusCode() >= 200 && httpResponse.getStatusCode() < 300);
            this.body = httpResponse.getBody();
            this.responseHttp = httpResponse;
        }
    }

    public class EnergestApiException extends Exception {}
}