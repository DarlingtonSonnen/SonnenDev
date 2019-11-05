/*
 * Created by Bartosz Jarmolinski on 29/06/2018
 * the class is apex controller for lightning component - lightning action which converts stock item record to asset
 * 
 * Version 2.0 - 03/07/2018
 * - added method linkCases(Id siId, Id assetId) - links existing cases under stock item to the respective asset
 *
 * Version 2.1 - 21/08/2018
 * - added methods linkFiles and linkAttachments - which link existing files/attachments under stock item to the asset
 *
 * Version 2.2 - 22/08/2018
 * - added Country__c property to the asset to make sure the Country Iso Code is filled in on the asset
 *
 * Version 3.0 - 01/11/2018
 * - adding dynamic field filling - if new fields are created on stock item and there are fields with the same api names on the asset, they will be synced from SI to Asset as well
 * - added record type parameter for newly created asset (battery)
 * - added client state to the fields to be moved
 *
 * Version 3.1 - 03/01/2019 by Bartosz
 * - added Product2__c field to the conversion process (the field cannot be included in the auto sync because Asset.Product2 is a standard field)
*/
public with sharing class ConvertStockItem_ApexController {
	
    @AuraEnabled
    public static String createAsset(Id stockItemId) {

        // get all field names from stock item and asset
        Map<String, Schema.SObjectField> M = Schema.SObjectType.Asset.fields.getMap(); // map of asset fields
        Map<String, Schema.SObjectField> N = Schema.SObjectType.StockItem__c.fields.getMap(); // map of stock item fields

        // create dynamic query to get all field values from the stock item
        String siQuery = 'SELECT ';

        for (Integer i=0; i< N.values().size(); i++) {
            if (i != N.values().size() - 1) {
                siQuery = siQuery + N.values()[i].getDescribe().getName() + ', ';
            } else if (i == N.values().size() - 1) {
                siQuery = siquery + N.values()[i].getDescribe().getName() + ' FROM StockItem__c WHERE Id = \'' + stockItemId + '\' LIMIT 1';
            }
        }
        System.debug(siQuery);

        StockItem__c si = Database.query(siQuery);

        // find record type Id for converted stockItems
        Id converted = Schema.SObjectType.StockItem__c.getRecordTypeInfosByDeveloperName().get('Converted').getRecordTypeId();

        // check if asset with the same serial number already exists and link the SI with it if so
        if (si.SerialNumber__c != null && si.SerialNumber__c != '') {
            List<Asset> aList = [SELECT Id, AccountId FROM Asset WHERE SerialNumber = :si.SerialNumber__c];
            if (aList.size() > 0) {
                si.Asset__c = aList[0].Id;
                si.Account__c = aList[0].AccountId;
                si.RecordTypeId = converted; // record type for converted assets
                
                try {
                    update si;
                    
                    // link the stock item cases, files and attachments with the asset
                    linkCases(si.Id, aList[0].Id);
                    linkAttachments(si.Id, aList[0].Id);
                    linkFiles(si.Id, aList[0].Id);
                    
                    return 'Success: The asset already exists. The Stock Item has been linked to it.';
                } catch (Exception e) {
                    return 'Error: ' +e.getMessage();
                }
            }            
        } else {
            return 'Error: Serial number is mandatory for conversion to asset.';
        }
        
        // if no assets found and serial number is not null, create a new asset if required info is provided
        if (si.ClientCity__c != null && si.Country__c != null && si.ClientPhoneNumber__c != null && si.FirstName__c != null && 
            si.LastName__c != null && si.SerialNumber__c != null && si.Type__c != null) {

                Id recordTypeAsset = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('battery').getRecordTypeId();

                Asset a = new Asset();
                a.Name = '#'+ si.SerialNumber__c + ' ' + si.FirstName__c + ' ' + si.LastName__c;
                a.RecordTypeId = recordTypeAsset;
                a.SerialNumber = si.SerialNumber__c;
                a.INClientFirstName__c = si.FirstName__c;
                a.INClientLastName__c = si.LastName__c;
                a.INClientPhoneNumber__c = si.ClientPhoneNumber__c;
                a.INClientEmail__c = si.ClientEmail__c;
                a.InClientEmail2__c = si.ClientEmail__c;
				a.INClientStreet__c = si.ClientStreet__c;
				a.INClientCity__c = si.ClientCity__c;
                a.INClientState__c = si.ClientState__c;
				a.INClientZIPCode__c = si.ClientZIPCode__c;
                a.INClientCountry__c = CountryWrapper.ConvertCountry().get(si.Country__c);
                a.Country__c = CountryWrapper.ConvertCountryIso().get(si.Country__c);
                a.AccountId = null;
                a.ContactId = null;
                a.Product2Id = si.Product2__c;


                //*** populate additional fields which may be created in the future - api names on the Stock item and Asset must be the same for the sync to happen
                for (String key : M.keySet()) {
                    for (String k : N.keySet()) {
                        // check and find fields on the stock item with the same name as on asset, check if they are of the same type
                        if (M.get(key).getDescribe().getName() == N.get(k).getDescribe().getName() &&
                                M.get(key).getDescribe().getSOAPType() == N.get(k).getDescribe().getSOAPType() ) {

                            // only populate the asset field if the current user have rights to do so and the field is still empty
                            if (M.get(key).getDescribe().isCreateable() && a.get(M.get(key).getDescribe().getName()) == null ) {

                                a.put(M.get(key).getDescribe().getName(), si.get(N.get(k).getDescribe().getName()));
                            }
                        }
                    }
                }
                //***

                List<Asset> asList = new List<Asset>();
                asList.add(a);
                DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(asList);
                Map<Id, Map<String, Id>> idMap = dch.handleObjectsv2();
                a.AccountId = idMap.get(a.Id).get('Account');
                a.ContactId = idMap.get(a.Id).get('Contact');

                try {
                    insert a;
                    
                    // update stock item by linking it to the asset
                    si.Asset__c = a.Id;
                    si.Account__c = a.AccountId;
                    si.RecordTypeId = converted;
					update si; 

                    // link the stock item cases, attachments and files with the asset
                    linkCases(si.Id, a.Id);
                    linkAttachments(si.Id, a.Id);
                    linkFiles(si.Id, a.Id);
                    
                    return 'Success: The asset has been successfully created and linked with the stock item.';
                    
                } catch (Exception e) {
                    return 'Error has occured: '+ e.getMessage();
                }	
            }
        
        return 'Error: The data on stock item is not complete';
    }

    public static void linkCases(Id siId, Id assetId) {
        // link the stock item cases to the asset 
        List<Case> cases = [SELECT StockItem__c, AssetId FROM Case WHERE StockItem__c = :siId];
        for (Case c : cases) {
            c.AssetId = assetId;
        }
        update cases;
    }

    public static void linkAttachments(Id siId, Id assetId) {
        List<Attachment> attachments = [SELECT ParentId, Body, Name, ContentType FROM Attachment WHERE ParentId =:siId ];
        System.debug(attachments.size());
        List<Attachment> newAttchment = new List<Attachment>();
        for (Attachment a : attachments) {
            Attachment aN = new Attachment();
            aN.ParentId = assetId;
            aN.Body = a.Body;
            aN.Name = a.Name;
            aN.ContentType = a.ContentType;
            newAttchment.add(aN);
        }

        System.debug(newAttchment);
        System.debug(attachments);
        insert newAttchment;
        delete attachments;
    }

    public static void linkFiles(Id siId, Id assetId) {
        System.debug(siId);
        System.debug(assetId);

        List<ContentDocumentLink> cvList = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId =:siId];
        System.debug(cvList);
        List<ContentDocumentLink> cvNew = new List<ContentDocumentLink>();
        for (ContentDocumentLink cvl : cvList) {
            ContentDocumentLink cvA = new ContentDocumentLink();
            cvA.ContentDocumentId = cvl.ContentDocumentId;
            cvA.LinkedEntityId = assetId;
            cvA.ShareType = 'V';
            cvNew.add(cvA);
            System.debug(cvA);
        }
        insert cvNew;
    }
}