@RestResource(urlMapping='/sbc')

global class WebserviceSbcListing {
    
    @HttpGet
    global static Response buildSbcList() {
        
        SavePoint sp = Database.setSavepoint();
        
        try {
            
            RestRequest req = RestContext.request;
            //Blob body = req.requestBody;
            //String bodyString = body.toString();
            
            Response resp = new Response();
            resp.sbclist   = getSbcList(new Map<String, String>());
            resp.status = 'OK';
            resp.message  = '';
            
            return resp;
        }
        catch(Exception e) {
            
            Response resp = new Response();
            resp.sbclist   = null;
            resp.status = 'ERROR';
            resp.message  = e.getMessage();
            
            Database.rollback(sp);
            
            return resp;
            
        }
    }
    
    global static SBC[] getSbcList(Map<String, String> filter) {
        
        if (SonnenbatterieConstants.ACC_RT_SBC == NULL) {
            throw new SbcListException('No record type filter defined.');
        }
        SBC[] sbclist = new List<SBC>();
        Account[] lAccs = [
            SELECT	Name, 
            BillingStreet, 
            BillingPostalCode, 
            BillingCity, 
            BillingCountry
            FROM 	Account
            WHERE 	RecordTypeId = : SonnenbatterieConstants.ACC_RT_SBC
            ORDER BY BillingCountry ASC, BillingPostalCode ASC];
        
        if (lAccs.isEmpty() ) {
            throw new SbcListException('No SBC records found.');
        }
        else {
            for (Account a : lAccs) {
                
                SBC oSbc = new SBC();
                
                oSbc.name = a.name;
                oSbc.address = a.BillingStreet;
                oSbc.postalcode = a.BillingPostalCode;
                oSbc.city = a.BillingCity;
                oSbc.country = a.BillingCountry;
                
                sbclist.add(oSbc);
            }      
        }
        
        return sbclist;
    }
    
    global class Response {
        public String 	status;
        public String	message;
        public SBC[]	sbclist;
    }
    
    global class SBC {
        public String 	name;
        public String 	address;
        public String	postalcode;
        public String	city;
        public String 	country;
    }
    
    private class SbcListException extends Exception {}
    
}