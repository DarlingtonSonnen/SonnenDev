/**
 * Created by m.muchow on 23.10.2018.
 */

global without sharing class LandingPageOrderAUDController {

    public String language {get; set;}

    public Boolean confirmed {get; set;}

    public Boolean dataReceived {get; set;}

    public Opportunity opp {get; set;}
    //if PV Installer TnC is necessary
        //public Account acc {get; set;}

    public pageOppWrapper oppWrapper {get; set;}
    //if PV Installer TnC is necessary
        //public pageAccWrapper accWrapper {get; set;}

    global List<Attachment> contentList {get; set;}
    public Map<Id, TermsAndConditions__c> tncsMap {get; set;}

    String urlId;
    String countryLab;
    //if PV Installer TnC is necessary
        //String site;
        //Id accId;
    Id contactId;

    global LandingPageOrderAUDController() {
        //set confirmed to false
        confirmed = false;
        //get Opp Id from page
        urlId = ApexPages.currentPage().getParameters().get('id');
        //get Account Id from Opp if PV Installer TnC is necessary
            //accId = [SELECT RecommendedPartner__c FROM Opportunity WHERE Id =: urlId].RecommendedPartner__c;
        //get Custom Metadata for TnCs
        AUOrderLandingPageSetting__mdt custMetaTnC = [SELECT TnC__c, ManufactureGuarantee__c FROM AUOrderLandingPageSetting__mdt WHERE Label = 'Tncs'];
        //get Contact Id from Opp
        contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id =: urlId].PrimaryContact__c;

        //query Data
        //query Opp Data
        this.opp = [SELECT Id, WebOrderType__c, ProductName__c, Amount, Financing__c, UpfrontPayment__c, BatteryCapacity__c, ShippingStreet__c, ShippingStreetNo__c, ShippingPostalCode__c, ShippingAdditional__c, ShippingCity__c, ShippingState__c, ShippingCountryIsoCode__c, TnCAndGuaranteeAccepted__c, Language__c FROM Opportunity WHERE Id =: urlId];
        //get language from opp
        language = opp.Language__c;
        //get Country Label
        Schema.DescribeFieldResult isoCodeField = User.CountryCode.getDescribe();
        List<Schema.PickListEntry> isoCodeEntry = isoCodeField.getPicklistValues();
        for (Schema.PickListEntry entry : isoCodeEntry) {
            if (entry.getValue() == opp.ShippingCountryIsoCode__c) {
                countryLab = entry.getLabel();
            }
        }

        //query Acc Data if PV Installer TnC is necessary
            //this.acc = [SELECT Id, Name, Website FROM Account WHERE Id =: accId];
        //strip Website if PV Installer TnC is necessary
            //site = acc.Website.removeStartIgnoreCase('http://');
            //site = site.removeStartIgnoreCase('https://');

        //query Terms and Conditions
        Map<Id, TermsAndConditions__c> tncMap = new Map<Id, TermsAndConditions__c>([SELECT Id, Type__c, Country__c, Language__c FROM TermsAndConditions__c WHERE (Type__c =: custMetaTnC.TnC__c OR Type__c =: custMetaTnC.ManufactureGuarantee__c) AND Current__c = TRUE AND Language__c =: language AND Country__c =: opp.ShippingCountryIsoCode__c]);
        this.tncsMap = tncMap;
        //get attachment of TnC Records
        List<Attachment> atList = [SELECT Id, Parent.Name, ParentId FROM Attachment WHERE ParentId IN : tncMap.keySet()];
        //Loop trough TnC to get parent type
        this.contentList = new List<Attachment>{null, null};
        for (Attachment at : atList) {
            String type = tncMap.get(at.ParentId).Type__c;
            String country = tncMap.get(at.ParentId).Country__c;
            String tncLanguage = tncMap.get(at.ParentId).Language__c;

            if (country == opp.ShippingCountryIsoCode__c && tncLanguage == language) {
                if (type == custMetaTnC.TnC__c) {
                    this.contentList.set(0, at);
                } else if (type == custMetaTnC.ManufactureGuarantee__c) {
                    this.contentList.set(1, at);
                }
            }
        }

        //set variable if data already send
        if(opp.TnCAndGuaranteeAccepted__c == true) {
            confirmed = true;
        }

        //set Wrapper for Opportunity
        this.oppWrapper = new pageOppWrapper();
        if (opp.WebOrderType__c == 'Battery') {
            this.oppWrapper.OderType = 'sonnenBatterie in house';
        } else if (opp.WebOrderType__c == 'Battery;PV Module') {
            this.oppWrapper.OderType = 'sonnenBatterie in house & solar system';
        }
        this.oppWrapper.ProductName = opp.ProductName__c;
        this.oppWrapper.Price = String.valueOf(opp.Amount);
        if (opp.Financing__c == 'PartFinancing') {
            this.oppWrapper.Financing = 'Part Financing';
        } else if (opp.Financing__c == 'FullFinancing') {
            this.oppWrapper.Financing = 'Full Financing';
        } else if (opp.Financing__c == 'Upfront') {
            this.oppWrapper.Financing = 'No Financing';
        }
        this.oppWrapper.Payment = String.valueOf(opp.UpfrontPayment__c);
        this.oppWrapper.Capacity = String.valueOf(opp.BatteryCapacity__c);
        this.oppWrapper.Street = opp.ShippingStreet__c;
        this.oppWrapper.StreetNo = opp.ShippingStreetNo__c;
        this.oppWrapper.PostalCode = opp.ShippingPostalCode__c;
        if (String.isBlank(opp.ShippingAdditional__c)) {
        this.oppWrapper.ShippingAdditional = null;
        } else {
        this.oppWrapper.ShippingAdditional = opp.ShippingAdditional__c;
        }
        this.oppWrapper.City = opp.ShippingCity__c;
        this.oppWrapper.State = opp.ShippingState__c;
        this.oppWrapper.CountryLabel = countryLab;

        //set Wrapper for Partner Account if PV Installer TnC is necessary
            //this.accWrapper = new pageAccWrapper();
            //this.accWrapper.PartnerName = acc.Name;
            //this.accWrapper.Website = site;
    }

    global void confirm() {
        try {
            createTnC();
            dataReceived();
            dataReceived = true;
        } catch (Exception e) {
            dataReceived = false;
        }

    }

    global void createTnC() {
        //create TnC Acceptance Records for Opportunity and Account/Contact
        List<TnCsAcceptance__c> acceptanceObj = [SELECT Accepted__c, DateAccepted__c, Contract__c, TermsAndConditions__c FROM TnCsAcceptance__c WHERE Opportunity__c =: opp.Id AND TermsAndConditions__r.Id IN :tncsMap.keySet()];
        List<TnCsAcceptance__c> acceptanceList = new List<TnCsAcceptance__c>();

        if (acceptanceObj.size() == 0) {
            for (Id i : tncsMap.keySet()) {
                TnCsAcceptance__c t1 = new TnCsAcceptance__c(Opportunity__c = opp.Id, Contact__c = contactId, TermsAndConditions__c = i, Accepted__c = false, DateAccepted__c = null);
                acceptanceList.add(t1);
            }
        } else if (acceptanceObj.size() == tncsMap.keySet().size()) {
            acceptanceList = acceptanceObj;
        } else {
            Map<Id, TnCsAcceptance__c> acceptanceMap = new Map<Id, TnCsAcceptance__c>();
            for (TnCsAcceptance__c tna : acceptanceObj) {
                acceptanceMap.put(tna.TermsAndConditions__c, tna);
            }
            for (TermsAndConditions__c tn : tncsMap.values()) {
                if (acceptanceMap.keySet().contains(tn.Id)) {
                    acceptanceList.add(acceptanceMap.get(tn.Id));
                } else {
                    TnCsAcceptance__c tn1 = new TnCsAcceptance__c(Opportunity__c = opp.Id, Contact__c = contactId, TermsAndConditions__c = tn.Id, Accepted__c = false, DateAccepted__c = null);
                    acceptanceList.add(tn1);
                }
            }
        }
        for (TnCsAcceptance__c tn : acceptanceList) {
            if (tn.Accepted__c != true) {
                tn.Accepted__c = true;
                tn.DateTimeAccepted__c = Datetime.now();
                tn.AppAccepted__c = 'AU Web Order Landing Page';
            }
        }
        upsert acceptanceList;
    }

    global void dataReceived() {
        Opportunity receivedOpp = [SELECT Id, TnCAndGuaranteeAccepted__c FROM Opportunity WHERE Id =: urlId LIMIT 1];
        receivedOpp.TnCAndGuaranteeAccepted__c = true;
        update receivedOpp;
    }

    public class pageOppWrapper {
        public String OderType {get; set;}
        public String ProductName {get; set;}
        public String Price {get; set;}
        public String Financing {get; set;}
        public String Payment {get; set;}
        public String Capacity {get; set;}
        public String Street {get; set;}
        public String StreetNo {get; set;}
        public String PostalCode {get; set;}
        public String ShippingAdditional {get; set;}
        public String City {get; set;}
        public String State {get; set;}
        public String CountryLabel {get; set;}
    }
    //if PV Installer TnC is necessary
        /*
        public class pageAccWrapper {
            public String PartnerName {get; set;}
            public String Website {get; set;}
        }
        */
}