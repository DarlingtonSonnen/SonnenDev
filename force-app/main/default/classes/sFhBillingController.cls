/**
 * Update M.Muchow 25.07.2018
 * - added try catch for landing page
 * - fixed authorized error if no direct marketing contract is present
 * -----------------------
 * Update M.Muchow 24.09.218
 * - update to use String for DatePV and work with jQuery Datepicker
 * -----------------------
 * Update M.Muchow 08.10.218
 * - update to use valueOf instead of parse to work with different user local settings
 * ------------------------
 * Update M.Muchow 12.11.2018
 * - set initial newDatePV value to fix null value if date is given and no changes are made by user
 */

global without sharing class sFhBillingController {

    public String language{get;set;}

    public Contract contr{get; set;}
    public Asset asset{get;set;}
    public Account acc{get;set;}

    public sFhAssetWrapper assetWrapper{get;set;}
    public sFhAccountWrapper accWrapper{get;set;}

    public Boolean confirmed {get; set;}
    public Boolean dtoCreated {get; set;}

    sFh_Billing_Setting__mdt custMeta;

    public List<SelectOption> getItems() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('',''));
        options.add(new SelectOption('Yes', System.Label.sFhBillingSelectOption1));
        options.add(new SelectOption('No', System.Label.sFhBillingSelectOption2));
        return options;
    }

    Id accId;
    Id assetId;
    String urlId;

    global sFhBillingController() {
        //set start confirmed boolean
        confirmed = false;

        language = System.currentPageReference().getParameters().get('language');

        //get Contract Id from URL
        urlId = ApexPages.currentPage().getParameters().get('id');

        //get Account Id & Asset Id
        assetId = [SELECT PVAsset__c FROM Contract WHERE Id =: urlId].PVAsset__c;
        accId = [SELECT AccountId FROM Contract WHERE Id =: urlId].AccountId;

        //query Accountf & Asset fields
        this.contr = [SELECT Id, UStQueryAnswerReceivedDate__c FROM Contract WHERE Id =: urlId LIMIT 1];
        this.asset = [SELECT Id, CommissioningDatePV__c, PVSizekWp__c FROM Asset WHERE Id =: assetId LIMIT 1];
        this.acc = [SELECT Id, SubjectToVat__c, VATId__c FROM Account WHERE Id =: accId LIMIT 1];

        //get Custom MetaData
        custMeta = [SELECT CaseOwnerIdDirectMarketing__c, Case_Record_Type_Id__c, Status__c, Type__c, CaseSubjectDirectMarketing__c, StatusDirectMarketing__c, CaseCategoryDM__c FROM sFh_Billing_Setting__mdt];

        //set wrapper for Contract information
        if((contr.UStQueryAnswerReceivedDate__c != null)){
            confirmed = true;
        }

        //set wrapper for Asset information
        this.assetWrapper = new sFhAssetWrapper();
        if(asset.CommissioningDatePV__c != null) {
            this.assetWrapper.datePV = asset.CommissioningDatePV__c.format();
        } else{
            this.assetWrapper.datePV = null;
        }
        this.assetWrapper.newDatePV = String.valueOf(asset.CommissioningDatePV__c);
        this.assetWrapper.pvSize = asset.PVSizekWp__c;

        //set Wrapper for Account information
        this.accWrapper = new sFhAccountWrapper();
        this.accWrapper.vatId = acc.VATId__c;
        this.accWrapper.subjectToVat = acc.SubjectToVat__c;
    }

    //create Data Transfer Object
    global void confirm() {
        //check if prior Values are changed and call case creation function


        DataTransferObject__c dto = new DataTransferObject__c();
        dto.RelatedProcess__c = 'sFh Billing';
        dto.CommissioningDatePV__c = Date.valueOf(assetWrapper.newDatePV);
        dto.PVSizekWp__c = assetWrapper.pvSize;
        dto.SubjectToVat__c = accWrapper.subjectToVat;
        dto.AccountId__c = accId;
        dto.AssetId__c = assetId;
        dto.ContractId__c = urlId;
        if(accWrapper.subjectToVat == 'No') {
            dto.VATId__c = null;
        } else {
            dto.VATId__c = accWrapper.vatId;
        }
        try {
            insert dto;
            dtoCreated = true;
            if(((asset.PVSizekWp__c != assetWrapper.pvSize) && (asset.PVSizekWp__c != null)) ||
                    ((asset.CommissioningDatePV__c != Date.valueOf(assetWrapper.newDatePV)) && (asset.CommissioningDatePV__c != null)) ||
                    ((acc.SubjectToVat__c != accWrapper.subjectToVat) && (acc.SubjectToVat__c != null)) ||
                    ((acc.VATId__c != accWrapper.vatId) && (acc.VATId__c != null))) {
                createCase();
            }
        } catch (Exception e) {
            dtoCreated = false;
        }
    }

    //Case creation function
    global void createCase() {
        Date feedDate;
        //get Start of Feed-In Date from DV-Contract
        try {
            feedDate = [SELECT Id, StartOfCommunityFeedIn__c FROM Contract WHERE ContractNumberSonnenFlatDM__c =: urlId LIMIT 1].StartOfCommunityFeedIn__c;
        } catch (Exception e) {
            feedDate = null;
        }

        //set description text
        String desTitel = 'The following values differ from the previous ones and have been changed by the customer:\n';
        String desPVSize = '';
        String desComDate = '';
        String desVat = '';
        String desVatId ='';
        if((asset.PVSizekWp__c != null) && (asset.PVSizekWp__c != assetWrapper.pvSize)) {
            desPVSize = '\n Old PV-Size: '+asset.PVSizekWp__c+ '\n New PV-Size: '+assetWrapper.pvSize+'\n';
        }
        if((asset.CommissioningDatePV__c != null) && (asset.CommissioningDatePV__c.format() != assetWrapper.datePV)) {
            desComDate = '\n Old Commissioning Date: '+asset.CommissioningDatePV__c.format()+ '\n New Commissioning Date: '+assetWrapper.datePV+'\n';
        }
        if((acc.SubjectToVat__c != null) && (acc.SubjectToVat__c != accWrapper.subjectToVat)) {
            desVat = '\n Old Subject To Vat: '+acc.SubjectToVat__c+ '\n New Subject To Vat: '+accWrapper.subjectToVat+'\n';
        }
        if((acc.VATId__c != null) && (acc.VATId__c != accWrapper.vatId)) {
            desVatId = '\n Old Vat Id: '+acc.VATId__c+ '\n New Vat Id: '+accWrapper.vatId+'\n';
        }

        //create new Case
        if(feedDate != null) {
            Case newCase = new Case();
            newCase.RecordTypeId = custMeta.Case_Record_Type_Id__c;
            newCase.Type = custMeta.Type__c;
            newCase.Subject = custMeta.CaseSubjectDirectMarketing__c;
            newCase.OwnerId = custMeta.CaseOwnerIdDirectMarketing__c;
            newCase.Status = custMeta.StatusDirectMarketing__c;
            newCase.Category__c = custMeta.CaseCategoryDM__c;
            newCase.AccountId = accId;
            newCase.Contract__c = urlId;
            newCase.Description = desTitel;
            newCase.Description += desPVSize;
            newCase.Description += desComDate;
            newCase.Description += desVat;
            newCase.Description += desVatId;

            insert newCase;
        }
    }

    public class sFhAssetWrapper{
        public String datePV {get;set;}
        public String newDatePV {get;set;}
        public Decimal pvSize {get;set;}
    }
    public class sFhAccountWrapper{
        public String subjectToVat {get; set;}
        public String vatId {get; set;}
        public List<SelectOption> Items;
    }
}