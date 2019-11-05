/**
 * Created by b.jarmolinski on 26/11/2018.
 * The class makes callout to api.soluzionifotovoltaico.it and obtains leads
 * The leads are returned as a an array of leads from the current day (to be confirmed)
 * Documentation: http://api.soluzionifotovoltaico.it/
 * 
 * Version 1.2. by Bartosz on 12/12/2018
 * - Removed assignement of the field APICampaign__c - duplicates creating campaign memebers
 *
 * Version 1.1 by Bartosz on 06/12/201
 * - Added LeadSource, CountryCode, TargetCountry__c, Language__c to newly created leads
 */

public with sharing class SoluzioniFotoVoltaicoCallout implements Schedulable {

    public void execute(SchedulableContext sc) {
        makeCallout();
    }

    @future(callout=true)
    public static void makeCallout() {

        //query metadata
        SoluzioniFotoVoltaico__mdt data = [SELECT Username__c, Password__c, Header__c, CampaignId__c
                                            FROM SoluzioniFotoVoltaico__mdt WHERE Label='Data'];

        // callout to log in
        Map<String, String> loginMap = logIn(data);
        System.debug(loginMap);

        // callout to get leads
        List<Lead> leads = makeCallout( loginMap.get('token'), loginMap.get('id_azienda'), data);

        // insert leads
        if (leads != null) {
            if (leads.size() > 0) {
                createLeads(leads, data);
            } else {
                Log__c log = new Log__c(Timestamp__c = Datetime.now(), Origin__c = 'Callout to api.soluzionefotovoltaico.it',  Message__c = 'No new leads found');
                insert log;
            }
        }
    }

    public static Map<String, String> logIn(SoluzioniFotoVoltaico__mdt data) {

        Map<String, String> returnMap; // keys: token, id_azienda as per HttpResponse

        String endpoint = 'https://api.soluzionifotovoltaico.it/api/v1/token';

        // split header to get key and value separately
        List<String> header = data.Header__c.split(': ');

        //create body for the request
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeStringField('username', data.Username__c);
        gen.writeStringField('password', data.Password__c);
        gen.writeEndObject();
        String body = gen.getAsString();

        // Http request
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader(header[0], header[1]);
        req.setBody(body);

        // callout
        HttpResponse res = new HttpResponse();
        if (Test.isRunningTest()) {
            String testResp = '{ "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI2MzExIiwiaXNzIjoiaHR0cHM6XC9cL2FwaS5zb2x1emlvbmlmb3Rvdm9sdGFpY28uaXRcL2FwaVwvdjFcL3Rva2VuIiwiaWF0IjoxNTQzMjIxMTMyLCJleHAiOjE1NDMzMDc1MzIsIm5iZiI6MTU0MzIyMTEzMiwianRpIjoiNTAxNTI1YjgwNGRjN2FmN2MyZDY3MzFmNzM2MDM2NWIifQ.qF89bH60ddBMl9mZM39reHgnlTJ9fHNyel_eEyyRH4E", "id_azienda": 6311 }';
            SingleRequestMock mockResponse = new SingleRequestMock(201, 'Created', testResp, null);
            res = mockResponse.respond(req);
        } else {
            res = h.send(req);
        }
        System.debug(res);
        // deserialize response
        if (res.getStatusCode() == 201 || res.getStatusCode() == 200 ) {
            returnMap = (Map<String, String>) JSON.deserialize(res.getBody(), Map<String, String>.class);
        } else {
            // handle error create log entry
            Log__c log = new Log__c(Timestamp__c = DateTime.now(), Origin__c = 'Login to api.soluzionefotovoltaico.it',
                                    Message__c = 'Login call to soluzionefotovoltaico.it failed. \n HttpResponse: \n '+res.getBody());
            insert log;
        }

        return returnMap;
    }

    private static List<Lead> makeCallout(String token, String id_azienda, SoluzioniFotoVoltaico__mdt data) {

        String endpoint = 'https://api.soluzionifotovoltaico.it/api/v1/partner/' + id_azienda +'/leads';

        // split header to get key and value separately
        List<String> header = data.Header__c.split(': ');

        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader(header[0], header[1]);
        req.setHeader('Authorization', 'Bearer '+token);

        //callout to get leads
        HttpResponse res = new HttpResponse();
        if (Test.isRunningTest()) {
            String testResp = '[ { "nome":"Alessandra", "cognome":"Manfrin", "regione":"Pescara", "citta":"Tocco Casauria", "telefono":"0313 7139583", "email":"mubhln5qfhk@fakemailgenerator.net", "tipologia":"Impianto da 3 kwp in su", "settore":"FOTOVOLTAICO", "datastorico":"2017-03-13 09:22:09.043" }, { "nome":"Dorotea", "cognome":"Cocci", "regione":"Arezzo", "citta":"Malva", "telefono":"0339 5726738", "email":"b5aev245i4b@fakemailgenerator.net", "tipologia":"Impianto da 3 kwp in su", "settore":"FOTOVOLTAICO", "datastorico":"2017-03-13 10:22:09.043" } ]';
            SingleRequestMock mockResponse = new SingleRequestMock(200, 'OK', testResp, null);
            res = mockResponse.respond(req);
        } else {
            res = h.send(req);
        }
        if (res.getStatusCode() == 200) {
            List<Map<String, String>> leadsObj = (List<Map<String, String>> ) JSON.deserialize(res.getBody(), List<Map<String, String>>.class);
            Log__c log = new Log__c();
            log.Timestamp__c = DateTime.now();
            log.Message__c = 'Leads from soluzionefotovoltaico.it - GET successful. \n HttpResponse: \n '+res.getBody();
            log.Origin__c = 'Callout to api.soluzionefotovoltaico.it';
            insert log;

            List<Lead> leads = new List<Lead>();
            // extract leads from the list
            for (Map<String, String> m : leadsObj) {
                Lead l = new Lead();
                l.FirstName = m.get('nome');
                l.LastName = m.get('cognome');
                l.City = m.get('citta');
                l.Phone = m.get('telefono');
                l.Email = m.get('email');
                l.Description2__c = 'tipologia: ' + m.get('tipologia') + '\n' + 'settore: ' + m.get('settore');
                //l.ApiCampaign__c = data.CampaignId__c;
                l.LeadSource = 'Web';
                l.Language__c = 'it';
                l.TargetCountry__c = 'it';
                l.CountryCode = 'IT';
                leads.add(l);
            }

            return leads;
        } else {
            // log error
            Log__c log = new Log__c(Timestamp__c = DateTime.now(), Origin__c = 'Callout to api.soluzionefotovoltaico.it');
            log.Message__c = 'Call to soluzionefotovoltaico.it was unsuccessful. \n HttpResponse: \n '+res.getBody();
            insert log;
            return null;
        }
    }
    public static void createLeads(List<Lead> leads, SoluzioniFotoVoltaico__mdt data) {

        System.debug(leads);
        Map<String, Boolean> duplicateCheckMap = checkForDuplicates(leads);
        System.debug(duplicateCheckMap);

        List<Lead> leadsToInsert = new List<Lead>(); // leads after being check for duplicates

        for (Lead l : leads) {
            if (!duplicateCheckMap.get(l.Email)) {
                // if email already exists in a contact or lead the map.get returns true.
                // the lead should be added to insert only if it does not exist on another lead or a contact
                leadsToInsert.add(l);
            }
        }
        System.debug(leadsToInsert.size());
        List<CampaignMember> members = new List<CampaignMember>(); // list of campaign memebers out of the acquired leads

        if (leadsToInsert.size() > 0) {
            List<Database.saveResult> srList = Database.insert(leadsToInsert, false);
            Log__c log = new Log__c();
            log.Origin__c = 'Callout to api.soluzionefotovoltaico.it';

            for (Database.saveResult sr : srList) {
                if (sr.isSuccess()) {
                    CampaignMember mem = new CampaignMember(CampaignId = data.CampaignId__c, LeadId = sr.getId() );
                    members.add(mem);
                } else {
                    if (log.Message__c != null) {
                        log.Message__c = log.Message__c + 'Lead creation failed: ' + sr.getErrors() + '\n';
                    } else {
                        log.Message__c = 'Lead creation failed: ' + sr.getErrors() + '\n';
                    }
                    
                }
            }
            if (log.Message__c != null) {
                log.Message__c = log.Message__c + 'List of leads: ' + '\n' + leadsToInsert;
            } else {
                log.Message__c = 'List of leads: ' + '\n' + leadsToInsert;
            }
            
            insert log;

            if (members.size() > 0) {
                try {
                    insert members;
                } catch (Exception e) {
                    System.debug(e.getMessage());
                    Log__c log2 = new Log__c( Message__c = 'Creation of Campaign members failed: ' + members, Timestamp__c = Datetime.now(),
                            Origin__c = 'Callout to api.soluzionefotovoltaico.it');
                    insert log2;
                }
            }
        }
    }

    private static Map<String, Boolean> checkForDuplicates(List<Lead> leads) {
        //  the method returns map with email as key (unique identifier for leads) and Boolean saying if the email already exists in another lead or a contact

        Map<String, Boolean> duplicateCheckMap = new Map<String, Boolean>();
        Set<String> emails = new Set<String>();
        for (Lead l : leads) {
            if (!String.isBlank(l.Email)) {
                emails.add(l.Email);
            }
        }
        List<Lead> existingLeads = [SELECT Id, Email FROM Lead WHERE Email IN:emails];
        List<Contact> existingContacts = [SELECT Id, Email FROM Contact WHERE Email IN:emails];

        Map<String, Lead> leadsMap = new Map<String, Lead>();
        Map<String, Contact> contactsMap = new Map<String, Contact>();
        for (Lead l : existingLeads) {
            leadsMap.put(l.Email, l);
        }
        for (Contact c : existingContacts) {
            contactsMap.put(c.Email, c);
        }

        // check if the email already exists in a lead or contact
        for (String email : emails) {
            if (leadsMap.keySet().contains(email) || contactsMap.keySet().contains(email)) {
                duplicateCheckMap.put(email, true);
            } else {
                duplicateCheckMap.put(email, false);
            }
        }
        return duplicateCheckMap;
    }
}