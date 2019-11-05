/*
 * Created by b.jarmolinski on 10/08/2018.
 * 
 * Version 1.1 by Bartosz on 05/11/2018
 * - exchanged execution of if clauses: if(cdLinks.size() > 0) and if(invoiceIdMap.values().size() > 0) - the latter makes callouts and the first makes DML 
 * 		(callout after DML caused failed execution)
 */


public without sharing class zuoraGetInvoice {

    List<String> zuoraInvList; // list to hold zuora invoice IDs
    List<Zuora__ZInvoice__c> invoiceList;
    Map<String, Id> invoiceNameMap = new Map<String, Id>(); // invoice name as key, billing account salesforce Id as value

//    public zuoraGetInvoice(List<String> zuoraInvList ) {
//        this.zuoraInvList = zuoraInvList;
//    }
//    public zuoraGetInvoice(String zuoraInvId) {
//        this.zuoraInvList = new List<String>{zuoraInvId};
//    }
    public zuoraGetInvoice(List<Zuora__ZInvoice__c> invoiceList) {
        this.invoiceList = invoiceList;
    }

    public void getInvoices() {
        System.debug(zuoraInvList);
        // check if files already exist
        if (this.invoiceList == null) {
            System.debug([SELECT Id, Name, Zuora__Zuora_Id__c, Zuora__BillingAccount__c FROM Zuora__ZInvoice__c WHERE Zuora__Zuora_Id__c IN:zuoraInvList ].size());
            this.invoiceList = [SELECT Id, Name, Zuora__Zuora_Id__c, Zuora__BillingAccount__c FROM Zuora__ZInvoice__c WHERE Zuora__Zuora_Id__c IN:zuoraInvList ];
        }

        Set<String> invoiceNames = new Set<String>(); // for querying content versions related to the invoices
        for (Zuora__ZInvoice__c inv : invoiceList) {
            invoiceNames.add(inv.Name);
        }

        // query content versions with the invoice names
        List<ContentVersion> cvList = [SELECT Id, ContentDocumentId, PathOnClient FROM ContentVersion WHERE PathOnClient IN:invoiceNames];
        Map<String, Id> contentDocsMap = new Map<String, Id>(); // invoice/file name as key, ContentDocumentId as values

        for (ContentVersion cv : cvList) {
            contentDocsMap.put(cv.PathOnClient, cv.ContentDocumentId);
        }

        List<ContentDocumentLink> cdLinks = new List<ContentDocumentLink>();
        Map<String, String> invoiceIdMap = new Map<String, String>(); // zuora invoice ID as key, zuora account id as value

        for (Zuora__ZInvoice__c inv : this.invoiceList) {

            if (contentDocsMap.get(inv.Name) != null) {
                // create content doc link because file already exists in salesforce
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = contentDocsMap.get(inv.Name);
                cdl.LinkedEntityId = inv.Id;
                cdl.ShareType = 'V';
                if (!String.isBlank(cdl.LinkedEntityId)) {
                    cdLinks.add(cdl);
                }

            } else {
                // invoke zuoraGetInvoiceFiles_Queueable - the file is not yet in salesforce and needs to be queried from zuora
                invoiceIdMap.put(inv.Zuora__Zuora_Id__c, inv.Zuora__BillingAccount__c);

                // populate invoiceNameMap which will be used for sending emails with the invoice attached from the queueable class
                this.invoiceNameMap.put(inv.Name, inv.Zuora__BillingAccount__c);

            }
        }
        if (invoiceIdMap.values().size() > 0) {
            System.debug(invoiceIdMap);
            
            zuoraSetting__mdt settings = ZuoraSettings.getZuoraSetting();

            HttpResponse res = zuoraLogin.loginZuora(settings);
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String accessToken = (String) resMap.get('access_token');

            zuoraGetInvoiceFiles_QueueableV2 que = new zuoraGetInvoiceFiles_QueueableV2(invoiceIdMap, this.invoiceNameMap, accessToken, settings);
            System.enqueueJob(que);
        }
        
        if (cdLinks.size() > 0) {
            //insert cdLinks;
            // allow partial insert
            Database.insert(cdLinks, false);
        }
    }
}