/*
* Author: Bartosz Jarmolinski
* test class: TermsAndConditionsTrigger_test
* Wrike ticket: AGB Objekt für sonnen Produkte einführen
*
* Version 2.0 (2018-09-04)
* - added Country as parameter - combination of country, language and type makes the unique identifier for the tnc(not only type as before)
* - deprecated the feature which creates new TnCsAcceptance everytime when new version is created
*
* Version 3.0 (2018-09-12)
* - added automatic versioning - version increments when a new TnC record of the kind is saved
*/
public class TermsAndCondTriggerHandler extends TriggerHandler {

    public override void beforeUpdate() {
        this.newTermsAndConditions();                
    }    
    public override void beforeInsert() {
        this.updateVersion();
    }
    public override void afterInsert() {
        this.newTermsAndConditions();

    }
    public override void afterUpdate() {
    }


    private void newTermsAndConditions() {
        // this method marks all TnC document as not current if the new version is uploaded and marked as current

        List<TermsAndConditions__c> tncs = (List<TermsAndConditions__c>) Trigger.new;
        Map<Id, TermsAndConditions__c> oldMap = (Map<Id, TermsAndConditions__c>) Trigger.oldMap;
        Map<Id, TermsAndConditions__c> newMap = (Map<Id, TermsAndConditions__c>) Trigger.newMap;

        // validate that no more than one marked as current of the the particular type and language and country is in the map(e.g to avoid data inconsitency via mass record update)
        List<AggregateResult> currentTncMap = [SELECT Type__c, Country__c, Language__c, COUNT(Id) cnt FROM TermsAndConditions__c WHERE
                                                Id IN :newMap.keySet() AND Current__c = true GROUP BY Type__c, Country__c, Language__c];

        // add error if more than one document of the same kind is marked as current in the new context
        for (AggregateResult ar : currentTncMap) {
            if ( (Integer)ar.get('cnt') > 1 ) {
                System.debug('Error: Only one record can be marked as current for the combination of type, country and language');
                ar.addError('Error: Only one record can be marked as current for the combination of type, country and language');
            }
        }

        Set<String> types = new Set<String>(); // types of newly created terms and conditions versions
        Set<String> countries = new Set<String>(); // ISO country codes of new terms and conditions
        Set<String> languages = new Set<String>(); // language of the TnC - ISO codes

        //List<TnCsAcceptance__c> newAcc = new List<TnCsAcceptance__c>(); // list of TnCsAcceptance to be created with the new version of Terms and conditions
        Map<String, Id> mapTypeId = new Map<String, Id>();

        // create sets of countries, languages and types of TnCs which were marked current in this execution context
        for(TermsAndConditions__c tnc : tncs){
            if(Trigger.isUpdate){
                TermsAndConditions__c oldObj = (TermsAndConditions__c)Trigger.oldMap.get(tnc.Id);
                if(Trigger.isUpdate && tnc.Current__c == true && oldObj.Current__c == false) {
                    types.add(tnc.Type__c);
                    countries.add(tnc.Country__c);
                    languages.add(tnc.Language__c);
                }               
            }
            if(Trigger.isInsert && tnc.Current__c == true){
                types.add(tnc.Type__c);
                countries.add(tnc.Country__c);
                languages.add(tnc.Language__c);
            }
        }

        // uncheck Current__c on every other TermsAndConditions of the given kind
        // find list of old terms and conditions marked as current - the current on them will be unchecked
        List<TermsAndConditions__c> oldTncs = [SELECT id, Country__c, Type__c, Language__c, Current__c FROM TermsAndConditions__c WHERE Type__c IN :types AND Country__c IN:countries AND Language__c IN:languages AND Current__c = true AND Id NOT IN: newMap.keySet()];

        // iterate through the list of old TnCs
        for(TermsAndConditions__c t : oldTncs) {
            // for each old TnC iterate through the list of new TnC and check if they are the same kind of document
            for(TermsAndConditions__c newT : tncs) {
                if (newT.Country__c == t.Country__c && newT.Type__c == t.Type__c && newT.Language__c == t.Language__c && t.Current__c == true) {
                    // if same document identified, mark it as not current
                    t.Current__c = false;
                }
            }
        }
        update oldTncs;
    }

    private void updateVersion() {

        List<TermsAndConditions__c> tncs = (List<TermsAndConditions__c>) Trigger.new;

        List<AggregateResult> lastVersion = [SELECT MAX(Version__c) verNum, Type__c, Country__c, Language__c FROM TermsAndConditions__c
                                                GROUP BY Type__c, Country__c, Language__c ];

        for (TermsAndConditions__c tnc : tncs) {
            for (AggregateResult ar : lastVersion) {
                if (tnc.Type__c == ar.get('Type__c') && tnc.Country__c == ar.get('Country__c') && tnc.Language__c == ar.get('Language__c') ) {
                    Decimal verNum = (Decimal) ar.get('verNum');
                    if (verNum == null) {
                        tnc.Version__c = 1;
                    } else {
                        tnc.Version__c = (Decimal) ar.get('verNum') + 1;
                    }
                }
            }
            if (tnc.Version__c == null) {
                tnc.Version__c = 1;
            }
        }
    }
}