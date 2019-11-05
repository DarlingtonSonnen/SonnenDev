trigger beforeInvoice on invt__Invoice__c (before update) {

    Set<Id> iSet = new Set<Id>();
    
    for(invt__Invoice__c inv : Trigger.New) {
        
        if(String.isNotEmpty(inv.invt__Partner_Id__c) && inv.INVTX__Update_PDF__c == NULL) {
            iSet.add(inv.Id);
            //xeroReqs.add(new INVTX__Xero_Request_Queue__c(INVTX__Object_Type__c='Invoice_PDF', INVTX__Object_Id__c=inv.Id, INVTX__Status__c='Queued'));
        }
    }
    
    if(!iSet.isEmpty())
        OpportunityInvoice.queueInvoicePdf(iSet);
}