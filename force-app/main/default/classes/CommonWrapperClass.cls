public class CommonWrapperClass {

    /*******************************************/
    /* Wrapper class to display Opportunity    */
    /*******************************************/

    public class OpportunityCommunityWrapper {

        @AuraEnabled public Boolean isSelected;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String postalCodeContact;
        @AuraEnabled public String cityContact;
        @AuraEnabled public String purchasingTimeframe;
        @AuraEnabled public Integer energyConsumption;
        @AuraEnabled public Integer numResidents;
        @AuraEnabled public String roofSize; // added with SOBCRM-1319
        @AuraEnabled public String productInterests; // added with SOBCRM-1319

        public OpportunityCommunityWrapper(){}
    }
}