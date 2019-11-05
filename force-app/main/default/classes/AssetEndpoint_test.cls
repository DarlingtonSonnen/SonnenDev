/**
 * Created by b.jarmolinski on 10/04/2018.
 * Test coverage for AssetEndpointV2
 *
 * 22/10/2018 by Bartosz
 * Added @testSetup to create partner account and contact to check linking asset to the installer
 *
 * 09/11/2018 by Bartosz
 * Added testMethod3 and generateJSON4 method to cover try catch exception block
 *
 * 17/12/2018 by Bartosz
 * Added "DE_Software": "0.9.42.160512" to the json payloads
 */

@isTest
public with sharing class AssetEndpoint_test {

    @testSetup
    static void createTest() {
        Account a = new Account(
                Name='Burgerchmidt Auto',
                RecordTypeID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId()
        );
        insert a;

        Contact c = new Contact(
                FirstName='Claus',
                LastName='Zeman',
                AccountId = a.Id,
                TopMCertificationId__c = '12345',
                RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Technician').getRecordTypeId()
        );
        insert c;
        System.debug([SELECT Id, AccountId, TopMCertificationId__c  FROM Contact]);
    }

    static testMethod String getJson1() {
        String jsonMessage = '[ { "DE_Ticket_Number":"12345", "IN_Address1": "Am Riedbach", "IN_Address2": "1", "IN_City": "Wildpoldsried", "IN_ContractId": "23456", "IN_Country": "DE", "IN_CustomerNumber" : "12345", "IN_Date": "13/02/2018", "IN_EarthingSystem": "TN-C-S", "IN_Email": "andre@test.de", "IN_EmailConfirm": "", "IN_FEATURE_CHP": "0", "IN_FEATURE_MICROGRID": "0", "IN_FEATURE_PROTECT": "0", "IN_FEATURE_SCR": "0", "IN_FEATURE_TOU": "0", "IN_FLAT": "1", "IN_FLAT_CONCEPT": "0", "IN_FLAT_CONCEPT_DESCRIPTION": "Z1 ist ein vom VNB installierter Zweirichtungszähler. Z2 ein privater Gesamtverbrauchszähler.", "IN_FLAT_CONTRACT": "12345678", "IN_FLAT_OFFICIAL": "2", "IN_FLAT_PRODUCTION_METER": "2", "IN_FLAT_STORAGEPASSNR": "", "IN_FirstName": "testname", "IN_Gender": "Mr.", "IN_IN_Certificate": "12345", "IN_IN_Company": "testcompany", "IN_IN_Email": "andre@test.de", "IN_IN_FirstName": "André", "IN_IN_Gender": "Mr.", "IN_IN_LastName": "testname", "IN_IN_LegalConfirmation": "Yes", "IN_Inverter_Country_Code": "Germany", "IN_LastName": "Customername", "IN_PROTECT_ACTIVE": "0", "IN_PROTECT_CODE": "", "IN_PROTECT_SERIAL": "", "IN_Password": "", "IN_Phone": "012345552134", "IN_State": "Bayern", "IN_SystemInstalled": "1", "IN_TZUTCOffset": "1", "IN_Time": "12:05", "IN_TimeZone": "Europe/Berlin", "IN_ZipCode": "87471", "IN_UTC": "2018-04-25 13:25:00", "DE_Software": "0.9.42.160512"}]';
        return jsonMessage;
    }

    static testMethod String getJson2() {
        String jsonMessage = '[ { "DE_Ticket_Number":"12345", "IN_Address1": "Zossener str", "IN_Address2": "56", "IN_City": "Berlin", "IN_ContractId": "23456", "IN_Country": "DE", "IN_CustomerNumber" : "12345", "IN_Date": "13/02/2018", "IN_EarthingSystem": "TN-C-S", "IN_Email": "bartosz@sonnen.de", "IN_EmailConfirm": "", "IN_FEATURE_CHP": "0", "IN_FEATURE_MICROGRID": "0", "IN_FEATURE_PROTECT": "0", "IN_FEATURE_SCR": "0", "IN_FEATURE_TOU": "0", "IN_FLAT": "1", "IN_FLAT_CONCEPT": "0", "IN_FLAT_CONCEPT_DESCRIPTION": "Z1 ist ein vom VNB installierter Zweirichtungszähler. Z2 ein privater Gesamtverbrauchszähler.", "IN_FLAT_CONTRACT": "12345678", "IN_FLAT_OFFICIAL": "2", "IN_FLAT_PRODUCTION_METER": "2", "IN_FLAT_STORAGEPASSNR": "", "IN_FirstName": "testname", "IN_Gender": "Mr.", "IN_IN_Certificate": "12345", "IN_IN_Company": "testcompany", "IN_IN_Email": "andre@test.de", "IN_IN_FirstName": "André", "IN_IN_Gender": "Mr.", "IN_IN_LastName": "testname", "IN_IN_LegalConfirmation": "Yes", "IN_Inverter_Country_Code": "Germany", "IN_LastName": "Customername", "IN_PROTECT_ACTIVE": "0", "IN_PROTECT_CODE": "", "IN_PROTECT_SERIAL": "", "IN_Password": "", "IN_Phone": "012345552134", "IN_State": "Bayern", "IN_SystemInstalled": "1", "IN_TZUTCOffset": "1", "IN_Time": "12:05", "IN_TimeZone": "Europe/Berlin", "IN_ZipCode": "87471", "IN_UTC": "2018-04-25 13:25:00", "DE_Software": "0.9.42.160512"}] ';
        return jsonMessage;
    }

    static testMethod String getJson3() {
        String jsonMessage = '[ { "DE_Ticket_Number":"12345", "IN_Address1": "Zossener str", "IN_Address2": "56", "IN_City": "Berlin", "IN_ContractId": "23456", "IN_Country": "DE", "IN_CustomerNumber" : "12345", "IN_Date": "13/02/2018", "IN_EarthingSystem": "TN-C-S", "IN_Email": "bartosz@sonnen.de", "IN_EmailConfirm": "", "IN_FEATURE_CHP": "0", "IN_FEATURE_MICROGRID": "0", "IN_FEATURE_PROTECT": "0", "IN_FEATURE_SCR": "0", "IN_FEATURE_TOU": "0", "IN_FLAT": "1", "IN_FLAT_CONCEPT": "0", "IN_FLAT_CONCEPT_DESCRIPTION": "Z1 ist ein vom VNB installierter Zweirichtungszähler. Z2 ein privater Gesamtverbrauchszähler.", "IN_FLAT_CONTRACT": "12345678", "IN_FLAT_OFFICIAL": "2", "IN_FLAT_PRODUCTION_METER": "2", "IN_FLAT_STORAGEPASSNR": "", "IN_FirstName": "testname", "IN_Gender": "Mr.", "IN_IN_Certificate": "12346", "IN_IN_Company": "testcompany", "IN_IN_Email": "andre@test.de", "IN_IN_FirstName": "André", "IN_IN_Gender": "Mr.", "IN_IN_LastName": "testname", "IN_IN_LegalConfirmation": "Yes", "IN_Inverter_Country_Code": "Germany", "IN_LastName": "Customername", "IN_PROTECT_ACTIVE": "0", "IN_PROTECT_CODE": "", "IN_PROTECT_SERIAL": "", "IN_Password": "", "IN_Phone": "012345552134", "IN_State": "Bayern", "IN_SystemInstalled": "1", "IN_TZUTCOffset": "1", "IN_Time": "12:05", "IN_TimeZone": "Europe/Berlin", "IN_ZipCode": "87471", "IN_UTC": "2018-04-25 13:25:00", "DE_Software": "0.9.42.160512"}] ';
        return jsonMessage;
    }

    static testMethod String getJson4() {
        String jsonMessage = '[ { "DE_Ticket_Number":"22345", "IN_Address1": "Zossener str", "IN_Address2": "56", "IN_City": "Berlin", "IN_ContractId": "23456", "IN_Country": "DE", "IN_CustomerNumber" : "12345", "IN_Date": "13/02/2018", "IN_EarthingSystem": "TN-C-S", "IN_Email": "bartosz@sonnen.de", "IN_EmailConfirm": "", "IN_FEATURE_CHP": "0", "IN_FEATURE_MICROGRID": "0", "IN_FEATURE_PROTECT": "0", "IN_FEATURE_SCR": "0", "IN_FEATURE_TOU": "0", "IN_FLAT": "1", "IN_FLAT_CONCEPT": "0", "IN_FLAT_CONCEPT_DESCRIPTION": "Z1 ist ein vom VNB installierter Zweirichtungszähler. Z2 ein privater Gesamtverbrauchszähler.", "IN_FLAT_CONTRACT": "12345678", "IN_FLAT_OFFICIAL": "2", "IN_FLAT_PRODUCTION_METER": "2", "IN_FLAT_STORAGEPASSNR": "", "IN_FirstName": "testname", "IN_Gender": "Mr.", "IN_IN_Certificate": "12346", "IN_IN_Company": "testcompany", "IN_IN_Email": "andre@test.de", "IN_IN_FirstName": "André", "IN_IN_Gender": "Mr.", "IN_IN_LastName": "testname", "IN_IN_LegalConfirmation": "Yes", "IN_Inverter_Country_Code": "Germany", "IN_LastName": "Customername", "IN_PROTECT_ACTIVE": "0", "IN_PROTECT_CODE": "", "IN_PROTECT_SERIAL": "", "IN_Password": "", "IN_Phone": "012345552134", "IN_State": "Bayern", "IN_SystemInstalled": "1", "IN_TZUTCOffset": "1", "IN_Time": "12:05", "IN_TimeZone": "Europe/Berlin", "IN_ZipCode": "87471", "IN_UTC": "2018-04-25 13:25:00", "IN_IN_SoldByInstaller": "yesnoyesnoyesnno", "DE_Software": "0.9.42.160512"}] ';
        return jsonMessage;
    }

    static testMethod void CommissioningAssistant() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/AssetApiV2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(getJson1());

        RestContext.request = req;
        RestContext.response = res;

        AssetEndpointV2.createAssets();

        System.assertEquals(1, [SELECT id FROM Asset WHERE AccountId != null].size());
        System.assertEquals('testname Customername', [SELECT Name FROM Account WHERE RecordType.DeveloperName != 'SBC' LIMIT 1].Name);
        System.assertEquals('Am Riedbach', [SELECT INClientStreet__c FROM Asset WHERE INClientLastName__c = 'Customername' LIMIT 1].INClientStreet__c);

        // test same request again, check that the new asset is linked the already created account and not creating a new one
        RestRequest req2 = new RestRequest();
        RestResponse res2 = new RestResponse();

        req2.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/AssetApiV2';
        req2.httpMethod = 'POST';
        req2.requestBody = Blob.valueOf(getJson2());

        RestContext.request = req2;
        RestContext.response = res2;

        AssetEndpointV2.createAssets();

        System.assertEquals(1, [SELECT id FROM Asset WHERE AccountId != null].size());
        String accountName = [SELECT Account.Name FROM Asset ORDER BY CreatedDate DESC][0].Account.Name;
        String city = [SELECT INClientCity__c FROM Asset WHERE SerialNumber = '12345'].INClientCity__c;
        System.assertEquals('testname Customername', accountName);
        System.assertEquals('Berlin', city);
    }

    static testMethod void testMethod2() {
        // test asset creation when no match found with existing installers
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/AssetApiV2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(getJson3());

        RestContext.request = req;
        RestContext.response = res;

        AssetEndpointV2.createAssets();

        System.assertEquals(1, [SELECT id FROM Asset WHERE AccountId != null].size());
        System.assertEquals(null, [SELECT Installer__c FROM Asset].Installer__c);
        System.assertEquals(1, [SELECT Id FROM Case WHERE AssetId != null].size());
    }

    static testMethod void testMethod3() {
        // test catch block when inserting asset
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/AssetApiV2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(getJson4());
        //System.debug(req.requestBody);

        RestContext.request = req;
        RestContext.response = res;

        AssetEndpointV2.createAssets();

        System.assertEquals(1, [SELECT Id FROM Log__c].size());
        System.assertEquals(1, [SELECT Id, Subject FROM Case WHERE Subject = 'Asset creation via CommAssist failed'].size());
    }
}