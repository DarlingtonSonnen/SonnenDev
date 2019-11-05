/**
 * Created by b.jarmolinski on 05/04/2018.
 * Code coverage by the class AssetEndpoint_test
 * 
 * 13/06/2018
 * added reference to DuplicateCheckv2 - filling out contact on asset together with account
 * added installer email to the wrapper and asset creation
 * added country wrapper - in order to translate free text value to the relevant picklist on account.billingcountry
 * 
 * 22/08/2018 - Bartosz J.
 * Added Country__c to be filled in by the value from AssetWrapper.IN_Country
 * 
 * 11/09/2018 - by Bartosz
 * Added a.INInstallerName__c - name of the installer to be populated on the asset
 *
 * 28/09/2018 - by Bartosz
 * Added language parameter - filled in from country
 *
 * 22/10/2018 - by Bartosz
 * Added In Installer ID, In Installer Company to be saved from the CommAssist to Asset object
 * Added linking asset with the installer contact and company if they exist (based on installer Id)
 * Added Case creation if no match found between installer certification Id provided in CommAssist and technicians existing in Salesforce
 *
 * 06/11/2018 - by Bartosz
 * Added IN_IN_SoldBy and IN_IN_SoldByInstaller parameters to the wrapper class and appropriate parameters to be filled in on Asset recordd
 * Added CommAssistPayLoad__c text area to store the JSON body sent by the CA App
 * Added method createCase(...) - which is shared by different scenarios when a case should be created
 * Added case creation when no ServicePartner could be identified
 *
 * 09/11/2018 - by Bartosz
 * Added try catch block for Asset upsert. The catch will create Log__c record and a case
 *
 * 04/12/2018 - by Bartosz
 * Added a.InstallingCompany__c when creating asset
 * Added DE_Software parameter to the ObjectWrapper class
 * Added a.INCommissioningAssistantVersion__c
 */
@RestResource(urlMapping = '/AssetApi')
global with sharing class AssetEndpointV2 {

    @HttpPost
    global static void createAssets() {
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String jsonBody = req.requestBody.toString();
        System.debug(jsonBody);
        List<ObjectWrapper> owl = (List<ObjectWrapper>) JSON.deserialize(jsonBody, List<ObjectWrapper>.class);
        System.debug(owl);

        ObjectWrapper owAsset = owl[0];

        List<String> s = owAsset.IN_Date.split('/');
        List<String> h = owAsset.IN_Time.split(':');

        System.debug(DateTime.valueOf(owAsset.IN_UTC));
        System.debug(DateTime.valueOfGmt(owAsset.IN_UTC));

        Integer day = Integer.valueOf(s[0]);
        Integer month = Integer.valueOf(s[1]);
        Integer year = Integer.valueOf(s[2]);

        Integer hours = Integer.valueOf(h[0]);
        Integer minutes = Integer.valueOf(h[1]);

        System.debug(hours);
        System.debug(minutes);

        CommissioningAssistant__mdt ca = [SELECT DefaultContactId__c FROM CommissioningAssistant__mdt WHERE Label = 'Settings' LIMIT 1];

        List<Asset> assets = [SELECT INClientSalutation__c, INClientFirstName__c, INClientLastName__c, INClientStreet__c,
                                INClientAdditionToAddress__c, INClientZIPCode__c, INClientPhoneNumber__c, INClientLanguage__c,
                                InstallationCommissioning__c, Installer__c, ServicePartner__c, InstallingCompany__c
                                FROM Asset WHERE SerialNumber = :owAsset.DE_Ticket_Number];

        Asset a;

        // query contacts to find installer based on the certification ID provided in commAssist
        List<Contact> contacts = [SELECT Id, AccountId, TopMCertificationId__c  FROM Contact WHERE TopMCertificationId__c = :owAsset.IN_IN_Certificate];
        System.debug(contacts.size());

        if(assets.isEmpty()) {
            a = new Asset();
            a.AccountId = null;
        } else {
            a = assets[0];
        }
        a.Name = '#' +owAsset.DE_Ticket_Number + ' ' + owAsset.IN_FirstName + ' ' + owAsset.IN_LastName;
        a.SerialNumber = owAsset.DE_Ticket_Number;
        a.Status = 'Installed';
        a.INClientSalutation__c = owAsset.IN_Gender;
        a.INClientFirstName__c = owAsset.IN_FirstName;
        a.INClientLastName__c = owAsset.IN_LastName;
        a.INClientStreet__c = owAsset.IN_Address1;
        a.INClientAdditionToAddress__c = owAsset.IN_Address2;
        a.INClientZIPCode__c = owAsset.IN_ZipCode;
        a.INClientPhoneNumber__c = owAsset.IN_Phone;
        a.INClientCity__c = owAsset.IN_City;
        a.INClientState__c = owAsset.IN_State;
        a.INInstallerEmail__c = owAsset.IN_IN_Email;
        a.INInstallerName__c = owAsset.IN_IN_FirstName + ' ' + owAsset.IN_IN_LastName;
        a.INInstallerID__c = owAsset.IN_IN_Certificate;
        a.INInstallerCompany__c = owAsset.IN_IN_Company;
        a.Country__c = owAsset.IN_Country;
        a.INClientCountry__c = CountryWrapper.ConvertCountry().get(owAsset.IN_Country);
        a.INClientEmail__c = owAsset.IN_Email;
        a.InClientEmail2__c = owAsset.IN_Email;
        a.INCommissioningDate__c = Date.newInstance(year, month, day);
        a.CommissioningDateTime__c = DateTime.valueOfGmt(owAsset.IN_UTC);
        a.INClientLanguage__c = setLanguage(owAsset.IN_Country);
        a.INClientDataConfirmed__c = false;
        a.CommAssistPayLoad__c = jsonBody;
        a.INSoldby__c = owAsset.IN_IN_SoldBy;
        a.INSoldByInstaller__c = owAsset.IN_IN_SoldByInstaller;
        a.INCommissioningAssistantVersion__c = owAsset.DE_Software;
        if (a.InstallationCommissioning__c == null) {
            a.InstallationCommissioning__c = Date.newInstance(year, month, day);
        }
        if (contacts.size() > 0) {
            a.Installer__c = contacts[0].Id;
            a.InstallingCompany__c = contacts[0].AccountId;
            if (owAsset.IN_IN_SoldByInstaller != 'No') {
                a.ServicePartner__c = contacts[0].AccountId;
            }
        }


        List<Asset> assetList = new List<Asset>();
        assetList.add(a);
        
        DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(assetList);
        a.AccountId = dch.handleObjectsv2().get(a.Id).get('Account');
        a.ContactId = dch.handleObjectsv2().get(a.Id).get('Contact');

        try {
            upsert a;

        } catch(Exception e) {
            Log__c log = new Log__c(
                    Message__c = e.getMessage() + '\n' + '\n' + 'Request body:' + '\n' + jsonBody,
                    Origin__c = 'Commissioning Assistant',
                    Timestamp__c = Datetime.now()
            );
            System.debug(e.getMessage());
            insert log;

            Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('TechnicalSupportCase').getRecordTypeId();
            Case c = createCase('Asset creation via CommAssist failed', recordTypeId, null, 'Asset creation failed via CommAssist2. Error log available: '+log.id + '. Contact Salesforce admin.');
            insert c;
        }


        if (a.Installer__c == null || a.ServicePartner__c == null) {

            List<Case> cases = new List<Case>();
            Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('TechnicalSupportCase').getRecordTypeId();

            if (a.Installer__c == null ) {
                String description = 'No match was found between installer certification Id provided in CommAssist and any existing Technician in Salesforce';
                Case c = createCase('Technician Certification prüfen', recordTypeId, a.Id, description);
                cases.add(c);
            } else if (a.ServicePartner__c == null) {
                String description = 'Service Partner: ' + owAsset.IN_IN_SoldBy + ' could not be automatically linked. Please link the right Service Partner Company or if Service Partner does not exist yet please contact Regina Ruf (r.ruf@sonnen.de).';
                Case d = createCase('No Service Partner', recordTypeId, a.Id, description);
                cases.add(d);
            }
            insert cases;
        }
    }

    private static Case createCase(String subject, Id recordTypeId, Id assetId, String description) {

        Case c = new Case(
            Subject = subject,
            RecordTypeId = recordTypeId,
            Impact__c = '2. High',
            AssetId = assetId,
            Description = description
        );
        return c;
    }

    private static String setLanguage(String country) {
        String language;
        if (country == 'de' || country == 'at' || country == 'ch') {
            language = 'de';
        } else if (country == 'it') {
            language = 'it';
        } else {
            language = 'en';
        }
        return language;
    }

    public class ObjectWrapper {
        public String DE_Ticket_Number;
        public String IN_Address1;
        public String IN_Address2;
        public String IN_City;
        public String IN_ContractId;
        public String IN_Country;
        public String IN_CustomerNumber ;
        public String IN_Date;
        public String IN_EarthingSystem;
        public String IN_Email;
        public String IN_EmailConfirm;
        public String IN_FEATURE_CHP;
        public String IN_FEATURE_MICROGRID;
        public String IN_FEATURE_PROTECT;
        public String IN_FEATURE_SCR;
        public String IN_FEATURE_TOU;
        public String IN_FLAT;
        public String IN_FLAT_CONCEPT;
        public String IN_FLAT_CONCEPT_DESCRIPTION;
        public String IN_FLAT_CONTRACT;
        public String IN_FLAT_OFFICIAL;
        public String IN_FLAT_PRODUCTION_METER;
        public String IN_FLAT_STORAGEPASSNR;
        public String IN_FirstName;
        public String IN_Gender;
        public String IN_IN_Certificate;
        public String IN_IN_Company;
        public String IN_IN_Email;
        public String IN_IN_FirstName;
        public String IN_IN_Gender;
        public String IN_IN_LastName;
        public String IN_IN_LegalConfirmation;
        public String IN_Inverter_Country_Code;
        public String IN_LastName;
        public String IN_PROTECT_ACTIVE;
        public String IN_PROTECT_CODE;
        public String IN_PROTECT_SERIAL;
        public String IN_Password;
        public String IN_Phone;
        public String IN_State;
        public String IN_SystemInstalled;
        public String IN_TZUTCOffset;
        public String IN_Time;
        public String IN_TimeZone;
        public String IN_ZipCode;
        public String IN_UTC;
        public String IN_IN_SoldByInstaller;
        public String IN_IN_SoldBy;
        public String DE_Software;
    }
}