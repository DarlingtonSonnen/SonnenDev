/**
 * Created by m.muchow on 12.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class AssetEndpointAssetUpdate {

    public static Id updateAsset(Id stockItemId, Map<String, Object> requestMap, Boolean checkOldCA) {
        Id assetId;
        Asset uAsset;
        Id returnId;
        List<Contact> cInstallerList = new List<Contact>();
        if ((String) requestMap.get('IN_riverbox_changed') == 'false' || checkOldCA == true) {
            assetId = [SELECT Asset__c FROM StockItem__c WHERE Id =: stockItemId AND SerialNumber__c =: (String) requestMap.get('DE_Ticket_Number')].Asset__c;
        } else if ((String) requestMap.get('IN_riverbox_changed') == 'true' && (Map<String, Object>) requestMap.get('pro_cascade') == null) {
            assetId = [SELECT Asset__c FROM StockItem__c WHERE SerialNumber__c =: (String) requestMap.get('IN_riverbox_old_serial')].Asset__c;
        } else if ((String) requestMap.get('IN_riverbox_changed') == 'true' && (Map<String, Object>) requestMap.get('pro_cascade') != null) {
            Map<String, Object> mapCascading = (Map<String, Object>) requestMap.get('pro_cascade');
            String roleString = ((String)mapCascading.get('role')).capitalize();
            if (roleString == 'Master') {
                assetId = [SELECT Asset__c FROM StockItem__c WHERE SerialNumber__c =: (String) requestMap.get('IN_riverbox_old_serial')].Asset__c;
            }
        }
        if (assetId != null) {
            uAsset = [SELECT Id, INCommissioningDate__c, InstallationCommissioning__c, Installer__c, ServicePartner__c, Street__c, PostalCode__c, City__c, Country__c, INClientLanguage__c FROM Asset WHERE Id =: assetId];
            if (String.isNotBlank((String) requestMap.get('IN_IN_Certificate'))) {
                cInstallerList = [SELECT Id, AccountId, TopMCertificationId__c FROM Contact WHERE TopMCertificationId__c =: (String) requestMap.get('IN_IN_Certificate')];
            }
            StockItem__c uStockItem = [SELECT Id, RevisionLevel__c, ManufacturingPlant__c, FinalInspectionDate__c, ShippingDate__c, DistributorSBC__c FROM StockItem__c WHERE Id =: stockItemId];

            StaticResource countryLanguageISOResource = [SELECT Body FROM StaticResource WHERE Name = 'CountryLanguageISO' LIMIT 1];
            Map<String, Object> isoMap = (Map<String, Object>) JSON.deserializeUntyped(countryLanguageISOResource.Body.toString());

            if ((String) requestMap.get('IN_riverbox_changed') == 'false' || checkOldCA == true) {
                uAsset.Status = 'Installed';
                uAsset.INClientAdditionToAddress__c = (String) requestMap.get('IN_Address2');
                if (uAsset.INCommissioningDate__c == null && String.isNotBlank((String) requestMap.get('IN_UTC'))) {
                    uAsset.INCommissioningDate__c = Datetime.valueOfGmt((String) requestMap.get('IN_UTC')).dateGmt();
                }
                if (uAsset.INClientLanguage__c == null || uAsset.INClientLanguage__c == '') {
                    uAsset.INClientLanguage__c = (String)isoMap.get((String) requestMap.get('IN_Country'));
                }
                uAsset.INClientDataConfirmed__c = false;
            }
            uAsset.Name = '#'+(String) requestMap.get('DE_Ticket_Number')+' '+(String) requestMap.get('IN_FirstName')+' '+(String) requestMap.get('IN_LastName');
            uAsset.SerialNumber = (String) requestMap.get('DE_Ticket_Number');
            if (String.isNotBlank((String) requestMap.get('IN_UTC'))) {
                uAsset.CommissioningDateTime__c = Datetime.valueOfGmt((String) requestMap.get('IN_UTC'));
            }
            uAsset.INInstallerEmail__c = (String) requestMap.get('IN_IN_Email');
            if (String.isNotBlank((String) requestMap.get('IN_IN_FirstName')) && String.isNotBlank((String) requestMap.get('IN_IN_LastName'))) {
                uAsset.INInstallerName__c = (String) requestMap.get('IN_IN_FirstName')+' '+(String) requestMap.get('IN_IN_LastName');
            }
            uAsset.INInstallerID__c = (String) requestMap.get('IN_IN_Certificate');
            uAsset.INInstallerCompany__c = (String) requestMap.get('IN_IN_Company');
            uAsset.INSoldBy__c = (String) requestMap.get('IN_IN_SoldBy');
            uAsset.INSoldByInstaller__c = (String) requestMap.get('IN_IN_SoldbyInstaller');
            uAsset.INCommissioningAssistantVersion__c = (String) requestMap.get('DE_Software');
            if (uAsset.InstallationCommissioning__c == null && String.isNotBlank((String) requestMap.get('IN_UTC'))) {
                uAsset.InstallationCommissioning__c = Datetime.valueOfGmt((String) requestMap.get('IN_UTC')).dateGmt();
            }
            if (cInstallerList.size() > 0) {
                uAsset.Installer__c = cInstallerList[0].Id;
                uAsset.InstallingCompany__c = cInstallerList[0].AccountId;
                if ((String) requestMap.get('IN_IN_SoldbyInstaller') != 'false') {
                    uAsset.ServicePartner__c = cInstallerList[0].AccountId;
                }
            }
            if (uAsset.Street__c == null || uAsset.Street__c == '') {
                uAsset.Street__c = (String) requestMap.get('IN_Address1');
            }
            if (uAsset.PostalCode__c == null || uAsset.PostalCode__c == '') {
                uAsset.PostalCode__c = (String) requestMap.get('IN_ZipCode');
            }
            if (uAsset.City__c == null || uAsset.City__c == '') {
                uAsset.City__c = (String) requestMap.get('IN_City');
            }
            if (uAsset.Country__c == null || uAsset.Country__c == '') {
                uAsset.Country__c = (String) requestMap.get('IN_Country');
            }

            //update Asset from Stock Item
            uAsset.RevisionLevel__c = uStockItem.RevisionLevel__c;
            uAsset.ManufacturingPlant__c = uStockItem.ManufacturingPlant__c;
            uAsset.FinalInspectionDate__c = uStockItem.FinalInspectionDate__c;
            uAsset.ShippingDate__c = uStockItem.ShippingDate__c;
            uAsset.DistributorSBC__c = uStockItem.DistributorSBC__c;

            update uAsset;
        }
        if (uAsset != null) {
            returnId = uAsset.Id;
        }
        return returnId;
    }
}