/**
 * Lumenaza Bonus object
 *
 * Changelog:
 *
 * v1.4.0-2018-04-27 (marko@die-interaktiven.de)
 * - Added bypassing for ContractTriggerHandler (SOBCRM-1177)
 *
 * v1.3.0-2018-04-06 (marko@die-interaktiven.de)
 * - Revised with lumenazaFields as Map<String,Object>
 *
 * v1.2.0 (MSB 2017-10-23)
 * - Added field "apply_to" (SOBCRM-1090)
 *
 * v1.1.0 (MSB 2016-10-05)
 * - Revised for using Lumenaza API v3 (SOBCRM-666)
 *
 * v1.0.0 (2016-04-27)
 * - Initial
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version v1.4.0-2018-04-27
 */
public class LumenazaBonus extends LumenazaObject {

    private Bonus__c bonus;

    private String lumenazaCustomerId; // same as consumerId

    /**
     * Init LumenazaFields
     */
    protected override void initLumenazaFields() {

        this.lumenazaFields = new Map<String,Object>{
            'amount_kwh'       => null, // float (mandantory if amount_euro is empty), kwH
            'amount_euro'      => null, // float (mandantory if amount_kwh is empty), EUR gross
            'contract_id'      => null, // string (mandatory), the ID of the contract to which the bonus is associated
            'start_date'       => null, // string (mandatory), date format: YYYY-MM-DD
            'number_of_months' => null, // integer (mandatory), length of bonus we payed
            'bonusID'          => null, // string (mandatory), a unique identifier for this bonus
            'bonus_type'       => null, // string (mandatory, values: periodical, oneshot
            'display_name'     => null, // string (mandatory), display name for customer/invoices. This should be the name used in the market campaign for better recognition by the customer.
            'apply_to'         => null  // string (optional), if given apply bonus to special part of product; values are: consumption, community_fee, base_fee
        };
    }

    /**
     * Instantiate LumenazaBonus by Bonus__c
     */
    public LumenazaBonus(Bonus__c bonus) {

        if (bonus == null) {
            throw new LumenazaObjectException('Bonus object is null');
        }
        if (bonus.Id == null) {
            throw new LumenazaObjectException('Only existing Bonuses with ID can be passed');
        }
        this.initLumenazaFields();

        // Init by bonus
        this.bonus = bonus;
        this.sObjectId = this.bonus.Id;

        this.lumenazaCustomerId = this.bonus.Lumenaza_consumer_id__c;

        System.debug('LumenazaBonus - Bonus ' + bonus);

        this.setLumenazaFieldsFromObject(bonus);
    }

    /**
     * Init by bonus ID
     */
    public LumenazaBonus(Id bonusId) {
        this((Bonus__c)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Bonus__c') + ' FROM Bonus__c WHERE Id = :bonusId'));
    }

    /**
     * Init future upsert
     */
    public override void initFutureUpsert() {
        if (Test.isRunningTest() == true) {
            new LumenazaBonus(this.sObjectId).persist();
        }
        else {
            LumenazaBonus.futureUpsert(this.sObjectId);
        }
    }

    /**
     * Future upsert of a LumenazaBonus by a bonus ID
     */
    @future(callout=true)
    public static void futureUpsert(Id bonusId) {
        System.debug('LumenazaBonus - futureUpsert() with bonus ' + bonusId);
        new LumenazaBonus(bonusId).persist();
    }

    /**
     * Persist this object
     *
     * @return Boolean Success
     */
    public override Boolean persist() {

        // Validate and if false write to bonus
        if (this.validate() == false) {
            return false;
        }

        Bonus__c bonus = this.bonus;
        System.debug('LumenazaBonus - persist(): bonus ' + bonus);

        // Set Request time
        bonus.Lumenaza_ApiRequestTime__c = System.now();

        String error = '';
        String errorDescription = '';

        // Insert bonus via API
        try {
            LumenazaApi api = new LumenazaApi();
            LumenazaApi.LumenazaApiResponse lumenazaResponse = api.addBonus(this);

            System.debug('LumenazaBonus - Got Lumenaza API Response: ' + lumenazaResponse);

            // Set request info
            bonus.Lumenaza_ApiRequest__c = lumenazaResponse.requestInfo;

            if (lumenazaResponse.success == false) {
                bonus.Lumenaza_ApiResponse__c = lumenazaResponse.error;
                error = lumenazaResponse.error;
            }
            else {

                bonus.Lumenaza_ApiResponse__c = lumenazaResponse.response.getBody();
                bonus.RedeemDate__c           = System.now();

                if (lumenazaResponse.resultMap != null) {

                    Map<String,String> resultMap = lumenazaResponse.resultMap;

                    /*
                    if (resultMap.containsKey('contract_id')) {
                        bonus.xxx = resultMap.get('contract_id');
                    }
                    */
                }
            }

            if (lumenazaResponse.response != null) {

                if (Test.isRunningTest() && bonus.Lumenaza_ApiStatusCode__c == 'TEST') {
                    System.debug('LumenazaBonus - Set a fake error to raise a case');
                    error = 'TESTERROR';
                }

                bonus.Lumenaza_ApiStatusCode__c = String.valueOf(lumenazaResponse.response.getStatusCode());
            }
            else {
                // Error on null response
                System.debug('LumenazaBonus - lumenazaResponse.response is null');
                error = 'The lumenazaResponse.response was null so the response could not be written to the Bonus';
                bonus.Lumenaza_ApiResponse__c = error;
                errorDescription = '\n\nLumenazaResponse: ' + lumenazaResponse;
            }
        }
        catch (Exception e) {
            bonus.Lumenaza_ApiResponse__c = e.getMessage();
            error = e.getMessage() + ' ' + e.getStackTraceString();
        }

        try {
            TriggerHandler.bypass('LumenazaBonusTriggerHandler');
            TriggerHandler.bypass('ContractTriggerHandler');
            System.debug('LumenazaBonus - Update bonus with bypassing LumenazaBonusTriggerHandler and ContractTriggerHandler: ' + bonus);
            update bonus;
            TriggerHandler.clearBypass('LumenazaBonusTriggerHandler');
            TriggerHandler.clearBypass('ContractTriggerHandler');
        }
        catch (Exception e) {
            error = e.getMessage() + ' ' + e.getStackTraceString();
        }

        // Open case on error
        if (error.length() > 0) {
            Case errorCase = new Case();
            errorCase.subject = 'Error at Lumenaza Sync for Bonus';
            errorCase.description  = 'Error: ' + error + '\n\n';
            errorCase.description += 'Bonus ' + System.Url.getSalesforceBaseUrl().toExternalForm() + '/' + bonus.Id;
            errorCase.description += errorDescription;
            insert errorCase;
        }

        return true;
    }

    /**
     * Is called by LumenazaApi to check if object needs an update.
     * In this case bonus is always only inserted
     */
    public override Boolean needsUpdate() {

        if (!this.bonus.IsSyncableToLumenaza__c) {
            System.debug('LumenazaBonus - needsUpdate(): IsSyncableToLumenaza__c is not true: no update');
            return false;
        }

        return true;
    }

    /**
     * Validates the object
     */
    public override Boolean validate() {

        System.debug('LumenazaBonus - validate() fields: ' + this.lumenazaFields);

        for (String fieldName : this.lumenazaFields.keySet()) {

            String value = (this.lumenazaFields.get(fieldName) == null) ? '' : String.valueOf(this.lumenazaFields.get(fieldName)).trim();

            if (
                (
                    fieldName == 'amount' ||
                    fieldName == 'contract_id' ||
                    fieldName == 'start_date' ||
                    fieldName == 'number_of_months' ||
                    fieldName == 'bonusID' ||
                    fieldName == 'bonus_type' ||
                    fieldName == 'display_name'
                ) && value.length() == 0) {
                this.setError('Field "' + fieldName + '" is mandatory for Lumenaza API');
                return false;
            }
        }

        if ((this.lumenazaFields.get('amount_kwh') == null || String.valueOf(this.lumenazaFields.get('amount_kwh')).length() == 0) &&
            (this.lumenazaFields.get('amount_euro') == null || String.valueOf(this.lumenazaFields.get('amount_euro')).length() == 0)) {
            this.setError('Either amount_kwh or amount_euro is mandatory for Lumenaza API');
            return false;
        }
        if (this.lumenazaFields.get('amount_kwh') != null && String.valueOf(this.lumenazaFields.get('amount_kwh')).length() != 0 &&
            this.lumenazaFields.get('amount_euro') != null && String.valueOf(this.lumenazaFields.get('amount_euro')).length() != 0) {
            this.setError('Specify either amount_kwh OR amount_euro for Lumenaza API');
            return false;
        }

        return true;
    }

    /**
     * Return the bonus object
     */
    public Bonus__c getBonus() {
        return this.bonus;
    }

    /**
     * Returns the bonus' contractId
     */
    public String getLumenazaContractId() {
        if (this.bonus != null) {
            return this.bonus.Lumenaza_contract_id__c;
        }
        return null;
    }

    /**
     * Returns the Lumenaza customer ID (consumer ID)
     */
    public String getLumenazaCustomerId() {
        return this.lumenazaCustomerId;
    }
}