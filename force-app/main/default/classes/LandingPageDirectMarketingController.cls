/**
 * Created by m.muchow on 25.09.2018.
 * ----------------------------------
 * Update 09.11.2018
 * - removed comment out code
 * - removed any reference for DataReceivedDM__c, field won't be used anymore
 * - changed already answered logic to DataReceivedCustomer__c use instead of DataReceivedDM__c
 * Update 12.03.2019
 * - removed reference of multiple fields from DM Contract regarding ContractingParty & ShippingAddress
 * - added new query to get ContractingParty & ShippingAddress informations direct from sonnenFlat contract
 * Update 15.10.2019
 * - added new fields to support the new Global Service App
 */

global without sharing class LandingPageDirectMarketingController {

    public String language{get;set;}

    public Contract contrDM{get; set;}
    public Contract contrSF{get; set;}
    public Asset assetPV{get; set;}
    public Account acc{get; set;}

    public DMContractDMWrapper contrDMWrapper{get; set;}
    public DMAssetPVWrapper assetPVWrapper{get; set;}
    public DMAccountWrapper accWrapper{get; set;}

    global List<Attachment> contentList{get; set;}
    public Map<Id, TermsAndConditions__c> tncsMap {get; set;}

    public Boolean confirmed {get; set;}

    public Boolean dtoCreated {get; set;}

    public List<SelectOption> getItems() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('',''));
        options.add(new SelectOption('Yes', System.Label.sFhBillingSelectOption1));
        options.add(new SelectOption('No', System.Label.sFhBillingSelectOption2));
        return options;
    }

    Id accId;
    Id assetPVId;
    Id contrSFId;
    String urlId;

    global LandingPageDirectMarketingController() {
        confirmed = false;

        language = System.currentPageReference().getParameters().get('language');

        //get DM Contract Id from URL
        urlId = ApexPages.currentPage().getParameters().get('id');

        //get SF Contract Id, Account Id, PV Asset Id
        contrSFId = [SELECT ContractNumberSonnenFlatDM__c FROM Contract WHERE Id =: urlId].ContractNumberSonnenFlatDM__c;
        accId = [SELECT AccountId FROM Contract WHERE Id =: urlId].AccountId;
        assetPVId = [SELECT PVAsset__c FROM Contract WHERE Id =: contrSFId].PVAsset__c;

        //get custom Metadata
        //Custom Metadata to create case
        DirectMarketingSetting__mdt custMetaTnC = [SELECT PrivacyPolicyeServices__c, PrivacyPolicySolandeo__c, TnCDirectMarketing__c, TnCSolandeo__c FROM DirectMarketingSetting__mdt WHERE Label = 'TnCs'];
        //query data
        this.contrSF = [SELECT Id, ContractingPartnerFirstname__c, ContractingPartnerLastname__c, ShippingStreet__c, ShippingStreetNumber__c, ShippingPostalCode__c, ShippingCity__c, BillingCountry__c FROM Contract WHERE Id =: contrSFId];
        this.contrDM = [SELECT Id,DataReceivedCustomer__c, sonnenBonusDM__c, ContractNumberSonnenFlatDM__r.CustomerSignedId FROM Contract WHERE Id =: urlId];
        this.assetPV = [SELECT Id, PVSizekWp__c, CommissioningDatePV__c, FeedInTarif10kWp__c, FeedInTarif10kWp40kWp__c FROM Asset WHERE Id =: assetPVId];
        this.acc = [SELECT Id, SubjectToVat__c, VATId__c FROM Account WHERE Id =: accId];

        //query Terms And Conditions
        Map<Id, TermsAndConditions__c> tncMap = new Map<Id, TermsAndConditions__c>([SELECT Id, Type__c, Country__c, Language__c FROM TermsAndConditions__c WHERE (Type__c =: custMetaTnC.PrivacyPolicySolandeo__c OR Type__c =: custMetaTnC.PrivacyPolicyeServices__c OR Type__c =: custMetaTnC.TnCSolandeo__c OR Type__c =: custMetaTnC.TnCDirectMarketing__c) AND Current__c = TRUE AND Language__c =: language AND Country__c =: contrSF.BillingCountry__c]);
        this.tncsMap = tncMap;
        //get attachment of TnC Records
        List<Attachment> atList = [SELECT Id, Parent.Name, ParentId FROM Attachment WHERE ParentId IN : tncMap.keySet()];

        //Loop trough TnC to get parent type
        this.contentList = new List<Attachment>{null, null, null, null};
        for (Attachment at : atList) {
            String type = tncMap.get(at.ParentId).Type__c;
            String country = tncMap.get(at.ParentId).Country__c;
            String tncLanguage = tncMap.get(at.ParentId).Language__c;

            if (country == contrSF.BillingCountry__c && tncLanguage == language) {
                if (type == custMetaTnC.TnCDirectMarketing__c) {
                    this.contentList.set(0, at);
                } else if (type == custMetaTnC.PrivacyPolicyeServices__c) {
                    this.contentList.set(1, at);
                } else if (type == custMetaTnC.TnCSolandeo__c) {
                    this.contentList.set(2, at);
                } else if (type == custMetaTnC.PrivacyPolicySolandeo__c) {
                    this.contentList.set(3, at);
                }
            }
        }

        //set variable if data already send
        if(contrDM.DataReceivedCustomer__c != null) {
            confirmed = true;
        }

        //set Wrapper for DM Contract
        this.contrDMWrapper = new DMContractDMWrapper();
        this.contrDMWrapper.sonnenBonus = contrDM.sonnenBonusDM__c;
        this.contrDMWrapper.FirstName = contrSF.ContractingPartnerFirstname__c;
        this.contrDMWrapper.LastName = contrSF.ContractingPartnerLastname__c;
        this.contrDMWrapper.Street = contrSF.ShippingStreet__c;
        this.contrDMWrapper.StreetNumber = contrSF.ShippingStreetNumber__c;
        this.contrDMWrapper.PostalCode = contrSF.ShippingPostalCode__c;
        this.contrDMWrapper.City = contrSF.ShippingCity__c;

        //set Wrapper for PV-Asset
        this.assetPVWrapper = new DMAssetPVWrapper();
        this.assetPVWrapper.sizePV = assetPV.PVSizekWp__c;
        if(assetPV.CommissioningDatePV__c != null) {
            this.assetPVWrapper.datePV = assetPV.CommissioningDatePV__c.format();
        } else {
            this.assetPVWrapper.datePV = null;
        }
        this.assetPVWrapper.newDatePV = String.valueOf(assetPV.CommissioningDatePV__c);
        this.assetPVWrapper.FeedInTariff10kWp = assetPV.FeedInTarif10kWp__c;
        this.assetPVWrapper.FeedInTariff40kWp = assetPV.FeedInTarif10kWp40kWp__c;

        //set Wrapper for Account
        this.accWrapper = new DMAccountWrapper();
        this.accWrapper.subjectToVat = acc.SubjectToVat__c;
        this.accWrapper.vatId = acc.VATId__c;
    }

    //create Data Transfer Object
    global void confirm() {

        DataTransferObject__c dto = new DataTransferObject__c();
        dto.RelatedProcess__c = 'Direct Marketing';
        dto.AccountId__c = accId;
        dto.AssetId__c = assetPVId;
        dto.ContractId__c = contrSFId;
        dto.PVSizekWp__c = assetPVWrapper.sizePV;
        dto.CommissioningDatePV__c = Date.valueOf(assetPVWrapper.newDatePV);
        dto.FeedIn10kWp__c = assetPVWrapper.FeedInTariff10kWp;
        if (assetPVWrapper.sizePV >= 10) {
            dto.FeedIn40kWp__c = assetPVWrapper.FeedInTariff40kWp;
        } else {
            dto.FeedIn40kWp__c = null;
        }
        dto.SubjectToVat__c = accWrapper.subjectToVat;
        if (accWrapper.subjectToVat == 'No') {
            dto.VATId__c = null;
        } else {
            dto.VATId__c = accWrapper.vatId;
        }

        try {
            insert dto;
            createTnC();
            createCases();
            dataReceived();
            dtoCreated = true;
        } catch (Exception e) {
            dtoCreated = false;
        }
    }

    //create case if accepted by customer and create case if data was changed
    global void createCases() {
        eServicesMonitoringSettings__mdt custMetaCaseDataChanged = [SELECT CaseOwnerId__c, CaseRecordTypeId__c, CaseCategory__c, CaseStatus__c, CaseSubject__c, CaseType__c, CaseSubcategory__c, CaseOrigin__c, CaseCountry__c FROM eServicesMonitoringSettings__mdt WHERE DeveloperName = 'CaseDataChanged'];
        Date feedDate;

        try {
            feedDate = [SELECT Id, StartOfCommunityFeedIn__c FROM Contract WHERE Id =: contrDM.Id LIMIT 1].StartOfCommunityFeedIn__c;
        } catch (Exception e) {
            feedDate = null;
        }
        if (feedDate != null) {
            if (((assetPV.PVSizekWp__c != assetPVWrapper.sizePV) && (assetPV.PVSizekWp__c != null) ||
                    ((assetPV.CommissioningDatePV__c != Date.valueOf(assetPVWrapper.newDatePV)) && assetPV.CommissioningDatePV__c != null) ||
                    ((assetPV.FeedInTarif10kWp__c != assetPVWrapper.FeedInTariff10kWp) && assetPV.FeedInTarif10kWp__c != null) ||
                    ((assetPV.FeedInTarif10kWp40kWp__c != assetPVWrapper.FeedInTariff40kWp) && assetPV.FeedInTarif10kWp40kWp__c != null) ||
                    ((acc.SubjectToVat__c != accWrapper.subjectToVat) && acc.SubjectToVat__c != null) ||
                    ((acc.VATId__c != accWrapper.vatId) && acc.VATId__c != null))) {

                //set Description text
                String desTitel = 'The following values differ from the previous ones and have been changed by the customer:\n';
                String desPVSize = '', desComDate = '', desFeed10 = '', desFeed40 = '', desVat = '', desVatId = '';
                if((assetPV.PVSizekWp__c != null) && (assetPV.PVSizekWp__c != assetPVWrapper.sizePV)) {
                    desPVSize = '\n Old PV-Size: '+assetPV.PVSizekWp__c+ '\n New PV-Size: '+assetPVWrapper.sizePV+'\n';
                }
                if((assetPV.CommissioningDatePV__c != null) && (assetPV.CommissioningDatePV__c != Date.valueOf(assetPVWrapper.newDatePV))) {
                    desComDate = '\n Old Commissioning Date: '+assetPV.CommissioningDatePV__c.format()+ '\n New Commissioning Date: '+Date.valueOf(assetPVWrapper.newDatePV).format()+'\n';
                }
                if((assetPV.FeedInTarif10kWp__c != null) && (assetPV.FeedInTarif10kWp__c != assetPVWrapper.FeedInTariff10kWp)) {
                    desFeed10 = '\n Old Feed-In Tariff 10 kWp: '+assetPV.FeedInTarif10kWp__c+ '\n New Feed-In Tariff 10 kWp: '+assetPVWrapper.FeedInTariff10kWp+'\n';
                }
                if((assetPV.FeedInTarif10kWp40kWp__c != null) && (assetPV.FeedInTarif10kWp40kWp__c != assetPVWrapper.FeedInTariff40kWp)) {
                    desFeed40 = '\n Old Feed-In Tariff 10-40 kWp: '+assetPV.FeedInTarif10kWp40kWp__c+ '\n New Feed-In Tariff 10-40 kWp: '+assetPVWrapper.FeedInTariff40kWp+'\n';
                }
                if((acc.SubjectToVat__c != null) && (acc.SubjectToVat__c != accWrapper.subjectToVat)) {
                    desVat = '\n Old Subject To Vat: '+acc.SubjectToVat__c+ '\n New Subject To Vat: '+accWrapper.subjectToVat+'\n';
                }
                if((acc.VATId__c != null) && (acc.VATId__c != accWrapper.vatId)) {
                    desVatId = '\n Old Vat Id: '+acc.VATId__c+ '\n New Vat Id: '+accWrapper.vatId+'\n';
                }

                Case newCase = new Case();
                newCase.RecordTypeId = custMetaCaseDataChanged.CaseRecordTypeId__c;
                newCase.Type = custMetaCaseDataChanged.CaseType__c;
                newCase.Subject = custMetaCaseDataChanged.CaseSubject__c;
                newCase.OwnerId = custMetaCaseDataChanged.CaseOwnerId__c;
                newCase.Status = custMetaCaseDataChanged.CaseStatus__c;
                newCase.Category__c = custMetaCaseDataChanged.CaseCategory__c;
                newCase.Subcategory__c =custMetaCaseDataChanged.CaseSubcategory__c;
                newCase.Origin = custMetaCaseDataChanged.CaseOrigin__c;
                newCase.Country__c = custMetaCaseDataChanged.CaseCountry__c;
                newCase.AccountId = accId;
                newCase.Contract__c = contrDM.Id;
                newCase.Description = desTitel;
                newCase.Description += desPVSize;
                newCase.Description += desComDate;
                newCase.Description += desFeed10;
                newCase.Description += desFeed40;
                newCase.Description += desVat;
                newCase.Description += desVatId;

                insert newCase;
            }
        }
    }

    //create TnC Acceptance records for Direct Marketing Contract
    global void createTnC() {
        List<TnCsAcceptance__c> acceptanceObj = [SELECT Accepted__c, DateAccepted__c, Contract__c, TermsAndConditions__c FROM TnCsAcceptance__c WHERE Contract__c =: contrDM.Id AND TermsAndConditions__r.Id IN :tncsMap.keySet()];
        List<TnCsAcceptance__c> acceptanceList = new List<TnCsAcceptance__c>();

        if (acceptanceObj.size() == 0) {
            for (Id i : tncsMap.keySet()) {
                TnCsAcceptance__c t1 = new TnCsAcceptance__c(Contract__c = contrDM.Id, Contact__c = contrDM.ContractNumberSonnenFlatDM__r.CustomerSignedId, TermsAndConditions__c = i, Accepted__c = false, DateAccepted__c = null);
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
                    TnCsAcceptance__c tn1 = new TnCsAcceptance__c(Contract__c = contrDM.Id, Contact__c = contrDM.ContractNumberSonnenFlatDM__r.CustomerSignedId, TermsAndConditions__c = tn.Id, Accepted__c = false, DateAccepted__c = null);
                    acceptanceList.add(tn1);
                }
            }
        }
        for (TnCsAcceptance__c tn : acceptanceList) {
            if (tn.Accepted__c != true) {
                tn.Accepted__c = true;
                tn.DateTimeAccepted__c = Datetime.now();
                tn.AppAccepted__c = 'Direct Marketing Landing Page';
            }
        }
        upsert acceptanceList;
    }

    global void dataReceived() {
        Contract receivedContract = [SELECT Id, DataReceivedCustomer__c FROM Contract WHERE Id =: contrDM.Id LIMIT 1];
            receivedContract.DataReceivedCustomer__c = Date.today();
        update receivedContract;
    }

    public class DMContractDMWrapper{
        public Decimal sonnenBonus {get; set;}
        public String FirstName {get; set;}
        public String LastName {get; set;}
        public String Street {get; set;}
        public String StreetNumber {get; set;}
        public String PostalCode {get; set;}
        public String City {get; set;}
    }

    public class DMAssetPVWrapper{
        public Decimal sizePV {get; set;}
        public String datePV {get; set;}
        public String newDatePV {get; set;}
        public Decimal FeedInTariff10kWp {get; set;}
        public Decimal FeedInTariff40kWp {get; set;}
    }

    public class DMAccountWrapper{
        public String subjectToVat {get; set;}
        public String vatId {get; set;}
    }
}