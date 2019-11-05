public class OpportunityInvoice {

    public static void createInvoice(List<Opportunity> triggerList) {
        
        List<Opportunity> workingList = new List<Opportunity>();
        
        for(Opportunity o : triggerList) {
            
            if(o.AccountId != NULL && o.PrimaryContact__c != NULL && o.Financing__c != 'FullFinancing' && o.Create_Invoice__c == 'Yes') {
                
                workingList.add(o);
            }
        }
        
        if(!workingList.isEmpty()) {
            
            workingList = [SELECT Id, AccountId, PrimaryContact__c, CloseDate, Invoice_Due_Date__c, Invoice_Customer_Number__c, Invoice_Branding_ID__c, RecordType.DeveloperName, Financing__c, CurrencyIsoCode, 
                           (SELECT Id, Product2Id, Quantity, UnitPrice, DownPayment__c, Down_Payment_Ex__c, Description, SalesPriceNet__c, Product2.Invoice_Item__c, Product2.RecordType.DeveloperName, Product2.Description, Product2.Invoice_Account__c, Product2.Invoice_Tax_Rate__c FROM OpportunityLineItems
                           WHERE Product2.RecordType.DeveloperName IN ('Payment','Service','Standard','Subsidy')) 
                           FROM Opportunity WHERE Id IN :workingList];
            
            Map<Id, invt__Invoice__c> iMap = new Map<Id, invt__Invoice__c>();
            
            for(Opportunity o : workingList) {
                
                if(!o.OpportunityLineItems.isEmpty()) {
                    
                    invt__Invoice__c i = new invt__Invoice__c();
                    
                    i.CurrencyIsoCode = o.CurrencyIsoCode;
                    i.invt__Opportunity__c = o.Id;
                    i.invt__Account__c = o.AccountId;
                    i.invt__Contact__c = o.PrimaryContact__c;
                    i.invt__Date__c = System.Today();
                    i.invt__Due_Date__c = o.Invoice_Due_Date__c;
                    i.invt__Reference__c = o.Invoice_Customer_Number__c;
                    i.invt__Branding_Theme__c = o.Invoice_Branding_ID__c;
                    i.invt__Type__c = 'ACCREC';
                    i.invt__Status__c = 'AUTHORISED';
                    
                    iMap.put(o.Id, i);
                    
                }
            }
            
            insert iMap.values();
            
            List<invt__Invoice_Line_Item__c> iliList = new List<invt__Invoice_Line_Item__c>();
            for(Opportunity o : workingList) {
                SYstem.Debug('o.OpportunityLineItems '+o.OpportunityLineItems);
                for(OpportunityLineItem oli : o.OpportunityLineItems) {
                    
                    if((oli.Product2.RecordType.DeveloperName != 'Payment' && o.Financing__c != 'PartFinancing')
                       || (oli.Product2.RecordType.DeveloperName == 'Payment' && o.Financing__c == 'PartFinancing')) {
                        
                        invt__Invoice_Line_Item__c l = new invt__Invoice_Line_Item__c();
                        
                        l.invt__Invoice__c = iMap.get(o.Id).Id;
                        l.CurrencyIsoCode = o.CurrencyIsoCode;
                        l.invt__Description__c = oli.Product2.Description;
                        l.invt__Invoice_Account__c = oli.Product2.Invoice_Account__c;
                        l.invt__Invoice_Tax_Type__c = oli.Product2.Invoice_Tax_Rate__c;
                        
                        l.invt__Quantity__c = oli.Quantity;
                           
                        l.invt__Unit_Amount__c = oli.Product2.RecordType.DeveloperName == 'Payment' ? oli.Down_Payment_Ex__c : oli.SalesPriceNet__c;
                        
                        iliList.add(l);
                    }
                }
                
            }
            
            insert iliList;
            
            for(invt__Invoice__c i : iMap.values())
                i.invt__Sync_With_Partner__c = 'Yes';
            
            update iMap.values();
            
        }
        
        
    }
    
    @future
    public static void queueInvoicePdf(Set<Id> iSet) {
        
        List<INVTX__Xero_Request_Queue__c> xeroReqs = new List<INVTX__Xero_Request_Queue__c>();
        
        for(Id i :iSet) {
            
            xeroReqs.add(new INVTX__Xero_Request_Queue__c(INVTX__Object_Type__c='Invoice_PDF', INVTX__Object_Id__c=i, INVTX__Status__c='Queued'));
        }
        
        if(!xeroReqs.isEmpty())
            insert xeroReqs;
    } 
    
}