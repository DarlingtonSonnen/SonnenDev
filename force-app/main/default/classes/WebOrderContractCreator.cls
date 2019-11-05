/**
 * WebOrderContractCreator
 *
 * Create a Contract based on Web Order(Opportunity)
 *
 * Changelog
 * ---------
 *
 * v1.0.0   2018-03-13  Andrey safronenko           Initial version (SOBCRM-1156)
 * v1.1.0   2018-03-19  Polina Tsuban-Drobot        Added AnnualConsumptionTotal_c as decimal (SOBCRM-1162)
 * v1.2.0   2018-03-23  Polina Tsuban-Drobot        Implemented dynamical detecting of field type,
 *                                                  added not calling attachments creation when they are null (SOBCRM-1168)
 * v1.3.0   2018-03-27  Polina Tsuban-Drobot        Added setting BillingCountry__c and SEPADate__c (SOBCRM-1171)
 * v1.4.0   2018-03-30  Polina Tsuban-Drobot        Added setting ContractingPartySalutation__c in German (SOBCRM-1173)
 * v1.5.0   2018-04-26  Polina Tsuban-Drobot        Added setting OpportunitySource__c field, did Contract creation to be safe (when we don't have product) (SOBCRM-1163)
 * v1.6.0   2018-05-04  Marko Schmalenbach          Fix: updateContractByOrderInputDefinitionValues(): Do not handle value if it is null as this will
 *                                                  change nothing to a new contract and will potentially raise NULL exceptions at conversions
 * v1.7.0   2018-05-09  Marko Schmalenbach          Removed attachment handling here as this is done in RESTServiceOrder on the Opportunity (SOBCRM-1169).
 *                                                  All files from Opportunity are now also linked to the created Contract.
 * v1.8.0   2018-06-08  Polina Tsuban-Drobot        Added setting CommunityFee__c field (SOBCRM-1202)
 * v1.9.0   2018-06-18  Marko Schmalenbach          Added creation of Terms and Condition acceptances (SOBCRM-1189)
 * v1.10.0  2018-06-20  Marko Schmalenbach          Added creation of PV Plant as Asset (SOBCRM-1216)
 *                                                  Implemented handling of multiple Target Fields for a Order Input Definition Value
 * v1.10.1  2018-06-21  Marko Schmalenbach          Fix in updateSObjectsByOrderInputDefinitionValues(): Initialize PV Plant only if value is NOT blank
 * v1.11.0  2018-07-03  Marko Schmalenbach          Added creation of Meter Installation (SOBCRM-1154)
 * v1.12.0  2018-09-19  Marko Schmalenbach          - Automatically activate contract (SOBCRM-1238)
 *                                                  - Relate Terms and Conditions Contact to CustomerSignedId (SOBCRM-1259)
 * v1.13.0  2018-10-12  Marko Schmalenbach          Switched to use of WebOrderUtil.updateSObjectsByOrderInputDefinitionValues()
 * v1.13.1  2018-10-17  Marko Schmalenbach          Do not set Contract.ContractDataApproved__c anymore (SOBCRM-1276)
 * v1.14.0  2018-10-31  Marko Schmalenbach          Do not activate Contract by setting Contract.Status to "Concluded" after creation anymore (SOBCRM-1287)
 * v1.14.1  2018-11-01  Marko Schmalenbach          Relate Contract to created PV Plant Asset not PV Plant to Contract anymore (SOBCRM-1288)
 * v1.14.2  2019-01-30  Marko Schmalenbach          Removed checkbox values IsEnergyTariffClassified__c, IsInstallerSpezified__c, IsPVSizeSpezified__c, IsInstallationDocumented__c (SOBCRM-1310)
 * v1.14.3  2019-07-05  Michael Muchow              Changed line 286 to use Price of Flat Product for CommunityFee__c instead of Price of Community Product
 *
 * @author Andrey Safronenko <andrey.safronenko@vrpconsulting.com>
 * @see https://interaktiv.jira.com/browse/SOBCRM-1156
 * @see RESTServiceOrder
 * @see ContractCreatorFromOpportunityCtrl
 */
public class WebOrderContractCreator {

    private static final String DEBUG_HEADER = 'WebOrderContractCreator.';

    private static final String CONTRACT_OBJ    = 'Contract';
    private static final String CONTRACT_STATUS = 'Draft';

    private static final String PRODUCT_RECORD_TYPE        = 'eService';
    private static final String PRODUCT_BUNDLE_RECORD_TYPE = 'eServiceBundleProduct';

    private static final String SALUTATION_MR = 'Mr.';
    private static final String SALUTATION_MS = 'Ms.';
    private static final String SALUTATION_FRAU = 'Frau';
    private static final String SALUTATION_HERR = 'Herr';

    public static final String PV_PLANT_ASSET_RECORD_TYPE  = 'PVPlant';
    public static final String PV_PLANT_ASSET_DEFAULT_NAME = 'PV-Plant';

    /**
    * Contract creation
    *
    * @param listOpportunities
    */
    public static Contract createWebOrderContract(String id) {

        final String DEBUG_HERE = DEBUG_HEADER + 'createWebOrderContract() - ';

        //eService Product record type
        Id idRecordTypeProduct = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Product2', PRODUCT_RECORD_TYPE);
        Id idRecordTypeProductBundle = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Product2', PRODUCT_BUNDLE_RECORD_TYPE);

        Opportunity opportunity = [
            SELECT
                Id,
                RecordTypeId,
                CreatedDate,
                Email__c,
                Company__c,
                Phone__c,
                Salutation__c,
                FirstName__c,
                LastName__c,
                BillingStreet__c,
                BillingStreetNo__c,
                BillingPostalCode__c,
                BillingCity__c,
                BillingCountryIsoCode__c ,
                ShippingStreet__c,
                ShippingStreetNo__c,
                ShippingPostalCode__c,
                ShippingCity__c,
                AccountId,
                PrimaryContact__c,
                ContractDataApproved__c,
            (
                SELECT
                    ContentDocumentId,
                    ShareType
                FROM ContentDocumentLinks
            ),
            (
                SELECT
                    Id,
                    Product2Id,
                    Product2.Name,
                    Product2.RecordTypeId,
                    Product2.ContractRecordType__c,
                    Product2.ContractType__c,
                    Product2.ContractTariffType__c,
                    Product2.AmountFreeEnergy__c,
                    Product2.RecordType.Name,
                    TotalPrice
                FROM OpportunityLineItems
                WHERE Product2.RecordTypeId IN (:idRecordTypeProduct, :idRecordTypeProductBundle)
            ),
            (
                SELECT Id FROM OrderInputDefinitionValues__r
            )
            FROM Opportunity
            WHERE Id = :id
        ];

        //We expect only one energy product per web-order Opportunity

        if (!opportunity.OpportunityLineItems.isEmpty()) {

            OpportunityLineItem oliForMainProduct;
            OpportunityLineItem oliForBundleProduct;

            for (OpportunityLineItem oli : opportunity.OpportunityLineItems) {
                if (oli.Product2.RecordTypeId == idRecordTypeProduct) {
                    oliForMainProduct = oli;
                }
                else if (oli.Product2.RecordTypeId == idRecordTypeProductBundle) {
                    oliForBundleProduct = oli;
                }
            }

            System.debug(DEBUG_HERE + ' oliForMainProduct:: ' + oliForMainProduct);
            System.debug(DEBUG_HERE + ' oliForBundleProduct:: ' + oliForBundleProduct);

            System.debug(DEBUG_HERE +'ContractRecordType__c = '+ oliForMainProduct.Product2.ContractRecordType__c);

            Contract oContract = new Contract();

            updateCustomerAndAddress(oContract, oliForMainProduct, oliForBundleProduct, opportunity);

            Asset oPvPlantAssetDefault = new Asset(
                Name         = PV_PLANT_ASSET_DEFAULT_NAME,
                RecordTypeId = DiaUtilities.getRecordTypeId('Asset', PV_PLANT_ASSET_RECORD_TYPE)
            );
            List<TnCsAcceptance__c> listTermsAndConditionAcceptances = new List<TnCsAcceptance__c>();
            MeterInstallation__c oMeterInstallation = new MeterInstallation__c();

            List<Object> listObjectsToUpdate = new List<Object>{
                oContract,
                oliForMainProduct,
                listTermsAndConditionAcceptances,
                oMeterInstallation,
                oPvPlantAssetDefault.clone() // Special case with Assets!
            };

            List<Id> listOrderInputDefinitionValueIds = new List<Id>();
            for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : opportunity.OrderInputDefinitionValues__r) {
                listOrderInputDefinitionValueIds.add(oOrderInputDefinitionValue.Id);
            }

            Map<String, List<SObject>> mapSObjectsToUpdate = WebOrderUtil.updateSObjectsByOrderInputDefinitionValues(
                listOrderInputDefinitionValueIds,
                listObjectsToUpdate
            );

            updateAccount(oContract, opportunity);

            System.debug(DEBUG_HERE + 'Insert Contract: ' + JSON.serializePretty(oContract.getPopulatedFieldsAsMap()));
            insert oContract;
            System.debug(DEBUG_HERE + 'New Contract ID: '+ oContract.Id);
            System.debug(DEBUG_HERE + oContract);

            // Check for PvPlant Asset (SOBCRM-1216)
            Asset oPvPlantAsset = (Asset)mapSObjectsToUpdate.get('pvplant').get(0);

            if (oPvPlantAsset != null && oPvPlantAsset != oPvPlantAssetDefault) {

                // Relate to Account and Contract
                oPvPlantAsset.AccountId   = opportunity.AccountId;

                System.debug(DEBUG_HERE + 'New PvPlant Asset: ' + JSON.serializePretty(oPvPlantAsset.getPopulatedFieldsAsMap()));
                insert oPvPlantAsset;

                oContract.PVAsset__c = oPvPlantAsset.Id;

                Asset oPvPlantAssetTmp = [SELECT PvPlantName__c FROM Asset WHERE Id = :oPvPlantAsset.Id];
                oPvPlantAsset.Name = oPvPlantAssetTmp.PvPlantName__c;
                update oPvPlantAsset;

                System.debug(DEBUG_HERE + 'New PvPlant Asset Name and ID: ' + oPvPlantAsset.Name + ' (' + oPvPlantAsset.Id + ')');
            }
            else {
                System.debug(DEBUG_HERE + 'No PvPlant Asset created');
            }

            // Check for Meter Installation (SOBCRM-1154)
            if (oMeterInstallation != new MeterInstallation__c()) {

                // Relate to Account and Contract
                oMeterInstallation.Account__c  = opportunity.AccountId;
                oMeterInstallation.Contract__c = oContract.Id;

                System.debug(DEBUG_HERE + 'New Meter Installation: ' + JSON.serializePretty(oMeterInstallation.getPopulatedFieldsAsMap()));
                insert oMeterInstallation;
                System.debug(DEBUG_HERE + 'New  Meter Installation ID: ' + oMeterInstallation.Id);
            }
            else {
                System.debug(DEBUG_HERE + 'No Meter Installation created');
            }

            // Process Terms and Condition acceptances
            if (!listTermsAndConditionAcceptances.isEmpty()) {

                for (TnCsAcceptance__c oAcceptance : listTermsAndConditionAcceptances) {
                    oAcceptance.Contract__c = oContract.Id;
                    oAcceptance.Contact__c  = oContract.CustomerSignedId; // since SOBCRM-1259
                }
                System.debug(DEBUG_HERE + 'Insert ' + listTermsAndConditionAcceptances.size() + ' Terms and Condition acceptance(s)');
                insert listTermsAndConditionAcceptances;
            }

            // Create ContentDocumentLinks for each attached file
            if (opportunity.ContentDocumentLinks.size() > 0) {

                List<ContentDocumentLink> listNewContentDocumentLinks = new List<ContentDocumentLink>();

                for (ContentDocumentLink oContentDocumentLink : opportunity.ContentDocumentLinks) {
                    listNewContentDocumentLinks.add(new ContentDocumentLink(
                        ContentDocumentId = oContentDocumentLink.ContentDocumentId,
                        ShareType         = oContentDocumentLink.ShareType,
                        LinkedEntityId    = oContract.Id
                    ));
                }

                System.debug(DEBUG_HERE + 'Adding ' + listNewContentDocumentLinks.size() + ' ContentDocumentLink(s) to the contract');
                insert listNewContentDocumentLinks;
            }

            // Activate the Contract by setting status to "Concluded"
            // (2018-07-26, SOBCRM-1237)
            // Reverted with SOBCRM-1287 on 2018-10-31
            // if (contract.RecordTypeId != DiaUtilities.getRecordTypeId('Contract', 'SonnenFlat')) {
            //     contract.Status = 'Concluded';
            // }

            update oContract;

            return oContract;
        }

        return null;
    }

    /**
    * Set Contract Customer and Address information
    *
    * @param opportunity
    * @param opportunityLineItem
    * @param contract
    */
    private static void updateCustomerAndAddress(Contract contract, OpportunityLineItem oliForMainProduct,
        OpportunityLineItem oliForBundleProduct, Opportunity opp) {

        //Contract information
        List<RecordType> contractRecordType = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE DeveloperName = :oliForMainProduct.Product2.ContractRecordType__c
            AND SobjectType = :CONTRACT_OBJ
            LIMIT 1
        ];
        contract.OpportunitySource__c = opp.Id;
        contract.RecordTypeId = !contractRecordType.isEmpty() ? contractRecordType[0].Id : [SELECT Id FROM RecordType WHERE SObjectType = :CONTRACT_OBJ LIMIT 1].Id;
        contract.Status = CONTRACT_STATUS;
        contract.StartDate = opp.CreatedDate.date();
        contract.SEPADate__c = Date.newInstance(opp.CreatedDate.year(), opp.CreatedDate.month(), opp.CreatedDate.day());
        contract.Type__c = oliForMainProduct.Product2.ContractType__c;
        contract.TariffType__c = oliForMainProduct.Product2.ContractTariffType__c;
        contract.AmountOfFreeEnergy__c = oliForMainProduct.Product2.AmountFreeEnergy__c;
        contract.CommunityFee__c = oliForMainProduct.TotalPrice;

        //Customer information
        contract.ContractingPartyEmail__c = opp.Email__c;
        contract.ContractingPartyAccountName__c = opp.Company__c;
        contract.ContractingPartyPhone__c = opp.Phone__c;
        contract.ContractingPartySalutation__c = (opp.Salutation__c == SALUTATION_MR ? SALUTATION_HERR : (opp.Salutation__c == SALUTATION_MS ? SALUTATION_FRAU : opp.Salutation__c));
        contract.ContractingPartnerFirstname__c = opp.FirstName__c;
        contract.ContractingPartnerLastname__c = opp.LastName__c;

        //Address information
        contract.BillingStreet__c = opp.BillingStreet__c;
        contract.BillingStreetNumber__c = opp.BillingStreetNo__c;
        contract.BillingPostalCode__c = opp.BillingPostalCode__c;
        contract.BillingCity__c = opp.BillingCity__c;
        contract.BillingCountry__c = opp.BillingCountryIsoCode__c;
        contract.ShippingStreet__c = opp.ShippingStreet__c;
        contract.ShippingStreetNumber__c = opp.ShippingStreetNo__c;
        contract.ShippingPostalCode__c = opp.ShippingPostalCode__c;
        contract.ShippingCity__c = opp.ShippingCity__c;
    }

    /**
    * Assign Account to Contract
    * @param contract
    * @param opportunity
    */
    private static void updateAccount(Contract contract, Opportunity opportunity) {
        contract.AccountId = opportunity.AccountId;
        contract.CustomerSignedId = opportunity.PrimaryContact__c;
    }

    public class WebOrderContractCreatorException extends Exception {}
}