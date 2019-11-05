/*
* Created by Bartosz Jarmolinski on 02/07/2018 by Bartosz Jarmolinski
* - convertStockItem() - the method looks for stock items with the serial number like created asset and connects them automatically with the asset
*
* Update 05.03.2019 M.Muchow
* - added update to asset from stockitem fields
*
* Update 18.06.2019 M.Muchow
* - removed ManufacturingPlant__c from Asset SOQL and comment out line 60 to remove Picklist Field and replace it with a global picklist field
*
*
* Update 20.06.2019 A.Romero
* - updateCertificationStatus() - certification status field of Asset updated depending on the certification of the installer and dates of the Certification and Asset
*
*
*
*/

public class AssetTriggerHandler extends TriggerHandler {

    public override void afterInsert() {
        this.convertStockItems();
    }

    public override void beforeUpdate() {
        this.updateCertificationStatus();
    }

    public override void beforeInsert() {
        this.updateCertificationStatus();
    }

    private void convertStockItems() {
        // test covereage: ConvertStockItem_ApexController_test

        // custom meta data types to control execution - not in test - in test it always runs to ensure code coverage
        StockItemSetting__mdt setting = [SELECT AssetTriggerOn__c FROM StockItemSetting__mdt WHERE Label = 'Trigger Settings' LIMIT 1];

        if (setting.AssetTriggerOn__c == false && !Test.isRunningTest()) {
            return;
        }

        List<Asset> triggerNew = (List<Asset>) Trigger.new;
        Set<String> serialNumbers = new Set<String>(); // serial numbers from the stock item
        Map<String, Asset> serialNumMap = new Map<String, Asset>(); // serial number as key, asset as value

        // search for stock items with the same serial number that are not converted

        for (Asset a : triggerNew) {
            serialNumbers.add(a.SerialNumber);
            serialNumMap.put(a.SerialNumber, a);
        }

        Id recordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'converted' AND SobjectType = 'StockItem__c' LIMIT 1].Id;

        List<StockItem__c> stockItems = [
                SELECT Id, SerialNumber__c, DistributorSBC__c, FinalInspectionDate__c, ShippingDate__c, RevisionLevel__c, ManufacturingPlant__c, Product2__c
                FROM StockItem__c
                WHERE SerialNumber__c IN :serialNumbers
                AND RecordTypeId != :recordTypeId
        ];

        //per 05.03.2019 to update Asseet with Stockitem informations after CA created Asset
        List<Asset> assetToUpdate = [SELECT DistributorSBC__c, FinalInspectionDate__c, ShippingDate__c, RevisionLevel__c, Product2Id FROM Asset WHERE SerialNumber IN :serialNumbers];

        // convert the stock items and link with the assets
        if (stockItems.size() > 0) {

            for (StockItem__c si : stockItems) {
                si.Asset__c = serialNumMap.get(si.SerialNumber__c).Id;
                si.Account__c = serialNumMap.get(si.SerialNumber__c).AccountId;
                si.RecordTypeId = recordTypeId;

                for (Asset a : assetToUpdate) {
                    a.DistributorSBC__c = si.DistributorSBC__c;
                    a.FinalInspectionDate__c = si.FinalInspectionDate__c;
                    a.ShippingDate__c = si.ShippingDate__c;
                    a.RevisionLevel__c = si.RevisionLevel__c;
                    //a.ManufacturingPlant__c = si.ManufacturingPlant__c;
                    a.Product2Id = si.Product2__c;
                }
            }
            update stockItems;
            update assetToUpdate;

            List<Case> cases = [SELECT Id, StockItem__c, StockItem__r.SerialNumber__c, AssetId FROM Case WHERE StockItem__r.SerialNumber__c IN :serialNumbers];
            for (Case c : cases) {
                c.AssetId = serialNumMap.get(c.StockItem__r.SerialNumber__c).Id;

            }
            update cases;
        }
    }


    private void updateCertificationStatus() {

        List<Asset> assets = (List<Asset>) Trigger.new;
        Map<Id, Asset> oldMap = (Map<Id, Asset>) Trigger.oldMap;
        Set<Asset> updateAssets = new Set<Asset>();
        Set<Id> assetProducts = new Set<Id>();
        Set<Id> assetContacts = new Set<Id>();
        Set<Id> certifications = new Set<Id>();
        Set<Id> productCertifications = new Set<Id>();
        Set<Id> products = new Set<Id>();
        Map<Id, Certificate__c> certContacts = new Map<Id, Certificate__c>();
        Date certificationDate;
        Boolean revoked;
        Id batteryRecordId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();

        for (Asset a : assets) {
            if (a.RecordTypeId == batteryRecordId) {
                if (Trigger.isUpdate) {
                    // If commissioningDate changes or installer changes
                    if (a.CommissioningDateTime__c != oldMap.get(a.Id).CommissioningDateTime__c && a.CommissioningDateTime__c != null || a.Installer__c != oldMap.get(a.Id).Installer__c && a.Installer__c != null) {

                        assetProducts.add(a.Product2Id);
                        assetContacts.add(a.Installer__c);
                        updateAssets.add(a);

                    }
                } else if (Trigger.isInsert) {
                    // If the date and the installer are not null then we can proceed
                    if (a.CommissioningDateTime__c != null && a.Installer__c != null) {

                        assetProducts.add(a.Product2Id);
                        assetContacts.add(a.Installer__c);
                        updateAssets.add(a);
                    }
                }
            }
        }

        // Skip the block in there is no installer related with the asset
        if (assetContacts.size() > 0) {

            // We retrieve the certificate information. Date of the certification, if it has been revoked, the contact of the certificate (Installer), the certification that we are looking for
            for (Certificate__c certificate : [SELECT Id, CertificateRevoked__c, StartDate__c,Certification__c,Contact__c FROM Certificate__c WHERE Contact__c = :assetContacts]) {
                certificationDate = certificate.StartDate__c;
                revoked = certificate.CertificateRevoked__c;
                certContacts.put(certificate.Contact__c, certificate);
                certifications.add(certificate.Certification__c);
            }

            // Retrieve the object where we have stored the link of the certification and the product
            for (ProdCertJunction__c pcj : [SELECT Certification__c, ProductCertification__c FROM ProdCertJunction__c WHERE Certification__c = :certifications]) {
                productCertifications.add(pcj.ProductCertification__c);
            }

            // Retrieve the product of the certification
            for (ProductCertification__c pc : [SELECT Id, Product__c FROM ProductCertification__c WHERE Id = :productCertifications]) {
                products.add(pc.Product__c);
            }

            for (Asset a : updateAssets) {
                Certificate__c certificated;
                // If the installer of the asset has certificate
                if (certContacts.get(a.Installer__c) != null) {
                    certificated = certContacts.get(a.Installer__c);
                }

                //System.debug('Compare dates??' + a.CommissioningDateTime__c + ' > ' + certificationDate);
                //System.debug('Revoked?'+ revoked);
                //System.debug('Instalador? '+ c.Contact__c + ' == ' + a.Installer__c);
                //System.debug('Product certificado? ' + a.Product2Id + ' IN: ' + products);


                // If the instalation date is after the certification date and the installer has the right certificate for the instalation (not revoked and same product as the asset)
                if (a.CommissioningDateTime__c > certificationDate && revoked != true && certificated != null && products.contains(a.Product2Id)) {
                    a.CertificationStatus__c = true;
                } else {
                    a.CertificationStatus__c = false;
                }
            }
        }

    }
}