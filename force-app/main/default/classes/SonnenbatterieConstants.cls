public class SonnenbatterieConstants {
	
    public static final Id ACC_RT_SBC;
    public static final Id CAMP_RT_BONUS;
    
    private static Id LEAD_STATUS_LONG_TERM_TO_OPEN_QUEUE;
    private static Id COMMUNITY_CONTRACT_BONUS_CAMPAIGN_ID;
    
    private static Map<String,Map<String,Id>> mRecordTypeDeveloperNameToId;
        
    public static final Set<String> CAMPAIGN_TYPES_PROJECT = new Set<String>{'Fair','Retail','Initiation','Promotion','Airport','Customer Event'};
    
    static {
       ACC_RT_SBC = Account.sObjectType.getDescribe().getRecordTypeInfosByName().get('Partner').getRecordTypeId();
       CAMP_RT_BONUS = Campaign.sObjectType.getDescribe().getRecordTypeInfosByName().get('Bonus').getRecordTypeId();
   }
    
    /**
     * Returns the ID of the queue which is configured as owner
     * after a Lead's status changed from "Long Term" to "Open" in
     * LeadStatusLongTermToOpenBatch.
     * 
     * @since 2016-06-14 (MSB)
     */
    public static Id getLeadStatusLongTermToOpenQueueId() {

        if (LEAD_STATUS_LONG_TERM_TO_OPEN_QUEUE != NULL) {
            return LEAD_STATUS_LONG_TERM_TO_OPEN_QUEUE;            
        }
        
        // Otherwise get queue by GeneralSetting
		GeneralSettings__c queueName = GeneralSettings__c.getValues('leadStatusLongTermToOpenQueue');
        
        if (queueName != NULL && queueName.Value__c != NULL) {
            List<Group> queueGroup = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :queueName.Value__c];
            if (queueGroup.size() == 1) {
            	LEAD_STATUS_LONG_TERM_TO_OPEN_QUEUE = queueGroup.get(0).Id;
            }
        }
        
        return LEAD_STATUS_LONG_TERM_TO_OPEN_QUEUE;
    } 
    
    /**
     * Get the Campaign ID for new Bonuses which are created
     * from new Community Contracts
     * 
     * @since 2016-05-08
     */
    public static Id getCommunityContractBonusCampaignId() {
        
        Id idCampaign;
        
        try {            
            idCampaign = (Id) GeneralSettings__c.getValues('communityContractBonusCampaignId').Value__c;
        }
        catch (Exception e) {            
        }
        
        return idCampaign;
    }

    /**
     * Get active RecordTypeId for an object by DeveloperName
     */
    public static Id getRecordTypeIdByObjectAndDeveloperName(String sObjectName, String sDeveloperName) {
        
        Id idRecordType;
        Map<String,Id> mObjectRecordTypes = getRecordTypeIdsByObjectName(sObjectName);
        
        if (!mObjectRecordTypes.isEmpty()) {
        	idRecordType = mObjectRecordTypes.get(sDeveloperName);    
        }
        
        return idRecordType;
    }
    
    /**
     * Get all active RecordType for an object name as a map
     */ 
    public static Map<String,Id> getRecordTypeIdsByObjectName(String sObjectName) {
        
        Map<String,Id> mObjectRecordTypes;
        
        // Init active RecordTypes if not done yet
        if (mRecordTypeDeveloperNameToId == NULL) {
            
            mRecordTypeDeveloperNameToId = new Map<String,Map<String,Id>>();
            List<RecordType> recordTypes = new List<RecordType>([SELECT Id, Name, DeveloperName, SObjectType FROM RecordType WHERE IsActive = true]);
            
            for (RecordType oRecordType : recordTypes) {                   
                if (mRecordTypeDeveloperNameToId.get(oRecordType.SObjectType) == NULL) {
                    mRecordTypeDeveloperNameToId.put(oRecordType.SObjectType, new Map<String,Id>());
                }                    
                mRecordTypeDeveloperNameToId.get(oRecordType.SObjectType).put(oRecordType.DeveloperName, oRecordType.Id);
            }
        }
        
        if (mRecordTypeDeveloperNameToId.containsKey(sObjectName)) {
            mObjectRecordTypes = mRecordTypeDeveloperNameToId.get(sObjectName);
        }
        
		return mObjectRecordTypes;               
    }
}