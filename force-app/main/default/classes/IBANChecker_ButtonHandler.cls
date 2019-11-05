global class IBANChecker_ButtonHandler {
    
    webservice static String checkIban(Id bankDataId) {
        String str = invokeCheckIban(bankDataId);
        return str;
    }
    
    @AuraEnabled
    public static String checkIbanLightning(Id bankDataId) {
        String str = invokeCheckIban(bankDataId);
        return str;
    }
    
    private static String invokeCheckIban(Id bankDataId) {
        
        List<BankData__c> bdList = new List<BankData__c>();
        BankData__c bd = [SELECT Id, IBAN__c, IBANCheckResult__c FROM BankData__c WHERE Id = :bankDataId];
        
        if (bd.IBAN__c != null && bd.IBANCheckResult__c == null) {
            bdList.add(bd);
            IBANChecker4 ic = new IBANChecker4(bdList);
            ID jobID = System.enqueueJob(ic);
            return 'Success: the request to validate IBAN has been sent';
        } else if (bd.IBANCheckResult__c != null) {
            return 'Error: the request has not been sent, as the IBAN had been already validated. See IBAN check result field.';
        } else if (bd.IBAN__c == null) {
            return 'Error: IBAN field cannot be empty.';
        } else {
            return 'Error occurred. The request has not been sent. Contact your Salesforce admin';
        }
    }
}