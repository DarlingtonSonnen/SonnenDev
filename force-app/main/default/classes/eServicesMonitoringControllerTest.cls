/**
 * Created by m.muchow on 07.08.2018.
 */
@IsTest
public with sharing class eServicesMonitoringControllerTest {
    @TestSetup
    static void testSetup() {

        Id personAccId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
        Account personAcc = new Account(FirstName = 'Person', LastName='Account', RecordTypeId = personAccId);
        insert personAcc;

        Id assetId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('PVPlant').getRecordTypeId();
        Asset pvAsset = new Asset(Name = 'PV-Asset', RecordTypeId = assetId, AccountId = personAcc.Id, PVSizekWp__c = 10);
        insert pvAsset;

        Id contractId = Schema.SObjectType.Contract.getRecordTypeInfosByDeveloperName().get('SonnenFlat').getRecordTypeId();
        Contract flatContract = new Contract(RecordTypeId = contractId,	Type__c = 'sonnenBatterieHome-DE', Status = 'Draft', AccountId = personAcc.Id, PVAsset__c = pvAsset.Id, StartDate = Date.today().addDays(1), TariffType__c = 'sonnenFlat', Tariff_Version__c = 'sFh 3.0');
        insert flatContract;

        MonitoringeServices__c miRecord = new MonitoringeServices__c(Contract__c = flatContract.Id, PVAsset__c = pvAsset.Id);
        insert miRecord;
    }

    //test for battery validation landing page
    @IsTest
    static void eServicesMonitoringControllerSB() {
        Id monitoringId = [SELECT Id FROM MonitoringeServices__c].Id;
        PageReference pageRef = Page.LandingPageMonitoring;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', monitoringId);
        ApexPages.currentPage().getParameters().put('pageType', 'sb');
        eServicesMonitoringController controller = new eServicesMonitoringController();
        controller.monWrapper.batteryId = '12345';
        controller.monWrapper.newCheckDate = '2018-01-01';
        controller.confirm_sb();
        Test.stopTest();

        List<DataTransferObject__c> dtoList = [SELECT Id FROM DataTransferObject__c WHERE eServicesMonitoringId__c =: monitoringId];
        DataTransferObject__c dto = [SELECT Id, RelatedProcess__c, AssetSerialNumber__c, eServicesMonitoringBatteryCheckDate__c FROM DataTransferObject__c WHERE eServicesMonitoringId__c =: monitoringId];
        Date expDate = Date.newInstance(2018, 01, 02);

        System.assertEquals(1, dtoList.size());
        System.assertEquals('12345', dto.AssetSerialNumber__c);
        System.assertEquals('eServicesMonitoring SB', dto.RelatedProcess__c);
        System.assertEquals(expDate, dto.eServicesMonitoringBatteryCheckDate__c);
    }

    //test for pv-plant validation landing page
    @IsTest
    static void eServicesMonitoringControllerPV() {
        Id monitoringId = [SELECT Id FROM MonitoringeServices__c].Id;
        PageReference pageRef = Page.LandingPageMonitoring;

        Test.startTest();
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', monitoringId);
        ApexPages.currentPage().getParameters().put('pageType', 'pv');
        eServicesMonitoringController controller = new eServicesMonitoringController();
        controller.assetWrapper.newPvComDate = '2018-01-01';
        controller.confirm_pv();
        Test.stopTest();

        Id assetId = [SELECT PVAsset__c FROM MonitoringeServices__c WHERE Id =: monitoringId].PVAsset__c;
        List<DataTransferObject__c> dtoList = [SELECT Id FROM DataTransferObject__c WHERE AssetId__c =: assetId AND eServicesMonitoringId__c =: monitoringId];
        DataTransferObject__c dto = [SELECT Id, RelatedProcess__c, CommissioningDatePV__c FROM DataTransferObject__c WHERE AssetId__c =: assetId AND eServicesMonitoringId__c =: monitoringId];
        Date expDate = Date.newInstance(2018, 01, 01);

        System.assertEquals(1, dtoList.size());
        System.assertEquals('eServicesMonitoring PV', dto.RelatedProcess__c);
        System.assertEquals(expDate, dto.CommissioningDatePV__c);
    }
}