/**
 * Created by m.muchow on 11.01.2019.
 * Initial - 11.01.2019 - M.Muchow - Apex Class to set Double Opt In on Lead after opening of landing page
 */

public without sharing class LandingPageDoubleOptInController {
    public String urlId;

    public LandingPageDoubleOptInController() {
        urlId = ApexPages.currentPage().getParameters().get('id');
    }

    public void checkDoubleOptIn() {
        Lead lead;
        lead = [SELECT Id, DoubleOptIn__c FROM Lead WHERE Id =: urlId];
        lead.DoubleOptIn__c = true;
        update lead;
    }
}