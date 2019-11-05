/**
 * Created by m.muchow on 17.04.2019.
 * Code coverage by the class AssetEndpointV3_Test
 */

public with sharing class ConvertStockItemLinkRelatedRecords {

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