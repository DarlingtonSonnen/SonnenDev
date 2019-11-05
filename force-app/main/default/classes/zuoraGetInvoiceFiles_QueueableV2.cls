/*
 * Created by b.jarmolinski on 07/08/2018.
 *
 * 17/10/2018 by Bartosz
 * - changed email logic to which the invoice is sent - email of the primary contact is the first choice, if it is blank, then Bill-to-Contact's email is taken
 * 
 * 05/11/2018 by Bartosz
 * - set custom timeout to 60 seconds for query call to zuora - to avoid often time outs
 */

public with sharing class zuoraGetInvoiceFiles_QueueableV2 implements Queueable, Database.AllowsCallouts {
    private Map<String, String> invoiceIdMap; // zuora invoice ID as key, sF zuora account id as value
    private zuoraSetting__mdt settings;
    private String accessToken;
    private Map<String, Id> invoiceNameMap; // zuora invoice name (number) as key, billing account salesforce Id as value


    public zuoraGetInvoiceFiles_QueueableV2(Map<String, String> invoiceIdMap, Map<String, Id> invoiceNameMap, String accessToken, zuoraSetting__mdt settings) {
        this.invoiceIdMap = invoiceIdMap; // zuora invoice ID as key, zuora account id as value
        this.accessToken = accessToken;
        this.settings = settings;
        this.invoiceNameMap = invoiceNameMap; // set of invoice names generated from Tigger.new list

        List<ContentVersion> cvList = [SELECT Id, Title, PathOnClient, ContentDocumentId FROM ContentVersion WHERE PathOnClient IN:invoiceNameMap.keySet()];
        for (ContentVersion cv : cvList) {
            // PathOnClient field contains the invoice name but without .pdf, unlike the title field
            this.invoiceNameMap.put(cv.PathOnClient, cv.ContentDocumentId);
        }
    }

    public void execute(QueueableContext context) {
        GetFiles(this.invoiceIdMap, this.settings, this.accessToken, this.invoiceNameMap );
    }

    private static void GetFiles(Map<String, String> invoiceIdMap, zuoraSetting__mdt settings, String accessToken, Map<String, Id> invoiceNameMap ) {

        System.debug(invoiceIdMap);
        List<String> invoiceIdList = new List<String>(invoiceIdMap.keySet()); // list of invoice IDs
        List<Zuora__CustomerAccount__c> billingAccounts = [SELECT Id, Zuora__Zuora_Id__c, Zuora__BillToWorkEmail__c, Zuora__Account__c,
                                                            Zuora__Account__r.PrimaryContactEmail__c
                                                            FROM Zuora__CustomerAccount__c WHERE Id IN :invoiceIdMap.values()];

//        Map<String, Id> billingAccMap = new Map<String, Id>(); // Zuora__CustomerAccount__c map where zuora Id is the key and salesforce Id is the value
        Map<String, Zuora__CustomerAccount__c> billingAccMap = new Map<String, Zuora__CustomerAccount__c>(); // Zuora__CustomerAccount__c map where zuora Id is the key and salesforce Id is the value
        Map<String, Id> billingAccMapInv = new Map<String, Id>(); // zuora invoice Id as key and billing account salesforce Id is the value

        // create map of the zuora invoice number and the billing account in order to use the billing account in the email logic
        Map<Id, Zuora__CustomerAccount__c> billingAccountsMapInv = new Map<Id, Zuora__CustomerAccount__c>();

        for (Zuora__CustomerAccount__c a : billingAccounts) {
            billingAccMap.put(a.Zuora__Zuora_Id__c, a);
            billingAccountsMapInv.put(a.Id, a);
        }

        System.debug(billingAccMap.keySet().size());
        System.debug(billingAccMap.size());
        for (String s : invoiceIdList) {
            System.debug(s);
            System.debug(billingAccMap);
            System.debug(invoiceIdMap.get(s));

            //billingAccountsMapInv.put(s, billingAccMap.get(invoiceIdMap.get(s)) );
            billingAccMapInv.put(s, invoiceIdMap.get(s));
        }
        System.debug(billingAccMapInv);

        Map<String, ContentVersion> cVersionMap = new Map<String, ContentVersion>(); // invoice number/file name as key
        Map<String, ContentDocumentLink> cDocLinkMap = new Map<String, ContentDocumentLink>(); // invoice number/file name as key

        // get a map of billing account Id to Invoice Id in order to create content doc link to invoice as well
        Map<Id, Id> invIdMap = findInvoiceId(InvoiceIdMap);
        System.debug(invIdMap);

        // query content versions to see if files already exist
        //List<ContentVersion> contentFiles = [SELECT Id, PathOnClient, ContentDocumentId, VersionData FROM ContentVersion WHERE ]
        // create map of content name (title) and and content document Id
        //

        while(invoiceIdList.size() > 0) {

            String invoiceId = invoiceIdList.remove(0);
            String accountId = invoiceIdMap.remove(invoiceId);

            // add check if invoice file already exists, if if does create special class to handle that and continue to skip to the
            // next iteration



            if (Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && Limits.getLimitCallouts()-1 > Limits.getCallouts()) {
                // -1 in the conditions because there are two api callouts in the context

                String query = 'SELECT Id, AccountId, InvoiceNumber, Body FROM Invoice WHERE Id = \''+ invoiceId +'\'';

                JSONGenerator gen = JSON.createGenerator(true);
                gen.writeStartObject();
                gen.writeStringField('queryString', query);
                gen.writeEndObject();

                String body1 = gen.getAsString();

                Http h = new Http();
                HttpRequest req = new HttpRequest();
                req.setEndpoint(settings.BaseUrl__c + '/v1/action/query' );
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer '+ accessToken);
                req.setHeader('Content-Type', 'application/json');
                req.setBody(body1);
                req.setTimeout(60000);

                HttpResponse res = new HttpResponse();
                if (Test.isRunningTest()) {

                    String s = 'test file';
                    Blob b = Blob.valueOf(s);
                    String file = EncodingUtil.base64Encode(b);

                    String body = '{ "records": [ { "AccountId": " ' + accountId  +'", "InvoiceNumber": "INV00002392", "Body": "'+ file +'", "Id": "' + invoiceId +'" } ], "size": 1, "done": true }';
                    SingleRequestMock mock = new SingleRequestMock(200, 'Completed', body, null);
                    res = mock.respond(req);

                } else {
                    res = h.send(req);
                }

                if (res.getStatusCode() == 200) {

                    Map<String, Object> des1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> des2 = (List<Object>) des1.get('records');
                    Object obj = des2[0];
                    Map<String, Object> des3 = (Map<String, Object>) obj;
                    String pdfText = (String) des3.get('Body');
                    Blob b = EncodingUtil.base64Decode(pdfText);
                    String name = (String) des3.get('InvoiceNumber');


                    if (billingAccMapInv.get(invoiceId) != null) {

                        // create content file and attach it to the Zuora__CustomerAccount__c in zuora
                        ContentVersion cv = new ContentVersion();
                        cv.VersionData = b;
                        cv.Title = name+'.pdf';
                        cv.PathOnClient = name;
                        cv.ContentDocumentId = null;
                        cVersionMap.put(billingAccMapInv.get(invoiceId), cv); // billing account SF ID as key
                    }
                }
            } else {
                break;
            }
        }
        System.debug(cVersionMap.values().size());
        insert cVersionMap.values();
        //System.debug(cVersionMap);

        // create content document link

        // * get content document link for each CV
        Set<Id> cVersionIDs = new Set<Id>(); // content version IDs for query for contentDocumentLinks
        for (ContentVersion cv : cVersionMap.values()) {
            cVersionIDs.add(cv.Id);
        }

        // cvMapContDocId - map of content version Id and ContentVersion object (with content doc Id)
        Map<Id, ContentVersion> cvMapContDocId = new Map<Id, ContentVersion>([SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN:cVersionIDs]);

        System.debug(cvMapContDocId);

        // loop through the map of zAccount IDs and ContentVersions, create content doc link for each pair
        // in order to display the file on the zAccount in Salesforce
        List<ContentDocumentLink> cdList = new List<ContentDocumentLink>();


        for (Id i : cVersionMap.keySet()) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cvMapContDocId.get(cVersionMap.get(i).Id).ContentDocumentId;
            cdl.LinkedEntityId = i;
            cdl.ShareType = 'V';
            if (!String.isBlank(cdl.LinkedEntityId)) {
                cdList.add(cdl);
            }

            ContentDocumentLink cdi = new ContentDocumentLink();
            cdi.ContentDocumentId = cvMapContDocId.get(cVersionMap.get(i).Id).ContentDocumentId;
            cdi.LinkedEntityId = invIdMap.get(i);
            cdi.ShareType = 'V';
            if (!String.isBlank(cdi.LinkedEntityId)) {
                cdList.add(cdi);
            }
        }
        insert cdList;

        System.debug(billingAccountsMapInv);
        // send email to users
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // map of accountId and contactId - needed for sending emails - target Id must be a contact
        Map<Id, Id> contactMap = findContactId(billingAccounts);

        for (Id i : cVersionMap.keySet()) {
            System.debug(i);
            System.debug(billingAccountsMapInv.get(i));


            if(billingAccountsMapInv.get(i) != null) {
                Zuora__CustomerAccount__c billingAccount = billingAccountsMapInv.get(i);

                // email string to which the email is to be sent
                String email;
                if (!String.isBlank(billingAccount.Zuora__Account__r.PrimaryContactEmail__c)) {
                    email = billingAccount.Zuora__Account__r.PrimaryContactEmail__c;
                } else if (!String.isBlank(billingAccount.Zuora__BillToWorkEmail__c)) {
                    email = billingAccount.Zuora__BillToWorkEmail__c;
                }

                if (!String.isBlank(email)) {

                    System.debug(invIdMap);
                    System.debug(billingAccount.Id);
                    System.debug(invIdMap.get(billingAccount.Id));

                    List<String> toAddresses = new List<String>();
                    toAddresses.add(email);
                    List<Id> contentId = new List<Id>();
                    contentId.add(cVersionMap.get(i).Id);

                    Messaging.SingleEmailMessage sem = new Messaging.SingleEmailMessage();
                    sem.setEntityAttachments(contentId);
                    sem.setOrgWideEmailAddressId(settings.SentFromId__c);
                    sem.setToAddresses(toAddresses);
                    sem.setTargetObjectId(contactMap.get(billingAccount.Zuora__Account__c)); // mandatory field
                    sem.setTreatTargetObjectAsRecipient(false); // prevent sending the copy of email to the targetId user
                    sem.setTemplateId(settings.EmailTemplateIdInvoice__c);
                    sem.setWhatId(invIdMap.get(billingAccount.Id)); // must be salesforce id of the zuora invoice
                    sem.setSaveAsActivity(true);
                    emails.add(sem);

                }
            }
        }
        List<Messaging.SendEmailResult> result = Messaging.sendEmail(emails, false);
        System.debug(result);

        // create new queueable instance if there are still invoices to process
        if (invoiceIdList.size() > 0 ) {
            zuoraGetInvoiceFiles_QueueableV2 q2 = new zuoraGetInvoiceFiles_QueueableV2(invoiceIdMap, invoiceNameMap, accessToken, settings);
            System.enqueueJob(q2);
        }
    }
    
    private static Map<Id, Id> findInvoiceId(Map<String, String> InvoiceIdMap) {
        // return map consists of Id pairs of zuora__CustomerAccount__c as key and Id of Zuora__ZInvoice__c as value
        // the map to be used for creation of content document links between invoices and downloaded invoice files

        Map<Id, Id> invIdMap = new Map<Id, Id>();
        List<Zuora__ZInvoice__c> invObjList = [SELECT Id, Zuora__Zuora_Id__c, Zuora__BillingAccount__c FROM Zuora__ZInvoice__c
        WHERE Zuora__Zuora_Id__c IN:InvoiceIdMap.keySet()];

        for (Zuora__ZInvoice__c inv : invObjList) {
            invIdMap.put(inv.Zuora__BillingAccount__c, inv.Id);
        }
        return invIdMap;
    }

    private static Map<Id, Id> findContactId(List<Zuora__CustomerAccount__c> billingAccounts) {
        // the method return map of account id and contact id. It is to be used in the logic sending emails to contacts
        Map<Id, Id> contactMap = new Map<Id, Id>();

        // create a set of accountIDs
        Set<Id> accountIds = new Set<Id>();
        for (Zuora__CustomerAccount__c i : billingAccounts) {
            accountIds.add(i.Zuora__Account__c);
        }
        // query for contacts with the set of bill to contacts
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE AccountId IN:accountIds];

        // create the return map
        for (Contact c : contacts) {
            contactMap.put(c.AccountId, c.Id);
        }
        return contactMap;
    }
}