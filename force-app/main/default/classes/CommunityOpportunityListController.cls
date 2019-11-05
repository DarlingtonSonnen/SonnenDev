/**
 * CommunityOpportunityListController
 *
 * Controller for CommunityOpportunityList.cmp
 *
 * v1.1.0   ?
 * v1.2.0   2019-02-20  Marko Schmalenbach          Added ProductInterest__c and RoofSize__c (SOBCRM-1319)
 */
public with sharing class CommunityOpportunityListController {

    @AuraEnabled
    public static string getUserLocale() {
        //String communityId = Network.getNetworkId();
        //ConnectApi.Community community = ConnectApi.Community.getCommunity(communityId);

        return UserInfo.getLocale();
    }

    @AuraEnabled
    public static List<CommonWrapperClass.OpportunityCommunityWrapper> getOpportunityRows() {

        List<CommonWrapperClass.OpportunityCommunityWrapper> lstOpportunityRows =
							new List<CommonWrapperClass.OpportunityCommunityWrapper>();

        List<Opportunity> lstOpportunities = [
            SELECT
                Id,
                Name,
                StageName,
                PrimaryContact__c,
                FirstNameContact__c,
                LastNameContact__c,
                PhoneContact__c,
                EmailContact__c,
                Amount,
                PostalCodeContact__c,
                CityContact__c,
                PurchasingTimeframe__c,
                TOLABEL(ProductInterest__c),
                EnergyConsumption__c,
                RoofSize__c,
                ProposedSBC__c,			// SOBCRM-976 - Proposed Partner Account
                ProposedSBC__r.OwnerId	// SOBCRM-976 - Proposed Partner's Owner
            FROM
                Opportunity
            WHERE
                StageName='Open' AND
                AcceptedByPartner__c = FALSE AND
                RecordType.DeveloperName = 'PartnerPortal' AND
                ProposedSBC__c != NULL
        ];	// SOBCRM-976 - requires Proposed Partner on the Oppty

        if (lstOpportunities != null && lstOpportunities.size() > 0){

            for (Opportunity opp : lstOpportunities){

                CommonWrapperClass.OpportunityCommunityWrapper oppRow =
									new CommonWrapperClass.OpportunityCommunityWrapper();
                oppRow.id = opp.Id;
                oppRow.title = opp.Name;
                oppRow.stage = opp.StageName;
                oppRow.amount = opp.Amount;
                oppRow.name = opp.FirstNameContact__c;

                if (String.isNotBlank(opp.LastNameContact__c)) {
                    oppRow.name += ' ' + opp.LastNameContact__c.substring(0, 1) + '.';
                }

                if (String.isNotBlank(opp.PhoneContact__c) && opp.PhoneContact__c.length() > 5) {
                    oppRow.phone = opp.PhoneContact__c.substring(0, 5) + '...';
                }

                if (String.isNotBlank(opp.EmailContact__c) && opp.EmailContact__c.indexOf('@') > 0) {
                    oppRow.email = opp.EmailContact__c.substring(0, opp.EmailContact__c.indexOf('@')) + '@xxxxx.xx';
                }

                oppRow.postalCodeContact = opp.PostalCodeContact__c;
                oppRow.cityContact = opp.CityContact__c;
                oppRow.purchasingTimeframe = opp.PurchasingTimeframe__c;
                oppRow.energyConsumption = Integer.valueOf(opp.EnergyConsumption__c);

                // Product interest (SOBCRM-1319)
                oppRow.roofSize = opp.RoofSize__c;
                oppRow.productInterests = '';

                if (opp.ProductInterest__c != null) {
                    List<String> listInterests = opp.ProductInterest__c.split(';');
                    oppRow.productInterests = String.join(listInterests, ', ');
                }

                lstOpportunityRows.add(oppRow);
            }

        }

        return lstOpportunityRows;
    }

    @AuraEnabled
    public static void performBulkAction(string oppRows) {

        if(!string.isBlank(oppRows)){

            List<CommonWrapperClass.OpportunityCommunityWrapper> lstOppRecords =
				(List<CommonWrapperClass.OpportunityCommunityWrapper>)
                	System.JSON.deserialize(oppRows,List<CommonWrapperClass.OpportunityCommunityWrapper>.class);

            system.debug('Debug displaying all the records : lstOppRecords'+lstOppRecords);

            //Perform Operation with records
            for(CommonWrapperClass.OpportunityCommunityWrapper objOppRow:lstOppRecords)
            {
                if(objOppRow.isSelected)
                {
                    //Play with selected Records here
                    system.debug('Selected Record :'+objOppRow);
                }
            }
        }
    }

    @AuraEnabled
    public static Boolean opportunityAccept(Id oppId) {
        //system.debug('Debug opportunityAccept Controller method with oppId:' + oppId);

        try {
	        Opportunity opp = new Opportunity(Id=oppId, AcceptedByPartner__c=true, AcceptedByPartnerDate__c=Date.today());
        	update opp;
            return true;
        }
        catch(Exception ex) {
            system.debug(LoggingLevel.ERROR, ex);
            return false;
        }
    }

    @AuraEnabled
    public static Boolean opportunityReject(Id oppId, String rejectReason) {
        //system.debug('Debug opportunityReject Controller method with oppId:' + oppId);

        try {
            // SOBCRM-976 - dino.ursic@die-interaktiven.de, 03.07.2017
            // Query Oppportunity with all the newly required fields (ProposedPartner, ProposedPartnerOwner, Opportunity.Contact.Language)
            Opportunity opp = [SELECT Id, ProposedSBC__c, ProposedSBC__r.Name, ProposedSBC__r.OwnerId, PrimaryContact__r.Language__c FROM Opportunity WHERE Id = :oppId];

            // SOBCRM-976 - dino.ursic@die-interaktiven.de, 03.07.2017
            // - Create ParterStatistic record
			PartnerStatistics__c ps = new PartnerStatistics__c(Account__c=opp.ProposedSBC__c, Opportunity__c=oppId, New__c=true, Event__c='Rejected', Note__c=rejectReason, OpportunityRejectReason__c=rejectReason);
            insert ps;

            // SOBCRM-976 - dino.ursic@die-interaktiven.de, 03.07.2017
            // - Create Chatter Post in German if Opportunity.Contact.Language is 'de', or English otherwise
            String feedMessage = (opp.PrimaryContact__r.Language__c == 'de') ?
                				('Opportunity wurde von Partner ' + opp.ProposedSBC__r.Name + ' abgelehnt') :
            					('Opportunity was rejected by partner ' + opp.ProposedSBC__r.Name);
            ConnectApi.FeedElement feedPost = ConnectApi.ChatterFeeds.postFeedElement(null, oppId, ConnectApi.FeedElementType.FeedItem, feedMessage);
			//ConnectApi.ChatterFeeds.postCommentToFeedElement(null, feedPost.Id, 'Comment to the Feed Post above');

            // SOBCRM-976 - dino.ursic@die-interaktiven.de, 30.06.2017
            // - Clearing Proposed Partner field when an Opportunity gets rejected
            // - Setting Proposed Partner's Owner as the new Opportunity Owner
            // - "In der Component muss StageName='notSold' durch "Closed Dead" ersetzt werden.", Richard H., 29.06.2017
            // - "Bitte die Stage nicht auf "closed-dead" sondern auf "open" lassen", Uwe Becher, 13.07.2017
            //Opportunity opp = new Opportunity(Id=oppId, ProposedSBC__c=null, OwnerId=partnerOwnerId, StageName='Closed - Dead', NotSoldReason__c='Rejected', RejectedReason__c=rejectReason);
            opp.StageName = 'Open';
            opp.NotSoldReason__c = 'Rejected';
            opp.RejectedReason__c = rejectReason;
            if (opp.ProposedSBC__c != null)
            	opp.OwnerId = opp.ProposedSBC__r.OwnerId;
            opp.ProposedSBC__c = null;
//			opp.ClosedLostReason__c = 'other';		// Required by Opportunity.FillinClosedLostDetails Validation Rule for all non API/SysAdmin Profiles
//			opp.ClosedLostDetails__c = feedMessage; // Required by Opportunity.FillinClosedLostDetails Validation Rule for all non API/SysAdmin Profiles
        	update opp;

            System.debug('Ist erfolgreich gewesen');
            return true;
        }
        catch(Exception ex) {

            System.debug('War nicht erfolgreich: ' + ex);

            system.debug(LoggingLevel.ERROR, ex);
            return false;
        }
    }

    @AuraEnabled
    public static String getOpportunityRejectReasonOptions() {

        Schema.DescribeFieldResult fieldResult = Opportunity.RejectedReason__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        return JSON.serialize(fieldResult.getPicklistValues());
    }

    @AuraEnabled
    public static CommunityOpportunityListLabels getCommunityOpportunityListLabels() {
        system.debug(UserInfo.getUserName());
        system.debug(UserInfo.getLocale());
        system.debug(UserInfo.getLanguage());
        CommunityOpportunityListLabels coll = new CommunityOpportunityListLabels();
        system.debug(coll);
        return coll;
        //return new CommunityOpportunityListLabels();
    }

    public class CommunityOpportunityListLabels {
        @AuraEnabled public string buttonAcceptOpptyLabel;
        @AuraEnabled public string buttonRejectOpptyLabel;

        public CommunityOpportunityListLabels() {
            buttonAcceptOpptyLabel = System.Label.Community_Opportunity_List_Accept_Oppty;
            buttonRejectOpptyLabel = System.Label.Community_Opportunity_List_Reject_Oppty;
            //ZLabelTranslator t = new ZLabelTranslator();
            //buttonAcceptOpptyLabel = t.translate('Community_Opportunity_List_Accept_Oppty', UserInfo.getLanguage());
            //buttonRejectOpptyLabel = t.translate('Community_Opportunity_List_Reject_Oppty', UserInfo.getLanguage());
        }
    }
}