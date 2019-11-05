/* Author: Bartosz Jarmolinski
*  Created on 24/05/2018
*
*  Version 1.1 on 09/11/2018 by Bartosz
*  - Added error handling if no asset found in salesforce based on the asset/ticket number sent to the BatteryErrors endpoint
*
*/

@RestResource(urlMapping='/BatteryErrors/v1/*')
global with sharing class BatteryErrorsEndpoint {
    
    @HttpPost
    global static void CreateErrorMessage() {
    	
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req = RestContext.request;
        res = RestContext.response;
    	
    	String jsonBody = req.requestBody.toString();
    	ErrorWrapper er = (ErrorWrapper) JSON.deserialize(jsonBody, ErrorWrapper.class);
    	System.debug('wrapper: '+er);
    	
    	JSONGenerator gen = JSON.createGenerator(true);
    	
    	if (er.ticket == null || er.code == null || er.alert_id == null || er.recipient == null) {
    		String s = 'One of the parameters is null: ticket, code, alert_id, recipient';
    		
			String body = generateMessage(s);
			
			res.addHeader('Content-Type', 'application/json');
    		res.StatusCode = 400;
    		res.responseBody = Blob.valueOf(body);
    		return;
    	}
    	
    	// query for respective metadata type and respective asset
	   	List<Asset> aList = [SELECT Id, INClientLanguage__c, SerialNumber FROM Asset WHERE SerialNumber =:er.ticket];
		System.debug(aList.size());
		Asset a;
		if (aList.size() > 0) {
			a = aList[0];
		} else {
			String s = 'No asset with the ticket number found in Salesforce: '+ er.ticket;
			String body = generateMessage(s);
			res.StatusCode = 400;
			res.responseBody = Blob.valueOf(body);
			res.addHeader('Content-Type', 'application/json');

			return;
		}
    	
    	String language = 'EN';
    	if (a.INClientLanguage__c != null) {
    		language = a.INClientLanguage__c;
    	}
    	
    	// identify error message field within custom metadata types
		String erf = 'X' + er.code + '__c';
    	String queryString = 'SELECT '+erf + ' FROM ErrorMessage__mdt WHERE Label = \'Message\' AND Language__c = :language LIMIT 1';
    	System.debug('mdt query: '+queryString);
    	
    	ErrorMessage__mdt erm = Database.query(queryString);
    	
    	// check if the error message for the recipient with the same alert_id already exists
    	List<DeviceError__c> existingErrors = [SELECT Asset__c, AlertId__c, Recipient__c, Resolved__c, Message__c, Code__c FROM DeviceError__c 
    											WHERE  AlertId__c =: er.alert_Id AND Recipient__c =: er.recipient];
    									
   		System.debug(er.data);
		
	
		DeviceError__c de = new DeviceError__c();
		
		if (existingErrors.size() > 0) {
			String s = 'there is already an error message for the same recipient and alert_id';
			
			String body = generateMessage(s);
			
			res.StatusCode = 400;
    		res.responseBody = Blob.valueOf(body);
    		res.addHeader('Content-Type', 'application/json');
    		
    		return;
    	
		} else {
			de.Asset__c = a.Id;
			de.AssetSerialNumber__c = er.ticket;
			de.AlertId__c = er.alert_Id;
			de.Recipient__c = er.recipient;
			de.Resolved__c = er.resolved;
			de.Message__c = (String) erm.get(erf);
			de.Code__c = er.code;
            de.AlertGeneratedDate__c = DateTime.valueOfGmt(er.alert_creation);
			if (er.data.last_contact != null) {
				de.Time__c = DateTime.valueOfGmt(er.data.last_contact);
			} 
			if (er.data.latest_software != null) {
				de.LatestSoftware__c = er.data.latest_software;
			}
			if (er.data.offline_grace_time != null) {
				de.OfflineGraceTime__c = er.data.offline_grace_time;
			}
		}
		
		try {
			upsert de;
		} catch (Exception e) {
			res.StatusCode = 400;
			res.responseBody = Blob.valueOf(e.getMessage());
			res.addHeader('Content-Type', 'application/json');
		}
		
    }
    
    @HttpPatch
    global static void AlertResolved() {
    	
    	RestRequest req = RestContext.request;
    	RestResponse res = RestContext.response;
    	
    	String jsonBody = req.requestBody.toString();
    	List<String> uriElements = req.requestURI.split('/');
    	String alertId = uriElements[uriElements.size() - 1];
    	
    	Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);   	
    	//String alertId = (String) m.get('alert_id');
    	Boolean resolved = (Boolean) m.get('resolved');

    	List<DeviceError__c> deList = [SELECT Id, AlertId__c, Resolved__c FROM DeviceError__c WHERE AlertId__c =: alertId];
    	System.debug(deList.size());
    	if (deList.size() > 0) {
    		for (DeviceError__c de : deList) {
	    		de.Resolved__c = (Boolean) m.get('resolved');
	    	}
	    	
    	} else {

    		String s = 'No alerts found with the specified alert_id: '+ alertId;    		
    		String body = generateMessage(s);
    		
    		res.StatusCode = 400;
    		res.responseBody = Blob.valueOf(body);
    		res.addHeader('Content-Type', 'application/json');
    		
    		return;
    	}
			    
    	try {
    		update deList;
    		res.StatusCode = 204;
    	} catch (Exception e) {
    		
    		res.StatusCode = 400;
    		res.responseBody = Blob.valueOf(e.getMessage());
    		res.addHeader('Content-Type', 'application/json');
    	}
    	
    }
    
    private static String generateMessage(String s) {
    	
    	JSONGenerator gen = JSON.createGenerator(true);
		
		gen.writeStartObject();
		gen.writeStringField('Error', s);
		gen.writeEndObject();
		String body = gen.getAsString();
		
		return body;
    }
    
    public class ErrorWrapper {
    	public String ticket; // Asset serial number in salesforce
    	public String code;
    	public String alert_Id;
    	public String recipient;
    	public Boolean resolved;
        public String alert_creation;
    	public ErrorData data;
    }
    public class ErrorData {
    	public String last_contact;
    	public String latest_software;
    	public String offline_grace_time;
    }
}