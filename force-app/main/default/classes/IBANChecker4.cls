/*
* @Author: Bartosz Jarmolinski
*
* Version 1.3
* + logic to search through existing BankData searching for the same IBAN before making the callout
* + saving IBAN in upper case
* 
* Version 1.2
* Added if statement to handle situation where no BIC is provided - line 91
* Allowed partial processing - line 108 if one or more records fail, the data for the successful ones is saved
* 
* Version 1.1
* Added cleanIban variable calculation - removing spaces and invalid characters from IBAN
*
* @Created: 28/02/2018
* the class queues callouts to iban-rechner service in order to obtain additional info about the bank and bank account
* the code is tested by IBANChecker2_Test
* 
*/
public class IBANChecker4 implements Queueable, Database.AllowsCallouts{
    
    private List<BankData__c> bdList {get; set;}
    
    public IBANChecker4(List<BankData__c> bdList) {
        this.bdList = bdList;
    }
    
    public void execute(QueueableContext context) {
        checkIBAN(bdList);
        System.debug(bdList.size());
    }
    
    public static void checkIBAN(List<BankData__c> bdList) {
        System.debug(bdList);
        System.debug(bdList.size());

        // create set of IDs passed to the method in order to requery the records to be updated - this is to avoid collection ready-only error
        Set<Id> bankDataIds = new Set<Id>();
        for(BankData__c bd : bdList) {
            bankDataIds.add(bd.Id);            
        }

        List<BankData__c> newBdList = new List<BankData__c>();
        List<BankDataSetting__mdt> bds = [SELECT Username__c, Password__c, Url__c FROM BankDataSetting__mdt WHERE MasterLabel = 'TriggerSettings'];

        // add logic to search trough existing IBAN data
        Map<String, BankData__c> existingMap = new Map<String, BankData__c>();

        ///
        List<BankData__c> bankDataList = [SELECT Id, IBAN__c, BankName__c, BankAddress__c, BankCode__c, BIC__c, Branch__c, IBANValidated__c, Balance__c, IBANCheckResult__c FROM BankData__c WHERE IBANCheckResult__c != NULL OR Id IN: bankDataIds];
        List<BankData__c> bdListQueried = new List<BankData__c>();
        List<BankData__c> existingList = new List<BankData__c>();
        for (BankData__c b : bankDataList) {
            if (bankDataIds.contains(b.Id)) {
                bdlistQueried.add(b);
            }
            if (b.IBANCheckResult__c != NULL) {
                //existingList.add(b);
                existingMap.put(b.IBAN__c, b);
            }
        }

        while(bdListQueried.size() > 0) {

            System.debug(bdListQueried);
            BankData__c bn =  bdListQueried.remove(0);
            String cleanIban = bn.IBAN__c.replaceAll('[^a-zA-Z0-9]', '').toUpperCase();
            System.debug(cleanIban);

            if (existingMap.keySet().contains(cleanIban)) {

                // if IBAN already exists in salesforce handle data without making callout
                BankData__c ref = existingMap.get(cleanIban);
                bn.BankName__c = ref.BankName__c;
                bn.BankAddress__c = ref.BankAddress__c;
                bn.BankCode__c = ref.BankCode__c;
                bn.BIC__c = ref.BIC__c;
                bn.IBANCheckResult__c = ref.IBANCheckResult__c;
                bn.Branch__c = ref.Branch__c;
                bn.IBANValidated__c = ref.IBANValidated__c;
                bn.Balance__c = ref.Balance__c;
                newBdList.add(bn);

            } else {
                //  else (if IBAN does not exist in Salesforce yet) process the callout logic

                System.debug(Limits.getLimitQueueableJobs() > Limits.getQueueableJobs());
                System.debug(Limits.getLimitCallouts() > Limits.getCallouts());
                if(Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && Limits.getLimitCallouts() > Limits.getCallouts()) {

                    //construct http callout
                    String endpointUrl = bds[0].Url__c + cleanIban;

                    Http h = new Http();
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(endpointUrl);
                    req.setMethod('GET');
                    
                    Blob headerValue = Blob.valueOf(bds[0].Username__c +':'+ bds[0].Password__c); 
                    String authorizationHeader = 'Basic '+ EncodingUtil.base64Encode(headerValue);

                    req.setHeader('Authorization', authorizationHeader);
                    
                    HttpResponse res = new HttpResponse();
                    if(Test.isRunningTest()) {

                        String body = '{ "iban": "IE92BOFI90001710027952", "result": "passed", "return_code": 0, "checks": [ "length", "bank_code", "account_number", "iban_checksum" ], "bic_candidates": [ { "bic": "BOFIIE2DXXX", "zip": "", "city": "", "wwwcount": 0, "sampleurl": "" } ], "all_bic_candidates": [ { "bic": "BOFIIE2DXXX", "zip": "", "city": "", "wwwcount": 0, "sampleurl": "" } ], "country": "IE", "bank_code": "900017", "bank": "Bank of Ireland", "bank_address": "c/o 2 College Green Dublin 2 ", "bank_street": "c/o 2 College Green", "bank_city": "Dublin", "bank_state": "", "bank_postal_code": "2", "bank_url": "", "branch": "", "branch_code": "", "balance": 9999 }';
                        SingleRequestMock mockResponse = new SingleRequestMock(200, 'Completed', body, null);
                        res = mockResponse.respond(req);

                    }                
                    else {
                        res = h.send(req);
                    }
                    
                    System.debug(res.getStatusCode());
                    if(res.getStatusCode() == 200) {

                        String body = res.getBody();
                        System.debug(body);
                        wrapperClass wrap = (wrapperClass) JSON.deserialize(body, wrapperClass.class);
                        System.debug(wrap);
            
                        bn.BankName__c = wrap.bank;
                        bn.BankAddress__c = wrap.bank_address;
                        bn.BankCode__c = wrap.bank_code;
                        if (wrap.bic_candidates.size() > 0) {
                            bn.BIC__c = wrap.bic_candidates[0].get('bic');
                        }
                        bn.IBANCheckResult__c = wrap.result;
                        bn.Branch__c = wrap.branch;
                        bn.IBANValidated__c = Datetime.now();
                        bn.Balance__c = wrap.balance;
                        bn.IBAN__c = cleanIban;
                        
                        newBdList.add(bn);
                    }
                }
                else {
                    break;
                }
            }
        }

        Database.update(newBdList, false);

        if(bdListQueried.size() > 0) {
            IBANChecker4 q = new IBANChecker4(bdListQueried);
            System.enqueueJob(q);
        }
    }
    class wrapperClass {
        String iban;
        String result;
        String bank;
        List<Map<String, String>> bic_candidates;
        String bank_code;
        String bank_address;
        String branch;
        String branch_code;
        Decimal balance;
    }
}