/*

    Version 3.0 - 2018-10-22 by Bartosz
    - added fix to avoid creation of TnC Acceptance for General TnC - the document is not to be on the landing page any more

    Version 2.0 - 2018-09-14 by Bartosz
    - added Language and Country parameters when querying TnCs
    - changed storing documents acceptance from TnCsAsset to TnCsAcceptance
 */

global without sharing class AssetTnCController5 {

//    global String username{get;set;}
//    global String password{get;set;}
    public String startURL {get;set;}
    public String language {get;set;}

    global List<Attachment> contentList {get;set;}
    public List<TermsAndConditions__c> tncList {get;set;}
    public Map<Id, TermsAndConditions__c> tncsMap {get; set;}

    public Asset asset{get; set;}
    public AssetWrapper assetWrapper{get; set;}
    public boolean accepted1 {get; set;}
    public boolean accepted2 {get; set;}
    public boolean accepted3 {get; set;}
    public boolean accepted4 {get; set;}
    public boolean accepted5 {get; set;}
    public boolean accepted6 {get; set;}

    public boolean confirmed {get; set;}

    public Boolean dtoCreated {get; set;}

    global AssetTnCController5 () {
        startURL = System.currentPageReference().getParameters().get('startURL');
        language = System.currentPageReference().getParameters().get('language');
        confirmed = false;

        // extract asset Id from the URL
        String urlId = ApexPages.currentPage().getParameters().get('id');

        // query asset fields
        this.asset = [SELECT Id, SerialNumber, INClientFirstName__c, INClientLastName__c, INClientPhoneNumber__c, INClientStreet__c,
                INClientAdditionToAddress__c, INClientZIPCode__c, INClientSalutation__c, INClientCity__c, INClientDataConfirmed__c, Country__c
        FROM Asset WHERE Id = :urlId LIMIT 1 ];

        // query custom metadata settings to find names of the documents to show
        CommissioningAssistant__mdt cma = [SELECT TnC1__c, TnC2__c, TnC3__c FROM CommissioningAssistant__mdt WHERE Label = 'Settings' AND Language__c = :language];
        System.debug('cma '+ cma);

        // query terms and conditions, assign them to content list
        // this map to be implemented when terms and conditions will be based on countries
        Map<Id, TermsAndConditions__c> tncsMap = new Map<Id, TermsAndConditions__c>([SELECT Id, Type__c, Country__c, Language__c FROM TermsAndConditions__c
        WHERE (Type__c = :cma.TnC1__c OR Type__c = :cma.TnC2__c OR Type__c = :cma.TnC3__c)
        AND Current__c = true AND Country__c =:asset.Country__c AND Language__c = :language]);
        System.debug(cma.TnC1__c + ' ' + cma.TnC2__c  + ' ' + cma.TnC3__c);
        System.debug(tncsMap);
        this.tncList = tncsMap.values();
        this.tncsMap = tncsMap;

        //this.contentList = [SELECT Id, Parent.Name, ParentId From Attachment WHERE ParentId IN :tncsMap.keySet()];
        List<Attachment> atList = [SELECT Id, Parent.Name, ParentId From Attachment WHERE ParentId IN :tncsMap.keySet()];
        System.debug(atList);

        // loop through terms and conditions to get the parent type
        // on the landing page the element[0] of this.contentList corresponds to warranty conditions, element[1] - General TnC, element[2] - privacy policy

        this.contentList = new List<Attachment>{null, null, null};
        for (Attachment at : atList) {

            System.debug(at.ParentId);
            System.debug(at.Id);
            System.debug(tncsMap.get(at.ParentId));
            System.debug(tncsMap);

            String type = tncsMap.get(at.ParentId).Type__c;
            String country = tncsMap.get(at.ParentId).Country__c; // terms and conditions country
            String termsLanguage = tncsMap.get(at.ParentId).Language__c;

            if (country == this.asset.Country__c && termsLanguage == language) {

                // assigning particular index in the list to the particular TnC document - this is determined by the VF site and the order the documents are presented on the site
                if (type == cma.TnC1__c) {
                    this.contentList.set(0, at);
                } else if (type == cma.TnC2__c) {
                    this.contentList.set(2, at);
                } else if (type == cma.TnC3__c) {
                    this.contentList.set(1, at);
                }
            }
        }

        // query terms and conditions together with attachments
        //List<TermsAndConditions__c> tncList2 = [SELECT Id, Type__c, (SELECT Id FROM Attachments) FROM TermsAndConditions__c WHERE (Type__c = :cma.TnC1__c OR Type__c = :cma.TnC2__c OR Type__c = :cma.TnC3__c) AND Current__c = true ORDER BY Type__c]];



        this.confirmed = asset.INClientDataCOnfirmed__c;

        // assign assetWrapper data to an asset
        this.assetWrapper = new AssetWrapper();
        this.assetWrapper.firstName = asset.INClientFirstName__c;
        this.assetWrapper.lastName = asset.INClientLastName__c;
        this.assetWrapper.phone = asset.INClientPhoneNumber__c;
        this.assetWrapper.salutation = asset.INClientSalutation__c;
        this.assetWrapper.street = asset.INClientStreet__c;
        this.assetWrapper.streetNumber = asset.INClientAdditionToAddress__c;
        this.assetWrapper.postCode = asset.INClientZIPCode__c;
        this.assetWrapper.city = asset.INClientCity__c;
    }


    public List<selectOption> getItems() {
        List<selectOption> options = new List<selectOption>();
        options.add(new selectOption('Mr.', System.Label.CommAssist_SalutationMr));
        options.add(new selectOption('Ms.', System.Label.CommAssist_SalutationMs));
        return options;
    }

    global void confirm() {

        DataTransferObject__c dto = new DataTransferObject__c();
        dto.RelatedProcess__c = 'Commissioning Assistant';
        dto.AssetId__c = asset.Id;
        dto.AssetSerialNumber__c = asset.SerialNumber;
        dto.Phone__c = assetWrapper.phone;
        dto.LastName__c = assetWrapper.lastName;
        dto.FirstName__c = assetWrapper.firstName;
        dto.PostCode__c = assetWrapper.postCode;
        dto.City__c = assetWrapper.city;
        dto.Street__c = assetWrapper.street;
        dto.StreetNumber__c = assetWrapper.streetNumber;
        dto.Language__c = language;
        dto.Salutation__c = assetWrapper.salutation;


        System.debug(dto);
        try {
            insert dto;
            dtoCreated = true;
        } catch (Exception e) {
            dtoCreated = false;
        }


        System.debug(asset.Id);
        System.debug(tncsMap);

        // *** fix to avoid creation of TnC Acceptance for General TnC
        for (Id i : tncsMap.keySet()) {
            if (tncsMap.get(i).Type__c == 'General TnC') {
                tncsMap.remove(i);
            }
        }

        // ****
        // switch to the TnC Acceptance
        List<TnCsAcceptance__c> acceptanceObj = [SELECT Accepted__c, DateAccepted__c, Asset__c, TermsAndConditions__c FROM TnCsAcceptance__c WHERE Asset__c =:asset.Id AND TermsAndConditions__r.Id IN :tncsMap.keySet()];
        List<TnCsAcceptance__c> acceptanceList = new List<TnCsAcceptance__c>();

        System.debug(acceptanceObj.size());
        if (acceptanceObj.size() == 0) {
            for (Id i : tncsMap.keySet()) {
                TnCsAcceptance__c t1 = new TnCsAcceptance__c(Asset__c = asset.Id, TermsAndConditions__c = i, Accepted__c = false, DateAccepted__c = null);
                acceptanceList.add(t1);
            }
        } else if (acceptanceObj.size() == tncsMap.keySet().size()) {
            acceptanceList = acceptanceObj;
        } else {
            Map<Id, TnCsAcceptance__c> acceptanceMap = new Map<Id, TnCsAcceptance__c>(); // terms and conditions Id as key, tncAsset__c as object
            for (TnCsAcceptance__c tna : acceptanceObj) {
                acceptanceMap.put(tna.TermsAndConditions__c, tna);
            }
            for (TermsAndConditions__c tn : tncsMap.values()) {
                if (acceptanceMap.keySet().contains(tn.Id)) {
                    acceptanceList.add(acceptanceMap.get(tn.Id));
                } else {
                    TnCsAcceptance__c tn1 = new TnCsAcceptance__c(Asset__c = asset.Id, TermsAndConditions__c = tn.Id, Accepted__c = false, DateAccepted__c = null);
                    acceptanceList.add(tn1);
                }
            }
        }
        System.debug(acceptanceList);
        for (TnCsAcceptance__c tn : acceptanceList) {
            if (tn.Accepted__c != true) {
                tn.Accepted__c = true;
                tn.DateTimeAccepted__c = DateTime.now();
                tn.AppAccepted__c = 'Commissioning Assistant landing page';
            }
        }
        upsert acceptanceList;
    }

    public class AssetWrapper {
        public String salutation {get; set;}
        public String firstName {get; set;}
        public String lastName {get; set;}
        public String phone {get; set;}
        public String street {get; set;}
        public String streetNumber {get; set;}
        public String postCode {get; set;}
        public String city {get; set;}
    }
}