/**
 * Created by m.muchow on 17.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class ConvertStockItemEUnit {
    public static Component__c createEUnitFromStockItem(StockItem__c stockItem, Map<String, Object> requestMap, Asset convertedAsset, String sRequestJSON) {

        Id electricUnitRecordTypeId = Schema.SObjectType.Component__c.getRecordTypeInfosByDeveloperName().get('ElectricUnit').getRecordTypeId();
        Component__c convertedComponent;

        List<Component__c> convertedComponentList = [SELECT Id, Name, RecordTypeId, Asset__c, Current__c, SerialNumber__c, ShippingDate__c,
                FinalInspectionDate__c, RevisionLevel__c, ManufacturingPlant__c, ActiveSince__c, Hierarchy__c
                FROM Component__c WHERE SerialNumber__c =: stockItem.SerialNumber__c];

        if (convertedComponentList.isEmpty()) {
            convertedComponent = new Component__c();
        } else {
            convertedComponent = convertedComponentList[0];
        }

        if (stockItem.UpdatedByCA__c == true) {
            convertedComponent.INSoldByInstaller__c = (String) requestMap.get('IN_IN_SoldbyInstaller');
            convertedComponent.INInstallerCompany__c = (String) requestMap.get('IN_IN_Company');
            convertedComponent.INInstallerID__c = (String) requestMap.get('IN_IN_Certificate');
            convertedComponent.INInstallerName__c = (String) requestMap.get('IN_IN_FirstName') + ' ' + (String) requestMap.get('IN_IN_LastName');
            convertedComponent.INInstallerEmail__c = (String) requestMap.get('IN_IN_Email');
            convertedComponent.CommAssistPayload__c = sRequestJSON;
            convertedComponent.CommissioningDateTime__c = Datetime.valueOfGmt((String) requestMap.get('IN_UTC'));
        }

        convertedComponent.Name = '#'+stockItem.SerialNumber__c+' Electric Unit';
        convertedComponent.RecordTypeId = electricUnitRecordTypeId;
        convertedComponent.Asset__c = convertedAsset.Id;
        convertedComponent.Current__c = true;
        convertedComponent.SerialNumber__c = stockItem.SerialNumber__c;
        convertedComponent.ShippingDate__c = stockItem.ShippingDate__c;
        convertedComponent.FinalInspectionDate__c = stockItem.FinalInspectionDate__c;
        convertedComponent.RevisionLevel__c = stockItem.RevisionLevel__c;
        convertedComponent.ManufacturingPlant__c = stockItem.ManufacturingPlant__c;
        convertedComponent.Hierarchy__c = stockItem.Hierarchy__c;
        if (convertedComponent.ActiveSince__c == null) {
            convertedComponent.ActiveSince__c = System.now();
        }

        upsert convertedComponent;

        return convertedComponent;
    }
}