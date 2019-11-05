/**
 * Created by m.muchow on 01.08.2018.
 */

global without sharing class eServicesMonitoringController {

    public String language{get; set;}
    public String pageType{get; set;}

    public MonitoringeServices__c monitoringeServices {get; set;}
    public Asset pvAsset {get; set;}

    public eServicesMonWrapper monWrapper {get; set;}
    public pvAssetWrapper assetWrapper {get; set;}

    public Boolean confirmed {get; set;}

    public Boolean dtoCreated {get; set;}

    String urlId;
    Id pvAssetId;

    global eServicesMonitoringController() {
        // start confirmed boolean
        confirmed = false;

        language = System.currentPageReference().getParameters().get('language');
        pageType = System.currentPageReference().getParameters().get('pageType');

        //get Monitoring Id from URL
        urlId = ApexPages.currentPage().getParameters().get('id');

        //get PV-Asset Id
        pvAssetId = [SELECT PVAsset__c FROM MonitoringeServices__c WHERE Id =: urlId LIMIT 1].PVAsset__c;

        //get eServices Monitoring & PV-Asset Record based on Contract Id & Asset Id
        this.monitoringeServices = [SELECT Id, BatteryID__c, EarliestBatteryCheckDate__c, LandingPageAnswer__c, MicroservicePaused__c FROM MonitoringeServices__c WHERE Id =: urlId LIMIT 1];
        system.debug(monitoringeServices.BatteryID__c);
        if (!String.isBlank(pvAssetId) || pvAssetId != null) {
            this.pvAsset = [SELECT Id, CommissioningDatePV__c FROM Asset WHERE Id = :pvAssetId LIMIT 1];
        }

        //check if data is already transmitted and set boolean for div
        if(monitoringeServices.LandingPageAnswer__c == true) {
            confirmed = true;
        }

        //set Wrapper for eServices Monitoring information
        if (pageType == 'sb') {
            this.monWrapper = new eServicesMonWrapper();
            if(monitoringeServices.BatteryID__c == null) {
                this.monWrapper.batteryId = null;
            } else {
                this.monWrapper.batteryId = monitoringeServices.BatteryID__c;
            }
        }

        //set Wrapper for PV-Asset information
        if (pageType == 'pv') {
            this.assetWrapper = new pvAssetWrapper();
            if (pvAsset.CommissioningDatePV__c != null) {
                this.assetWrapper.pvComDate = pvAsset.CommissioningDatePV__c.format();
            } else {
                this.assetWrapper.pvComDate = null;
            }
            this.assetWrapper.newPvComDate = String.valueOf(pvAsset.CommissioningDatePV__c);
        }
    }

    //create Data Transfer Object SB-Landing Page
    global void confirm_sb() {
        DataTransferObject__c dto = new DataTransferObject__c();
        dto.RelatedProcess__c = 'eServicesMonitoring SB';
        if(monWrapper.batteryId == '0') {
            dto.AssetSerialNumber__c = null;
        } else {
            dto.AssetSerialNumber__c = monWrapper.batteryId;
        }
        if(monWrapper.newCheckDate != '') {
            dto.eServicesMonitoringBatteryCheckDate__c = Date.valueOf(monWrapper.newCheckDate) + 1;
        } else {
            dto.eServicesMonitoringBatteryCheckDate__c = monitoringeServices.EarliestBatteryCheckDate__c;
        }

        dto.eServicesMonitoringId__c = monitoringeServices.Id;
        try {
            insert dto;
            uncheckMicroservice();
            checkAnswer();
            sbValidated();
            dtoCreated = true;
        } catch (Exception e) {
            dtoCreated = false;
        }
    }

    //create Data Transfer Object PV-Landing Page
    global void confirm_pv() {
        DataTransferObject__c dto = new DataTransferObject__c();
        dto.RelatedProcess__c = 'eServicesMonitoring PV';
        dto.CommissioningDatePV__c = Date.valueOf(assetWrapper.newPvComDate);
        dto.AssetId__c = pvAssetId;
        dto.eServicesMonitoringId__c = monitoringeServices.Id;
        try {
            insert dto;
            uncheckMicroservice();
            checkAnswer();
            pvValidated();
            dtoCreated = true;
        } catch (Exception e) {
            dtoCreated = false;
        }
    }

    global void uncheckMicroservice() {
        MonitoringeServices__c uncheckMonitoring = [SELECT Id, MicroservicePaused__c FROM MonitoringeServices__c WHERE Id =: urlId];
            uncheckMonitoring.MicroservicePaused__c = false;
        update uncheckMonitoring;
    }

    global void checkAnswer() {
        MonitoringeServices__c answerMonitoring = [SELECT Id, LandingPageAnswer__c FROM MonitoringeServices__c WHERE Id =: urlId];
            answerMonitoring.LandingPageAnswer__c = true;
        update answerMonitoring;
    }

    global void sbValidated() {
        MonitoringeServices__c sbVali = [SELECT Id, BatteryIDValidated__c FROM MonitoringeServices__c WHERE Id =: urlId];
            sbVali.BatteryIDValidated__c = 'not validated';
        update sbVali;
    }

    global void pvValidated() {
        MonitoringeServices__c pvVali = [SELECT Id, PVCheck__c FROM MonitoringeServices__c WHERE Id =: urlId];
        pvVali.PVCheck__c = 'not validated';
        update pvVali;
    }

    public class eServicesMonWrapper{
        public String batteryId {get; set;}
        public String newCheckDate {get; set;}
    }

    public class pvAssetWrapper{
        public String pvComDate {get; set;}
        public String newPvComDate {get; set;}
    }
}