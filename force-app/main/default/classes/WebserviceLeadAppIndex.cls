@RestResource(urlMapping='/leadapp/*')

global class WebserviceLeadAppIndex {
    private boolean isUnauthorized;
    
    @HttpGet
    global static CampaignResponse getRunningCampaignsAndStaff() {
        
        SavePoint sp = Database.setSavepoint();
        
        try {
            
            RestRequest req = RestContext.request;
            
            if (req.headers.get('AuthToken') != 'YXBwOnBhc3N3b3Jk') {
                throw new LeadAppException('Unauthorized');
            }
            
            CampaignResponse resp = new CampaignResponse();
            resp.payload   = getCampaignStaff( new Map<String, String>());
            resp.status = '200 - OK';
            resp.message = (resp.payload == null) ? 'Finished without errors, but result set is empty.' : '';
            system.debug('WebserviceLeadAppIndex - getRunningCampaignAndStaff(). Response: ' + resp);
            return resp;
        }
        catch(Exception e) {
            
            CampaignResponse resp = new CampaignResponse();
            resp.payload   = null;
            resp.status = 'ERROR';
            resp.message  = e.getMessage();
            
            Database.rollback(sp);
            
            return resp;
            
        }
    }
    
    @HttpPost
    global static LeadResponse saveCampaignLeads() {
        
        Log errorLog = new Log();
        
        SavePoint eineSchritteSuruck = Database.setSavepoint();
        
        try {
            
            RestRequest req = RestContext.request;
            
            if (req.headers.get('AuthToken') != 'YXBwOnBhc3N3b3Jk') {
                throw new LeadAppException('Unauthorized');
            }
            
            System.debug(req.requestBody);
            Blob body = req.requestBody;
            String bodyString = body.toString();
            
            errorLog.add('endpoint request body', bodyString);
            
            LeadResponse resp = new LeadResponse();
            resp.payload  = saveCampaignLeads(bodyString);
            resp.status = '200 - OK';
            resp.message = (resp.payload == null) ? 'Finished without errors, but result set is empty.' : '';
            
            errorLog.add('endpoint response payload', string.valueOf(resp.payload));
            errorLog.add('endpoint response message', resp.message);
            errorLog.save();
            return resp;
        }
        catch(Exception e) {
            
            LeadResponse resp = new LeadResponse();
            resp.payload   = null;
            resp.status = 'ERROR';
            resp.message  = e.getMessage();
            if (resp.message == 'Unauthorized') {
                resp.status = '403 - ' + resp.status;
            }
            
            Database.rollback(eineSchritteSuruck);
            
            errorLog.add('endpoint response payload', string.valueOf(resp.payload));
            errorLog.add('endpoint response message', resp.message);
            errorLog.save();
            return resp;
            
        }
    }
    
    global static CampaignStaff[] getCampaignStaff(Map<String, String> filter) {

        CampaignTeam__c[] lStaff = [ SELECT  Campaign__c,
                                             Campaign__r.Name,
                                             Campaign__r.LocationStreet__c,
                                             Campaign__r.LocationPostalCode__c,
                                             Campaign__r.LocationCity__c,
                                             Campaign__r.LocationState__c,
                                             Campaign__r.LocationCountry__c,
                                    		 Campaign__r.TargetCountry__c,
                                             TeamMember__c,
                                             TeamMember__r.FirstName__c,
                                             TeamMember__r.LastName__c,
                                             TeamMember__r.Email__c,
                                             TeamMember__r.Phone__c 
                                    FROM    CampaignTeam__c
                                    WHERE   Campaign__r.isActive = true
                                    AND     Campaign__r.Type IN : SonnenbatterieConstants.CAMPAIGN_TYPES_PROJECT 
                                    ORDER BY Campaign__r.Id ASC, TeamMember__r.LastName__c ASC];
        
        if (SonnenbatterieConstants.CAMPAIGN_TYPES_PROJECT == NULL) {
        	system.debug('WebserviceLeadAppIndex - getCampaignStaff(). RT is null');
            throw new LeadAppException('Error fetching records. No filter criteria available to find projects.');
        }
        
        if (lStaff.isEmpty() ) {
            system.debug('WebserviceLeadAppIndex - getCampaignStaff(). lStaff is empty');
            throw new LeadAppException('No projects found.');
        }
		
        system.debug('WebserviceLeadAppIndex - getCampaignStaff(). gating done');
        // initializing flow control variables

        List<CampaignStaff> payload = new List<CampaignStaff>(); 
        Id campaignIterationControl;
        CampaignStaff currentStaff;
		Integer i = 1;
        
        for (CampaignTeam__c oCampTeam : lStaff) {
			
            System.debug('Iteration starts: ' + i);
            
            
            if (oCampTeam.Campaign__c != campaignIterationControl) {
                
                if (currentStaff != NULL) {
                    
                    system.debug('adding an item to payload');
                    payload.add(currentStaff);
                }
                
                system.debug('resetting currentstaff');
                
                currentStaff    = new campaignstaff();
                currentStaff.campaign = new campaignItem();
                currentStaff.campaignstaff = new List<campaignStaffItem>();
                
            }
			
            
            campaignIterationControl = oCampTeam.Campaign__c;
			System.debug('Campaign: ' + oCampTeam.Campaign__r.Name);
            
            currentStaff.campaign.campaignid = oCampTeam.Campaign__c;
            currentStaff.campaign.campaignname = oCampTeam.Campaign__r.Name;
            currentStaff.campaign.street = oCampTeam.Campaign__r.LocationStreet__c;
            currentStaff.campaign.city = oCampTeam.Campaign__r.LocationCity__c;
            currentStaff.campaign.postalcode = oCampTeam.Campaign__r.LocationPostalcode__c;
            currentStaff.campaign.state = oCampTeam.Campaign__r.LocationState__c;
            currentStaff.campaign.country = oCampTeam.Campaign__r.LocationCountry__c;
            currentStaff.campaign.targetcountry = oCampTeam.Campaign__r.TargetCountry__c;
			
            CampaignStaffItem staffmember = new campaignstaffitem();
            
            System.debug('Campaign Team Member: ' + oCampTeam.TeamMember__r.FirstName__c + ' ' + oCampTeam.TeamMember__r.LastName__c);

            staffmember.campaignid = oCampTeam.Campaign__c;
            staffmember.staffid = oCampTeam.TeamMember__c;
            staffmember.firstname = oCampTeam.TeamMember__r.FirstName__c;
            staffmember.lastname = oCampTeam.TeamMember__r.LastName__c;
            staffmember.email = oCampTeam.TeamMember__r.Email__c;
            staffmember.phone = oCampTeam.TeamMember__r.Phone__c;

            currentStaff.campaignstaff.add(staffmember);
            
            if (i == lStaff.size()) {
                    system.debug('final iteration reached');
                    payload.add(currentStaff);
            }
            i++;
        }
        system.debug('WebserviceLeadAppIndex - getCampaignStaff(). Payload is ' + payload);
        return payload;
    }
    
    global static CampaignLead[] saveCampaignLeads(String requestBody) {
        
        Integer 				errorCount = 0;
        Integer					updateCount = 0;
        Integer					insertCount = 0;
        Id 						campaignId;
        List<Lead> 				lLeads;
        List<CampaignMember>	lCampaignMembers = new List<CampaignMember>();
        List<CampaignLead> 		lCampaignLeads = new List<CampaignLead>();
        List<Database.UpsertResult> lUpsertResult;
        Map<Id, Campaign>		mCampaigns = new Map<Id, Campaign>([
            SELECT Id, OwnerId FROM Campaign
        ]);
        Log errorLog = new Log();
        
        if (!requestBody.contains('[') && !requestBody.contains(']')) {
            requestBody = '[' + requestBody + ']';
        }
        
        try {
            lLeads = (List<Lead>) JSON.deserialize(requestBody, List<Lead>.class);
            
            if (lLeads.size() > 0) {
            	campaignId = (Id) lLeads.get(0).ApiCampaign__c;    
            }
            
            for (Lead l : lLeads) {   
        
            	if (mCampaigns.get(l.ApiCampaign__c) != NULL) {
                	l.OwnerId =  mCampaigns.get(l.ApiCampaign__c).OwnerId;
                    l.CreatedByUser__c = mCampaigns.get(l.ApiCampaign__c).OwnerId;
                	System.debug('Owner: ' + l.OwnerId );
 				}
                if (l.LeadSource == 'app') {
                    l.LeadSource = 'PoS';
                }
            }
        }
        catch (Exception e) {
            throw new LeadAppException('Deserialization failed. Request body maybe corrupt or not satisfying requiremnets for List<Lead>');
        }
        
        try {
        	lUpsertResult = Database.upsert(lLeads, Lead.ExtId__c.getDescribe().getSObjectField(), false);
        }
        catch (DMLException e) {
            throw new LeadAppException('Database upsert failed. Message: ' + e);
        }        
        
        
        System.debug(lUpsertResult);
        
        Integer i = 0; // helper 
        for (Lead l : lLeads) {   
        
            CampaignLead cl = new CampaignLead();
            CampaignMember cm = new CampaignMember();
            Database.UpsertResult u = lUpsertResult.get(i);
            System.debug('DEBUG: Upsert Result: ' + u);
            System.debug('DEBUG: Original Lead: ' + l);
            errorLog.add('endpoint - upsert result ', sTring.valueOf(u));
            
            i++;
            
            if (u.getErrors() != NULL ) {
            	cl.Status   = 'UPSERT: failure. Message: ' + u.getErrors(); 
            	errorCount++;
            }
            
            if (u.isSuccess() ) {
                cl.Status = 'UPDATE: success';
                updateCount++;
            }
            
            if (u.isCreated() ) {
                cl.Status = 'INSERT: success';
                insertCount++;
            }
            
            cl.record = l;
                
            if (mCampaigns.get(l.ApiCampaign__c) != NULL) {
                cl.record.OwnerId =  mCampaigns.get(l.ApiCampaign__c).OwnerId;
            }
            
            lCampaignLeads.add(cl);
            
            if (l.Id != NULL && campaignId != NULL) {
                cm.LeadId = l.Id;
                cm.Status = 'Sent';
                cm.CampaignId = campaignID;
                lCampaignMembers.add(cm);
            }
            
            try {
                if (!lCampaignMembers.isEmpty() ) {
                    errorlog.add('endpoint adds campaign members', string.valueOf(lCampaignMembers));
                	Database.insert(lCampaignMembers, false);    
                }
                
            }
            catch (DMLException e) {
                errorLog.add('endpoint adding campaign members failed','');
                throw new LeadAppException('Associating lead with a campaign failed. Message: ' + e);
            }
            
            
        }
        errorLog.save();
        return lCampaignLeads;
    }

    // generic response type and payload 

    global class LeadResponse {
        String status;
        String message;
        CampaignLead[] payload;
    }

    global class CampaignResponse {
        String status;
        String message;
        CampaignStaff[] payload;
    }

    global class CampaignStaff {
        CampaignItem campaign;
        List<CampaignStaffItem> campaignstaff;
    }

    global class CampaignStaffItem {
        String  campaignid;
        String  staffid;
        String  firstname;
        String  lastname;
        String  email;
        String  phone;

    }

    global class CampaignItem {
        String  campaignid;
        String  campaignname;
        String  street;
        String  city;
        String  postalcode;
        String  state;
        String  country;
        String  targetcountry;

    }
    
    global class CampaignsWithLeads {
        global Id   campaignId;
        global CampaignLead[] leads;
    }

    global class CampaignLead {
        global String status;
        global Lead record;
    }
    
    global class InnerLead {
        global List<Map<String, String>> tokens;
    }
    
    private class LeadAppException extends Exception {
        
        String code;
        
    }
    
    private class Log {
        
        private List<Log__c> entries;
        
        Log () {
            this.entries = new List<Log__c>();
        }
        void add(String caller, String message) {
            Log__c log = new Log__c();
            log.timeStamp__c = Datetime.now();
            log.origin__c = caller;
            log.message__c = message;
            
            this.entries.add(log);
        }
        
        void save() {
            if(!this.entries.isEmpty()) {
                insert this.entries;
            }
        }
    }
    
}