/**
 * Lumenaza Change object
 *
 * Changelog
 * ---------
 *
 * v1.1.0-2018-04-06 (marko@die-interaktiven.de)
 * - Revised with lumenazaFields as Map<String,Object>
 *
 * v1.0.1 (MSB 2017-01-02)
 * - Fix: new_value has to be set to empty string if null. Otherwise empty
 *   values would not be transmitted as null values are stripped from JSON.
 *
 * v1.0.0 (2016-12-14)
 * - Initial
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version v1.1.0-2018-04-06
 */
public class LumenazaChange extends LumenazaObject {

    private static final String DEBUG_HEADER = 'LumenazaChange.';

    private static LumenazaApi lumenazaApi;

    private LumenazaContractChange__c LumenazaContractChange;

    /**
     * Instantiate LumenazaContract by contract
     */
    public LumenazaChange(LumenazaContractChange__c change) {

        String sDebugHere = DEBUG_HEADER + 'LumenazaChange() - ';
        System.debug(sDebugHere + 'Init change from LumenazaContractChange__c: ' + change);

        this.initLumenazaFields();
        this.sObjectId = change.Id;
        this.LumenazaContractChange = change;

        this.setLumenazaFieldsFromObject(change);
    }

    /**
     * Init LumenazaFields
     */
    protected override void initLumenazaFields() {

        this.lumenazaFields = new Map<String,Object>{
            'consumer_id'       => null, // (mandatory)
            'contract_id'       => null, // (mandatory)
            'changed_attribute' => null, // (mandatory)
            'new_value'         => null
        };
    }

    /**
     * Return Lumenaza fields with values
     */
    public override Map<String,Object> getLumenazaFields() {

        String sDebugHere = DEBUG_HEADER + '.getLumenazaFields() - ';

        Map<String,Object> mapLumenazaFields = super.getLumenazaFields().clone();

        // null values would be skipped when converted to JSON!
        if (mapLumenazaFields.get('new_value') == null) {
            mapLumenazaFields.put('new_value', '');
        }

        return mapLumenazaFields;
    }

    /**
     * Persist via Lumenaza API
     *
     * This does not fire any DML because persist should
     * usually be called from a batch job. Otherwise you
     * could run into an "uncommitted work pending" error.
     */
    public override Boolean persist() {

        String sDebugHere = DEBUG_HEADER + 'persist() - ';

        LumenazaContractChange__c oChange = this.LumenazaContractChange;

        while (TRUE) {

            // Validate and if false write to contract
            if (this.validate() == FALSE) {
                oChange.StatusReason__c = 'Change has validation errors';
                break;
            }

            try {

                // Callout
                LumenazaApi api = this.getLumenazaApi();
                LumenazaApi.LumenazaApiResponse lumenazaResponse = api.addChange(this);

                System.debug(sDebugHere + 'API Response: ' + lumenazaResponse);

                // Set request info
                oChange.LumenazaCreateAPIRequestTime__c = System.now();
                oChange.LumenazaCreateAPIRequest__c     = lumenazaResponse.requestInfo;

                // On error
                if (lumenazaResponse.success == FALSE) {
                    this.setError(lumenazaResponse.error);
                    oChange.LumenezaCreateAPIResponse__c = this.getError();
                }
                // On success
                else {

                    oChange.LumenezaCreateAPIResponse__c  = lumenazaResponse.response.getBody();

                    // Set retrieved change ID
                    if (lumenazaResponse.resultMap != null && lumenazaResponse.resultMap.containsKey('change_id')) {
                        oChange.LumenazaChangeId__c = lumenazaResponse.resultMap.get('change_id');
                        oChange.Status__c           = 'pending';
                        oChange.StatusReason__c     = 'Change successfully passed to Lumenaza';
                    }
                    else {
                        this.setError('No change_id found in response');
                    }
                }

                //
                if (lumenazaResponse.response != null) {
                    //if (Test.isRunningTest() && contract.Lumenaza_ApiStatusCode__c == 'TEST') {
                    //    System.debug('LumenazaContract - Set a fake error to raise a case');
                    //    error = 'TESTERROR';
                    //}
                    oChange.LumenazaCreateAPIStatusCode__c = lumenazaResponse.response.getStatusCode();
                }
                else {
                    // Error on null response
                    this.setError('HTTP response was null');
                    System.debug(sDebugHere + this.getError());
                }
            }
            catch (Exception e) {
                this.setError(e.getMessage() + ': ' + e.getStackTraceString());
            }

            break;
        }

        if (this.hasError()) {
            oChange.Status__c       = 'error';
            oChange.StatusReason__c = oChange.StatusReason__c != null ? oChange.StatusReason__c : 'Error on creating change via Lumenaza API';
            oChange.LastError__c    = this.getError().length() > 255 ? this.getError().substring(0,255) : this.getError();
            return FALSE;
        }

        return TRUE;
    }

    /**
     * Checks on Change's status via Lumenaza API
     */
    public Boolean checkOnResult() {

        String sDebugHere = DEBUG_HEADER + 'checkOnResult() - ';

        LumenazaContractChange__c oChange = this.LumenazaContractChange;
        String sLumenazaChangeId = oChange.LumenazaChangeId__c;

        if (oChange.Status__c != 'pending' || sLumenazaChangeId == null) {
            this.setError('Change is not "pending" or has no change ID');
            return FALSE;
        }

        try {

            LumenazaApi oApi = this.getLumenazaApi();
            LumenazaApi.LumenazaApiResponse oLumenazaResponse = oApi.checkChange(this);

            System.debug(sDebugHere + 'API Response: ' + oLumenazaResponse);

            // Set request info
            oChange.LumenazaLastResultAPIRequestTime__c = System.now();
            //oChange.LumenazaCheckAPIRequest__c     = lumenazaResponse.requestInfo;

            // On error
            if (oLumenazaResponse.success == FALSE) {
                this.setError(oLumenazaResponse.error);
            }
            // On success
            else {

                List<Map<String,String>> listChangeResult;

                Boolean bFoundChange = FALSE;
                listChangeResult = (List<Map<String,String>>)JSON.deserialize(oLumenazaResponse.response.getBody(), List<Map<String,String>>.class);

                // Search for current change ID
                for (Map<String,String> mapChangeResult : listChangeResult) {
                    if (mapChangeResult.get('change_id') == sLumenazaChangeId) {

                        String sStatus = mapChangeResult.get('status');

                        if (sStatus == 'pending' || sStatus == 'rejected' || sStatus == 'stored') {
                            oChange.Status__c = sStatus;

                            if (sStatus == 'pending') {
                                oChange.StatusReason__c = 'Still pending (' + System.now() + ')';
                            }
                            else {
                                oChange.StatusReason__c = 'Change was ' + sStatus + ' (' + System.now() + ')';
                            }
                        }
                        else {
                            this.setError('Unknown Change status "' + sStatus + '" returned by API');
                        }
                        bFoundChange = TRUE;
                        break;
                    }
                }

                if (!bFoundChange) {
                    this.setError('Change with Lumenaza ID "' + sLumenazaChangeId + '" not found in Lumenaza change list');
                }
            }

            if (oLumenazaResponse.response != null) {
                oChange.LumenazaCreateAPIStatusCode__c = oLumenazaResponse.response.getStatusCode();
            }
            else {
                // Error on null response
                this.setError('HTTP response was null');
            }
        }
        catch (Exception e) {
            this.setError(e.getMessage() + ': ' + e.getStackTraceString());
        }

        if (this.hasError()) {
            oChange.Status__c       = 'error';
            oChange.StatusReason__c = oChange.StatusReason__c != null ? oChange.StatusReason__c : 'Error on querying change from Lumenaza API';
            oChange.LastError__c    = this.getError().length() > 255 ? this.getError().substring(0,255) : this.getError();
            return FALSE;
        }

        return TRUE;
    }

    /**
     * Returns an instance of the LumenazaApi
     */
    private LumenazaApi getLumenazaApi() {

        String sDebugHere = DEBUG_HEADER + 'getLumenazaApi() - ';

        if (lumenazaApi == null) {
            System.debug(sDebugHere + 'Instantiate new LumenazaApi()');
            lumenazaApi = new LumenazaApi();
        }
        else {
            System.debug(sDebugHere + 'Take existing LumenazaApi() instance');
        }

        return lumenazaApi;
    }

    /**
     * Always needs update which means insert here
     * because updates cannot be done on changes
     */
    public override Boolean needsUpdate() {
        return TRUE;
    }

    /**
     * Validate Lumenaza fields
     */
    public override Boolean validate() {

        String sDebugHere = DEBUG_HEADER + 'validate() - ';
        System.debug(sDebugHere + 'Fields to validate: ' + this.lumenazaFields);

        for (String fieldName : this.lumenazaFields.keySet()) {

            String value = (this.lumenazaFields.get(fieldName) == null) ? '' : String.valueOf(this.lumenazaFields.get(fieldName)).trim();

            if ((fieldName == 'consumer_id' || fieldName == 'contract_id' || fieldName == 'changed_attribute') && value.length() == 0) {
                this.setError('Field "' + fieldName + '" is mandatory for Lumenaza Change');
                System.debug(sDebugHere + 'Validation with error: ' + this.getError());
                return false;
            }
        }

        System.debug(sDebugHere + 'Validation ok');
        return TRUE;
    }

    public override void initFutureUpsert() {
        throw new LumenazaChangeException('initFutureUpsert() is not implemented for LumenazaChange as this is done by a batch!');
    }

    /**
     * Returns the Contract ID
     */
    public String getLumenazaContractId() {
        return String.valueOf(this.getLumenazaFields().get('contract_id'));
    }

    /**
     * Returns the Customer/Consumer ID
     */
    public String getLumenazaCustomerId() {
        return String.valueOf(this.getLumenazaFields().get('consumer_id'));
    }

    public class LumenazaChangeException extends Exception {}
}