@RestResource(urlMapping='/contract/partner/*')

/**
 * REST Service for querying Contract Partner Accounts
 *
 * External testing via http://sonnenbatterie-dev.interapps.de/tests/contract/LumenazaContractRESTServiceTest.php
 * (Credentials: standard dia or see https://dia.my.salesforce.com/a0757000013gG5S)
 *
 * Apex Unit Testing via class RESTServiceTest.
 *
 * Changelog:
 *
 * v1.1.0-2017-04-06
 * - Added parameter "country" to filter partners (SOBCRM-897)
 *
 * v1.0.0
 * - Initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @see https://interaktiv.jira.com/wiki/pages/viewpage.action?pageId=110592032
 * @version 1.1.0-2017-04-06
 */
global with sharing class RESTServiceContractPartner {

    public static final String OBJECT_NAME = 'Partner'; // fictive

    /**
     * handle GET
     *
     * Querying Partner
     */
    @HttpGet
    global static DiaRESTResponse handleGet() {

        DiaRESTResponse oResponse = new DiaRESTResponse(OBJECT_NAME);

        while (true) {

            if (!RESTService.isAuthenticated(oResponse)) {
                break;
            }

            List<Schema.PicklistEntry> listCountryCodes = Account.BillingCountryCode.getDescribe().getPicklistValues();
            Set<String> lsetCountryCodes = new Set<String>();

            for(Schema.PicklistEntry oPickListEntry : listCountryCodes) {
                lsetCountryCodes.add(oPickListEntry.getValue());
            }

            oResponse.addDebug('Valid country codes: ' + String.join(new List<String>(lsetCountryCodes), ', '));

            RestRequest request = RestContext.request;
            String country = request.params.get('country');

            if (country == NULL || country.length() == 0) {
                oResponse.setError('Kein Ländercode übergeben', 'MISSING_COUNTRY_CODE');
                break;
            }

            if (!lsetCountryCodes.contains(country.toUpperCase())) {
                oResponse.setError('Ungültiger Ländercode', 'INVALID_COUNTRY_CODE');
                break;
            }

            List<Account> listPartnerAccounts;

            try {
                listPartnerAccounts = new List<Account>([
                    SELECT Id, Name, BillingCountryCode
                    FROM Account
                    WHERE
                    RecordType.DeveloperName = 'SBC' AND
                    Status__c = 'active' AND
                    PartnerType__c != 'OEM' AND
                    BillingCountryCode = :country
                    ORDER BY
                        Name ASC
                ]);
            }
            catch (Exception e) {
                oResponse.setError(e.getMessage(), 'INTERNAL_ERROR');
                break;
            }

            oResponse.setObjects(listPartnerAccounts, listPartnerAccounts.size());
            break;
        }

        return oResponse;
    }
}