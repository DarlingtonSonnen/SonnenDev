/**
 * Created by b.jarmolinski on 26/11/2018.
 */

@IsTest
private class SoluzioniFotoVoltaicoCallout_Test {

    @testSetup
    static void createData() {

        Campaign cm = new Campaign();
        cm.Name = 'IT|2018|Campagna Soluzioni Fotovoltaico';
        insert cm;

    }

    @IsTest
    static void testBehavior1() {
        //scenario 1 - lead received and created - no duplicates

        SoluzioniFotoVoltaicoCallout newInst = new SoluzioniFotoVoltaicoCallout();
        Test.startTest();
        newInst.execute(null);
        Test.stopTest();

        System.assertEquals(2, [SELECT Id FROM Lead].size());
    }

    @IsTest
    static void testBehavior2() {
        //scenario 2 - leads received - 1 already exists in salesforce as lead, another as contact
        // no new leads should be created from the callout as the existing emails match

        Lead l = new Lead(
                FirstName = 'Alessandra',
                LastName = 'Manfrin',
                City = 'Tocco Casauria',
                Phone = '0313 7139583',
                Email = 'mubhln5qfhk@fakemailgenerator.net'
        );
        insert l;

        Contact c = new Contact(
                FirstName = 'Dorotea',
                LastName = 'Cocci',
                MailingCity = 'Malva',
                Phone = '0339 5726738',
                Email = 'b5aev245i4b@fakemailgenerator.net'
        );
        insert c;

        SoluzioniFotoVoltaicoCallout newInst = new SoluzioniFotoVoltaicoCallout();
        Test.startTest();
        newInst.execute(null);
        Test.stopTest();

        System.assertEquals(1, [SELECT Id FROM Lead].size());

    }

    @IsTest
    static void testBehavior3() {
        //scenario 3 - test creation of leads failure

        SoluzioniFotoVoltaico__mdt data = [SELECT Username__c, Password__c, Header__c, CampaignId__c
                                            FROM SoluzioniFotoVoltaico__mdt WHERE Label='Data'];

        List<Lead> leads = new List<Lead>();

        Lead l = new Lead(
                FirstName = 'Sinibaldo',
                Email = 'sinibaldo@gmailc.com'
        ); // lead without lastName
        leads.add(l);

        Test.startTest();
        SoluzioniFotoVoltaicoCallout.createLeads(leads, data);
        Test.stopTest();

        System.assertEquals(1, [SELECT Id FROM Log__c WHERE Origin__c = 'Callout to api.soluzionefotovoltaico.it'].size());
        System.debug([SELECT Message__c FROM Log__c WHERE Origin__c = 'Callout to api.soluzionefotovoltaico.it'].Message__c);
    }
}