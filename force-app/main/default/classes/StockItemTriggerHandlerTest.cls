/**
 * Created by a.romero on 02/09/2019.
 */

@IsTest
private class StockItemTriggerHandlerTest {
    @TestSetup
    static void testSetup() {

        Account acc = new Account(Name='newAccount');
        insert acc;

        Asset a = new Asset(Name = '#12345 Bartosz LastName', INClientFirstName__c = 'Bartosz', INClientLastName__c = 'LastName', INClientPhoneNumber__c = '2354345', INClientStreet__c = 'Zossener',
                INClientAdditionToAddress__c='56', INClientZIPCode__c='10245', INClientSalutation__c='Mr.', INClientCity__c='Berlin', AccountId = acc.Id, Country__c = 'DE');
        insert a;

                Asset a1 = new Asset(Name = '#12345 Bartosz LastName', INClientFirstName__c = 'Bartosz', INClientLastName__c = 'LastName', INClientPhoneNumber__c = '2354345', INClientStreet__c = 'Zossener',
                INClientAdditionToAddress__c='56', INClientZIPCode__c='10245', INClientSalutation__c='Mr.', INClientCity__c='Berlin', AccountId = acc.Id, Country__c = 'DE', SerialNumber = '13456');
        insert a1;
        
        Id defalt = Schema.SObjectType.StockItem__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();

        StockItem__c si = new StockItem__c();
        si.SerialNumber__c = '23456';
        si.Asset__c = a.Id;
        si.RecordTypeId=defalt;
        insert si;

        // create stock item with different serial number
        StockItem__c s2 = new StockItem__c();
        s2.SerialNumber__c = '23000';
        s2.Asset__c = a.Id;
        s2.RecordTypeId=defalt;
        insert s2;

        Id casTechnicalRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('TechnicalSupportCase').getRecordTypeId();

        Case cLinkCase = new Case(Subject = 'New Case', Status = 'New', Type = 'Request', Impact__c = '2. High', StockItem__c = s2.Id, RecordTypeId = casTechnicalRecordTypeId);
        insert cLinkCase;

        Case cLinkCase1 = new Case(Subject = 'New Case', Status = 'New', Type = 'Request', Impact__c = '2. High', StockItem__c = s2.Id, RecordTypeId = casTechnicalRecordTypeId);
        insert cLinkCase1;

    }


    @IsTest
    static void testRelateCaseAsset() {

        Id converted = Schema.SObjectType.StockItem__c.getRecordTypeInfosByName().get('Converted').getRecordTypeId();

        StockItem__c s2 = [SELECT Id,RecordTypeId,Asset__c FROM StockItem__c WHERE SerialNumber__c='23000'].get(0);
        s2.RecordTypeId = converted;

        StockItem__c si = [SELECT Id,RecordTypeId,Asset__c FROM StockItem__c WHERE SerialNumber__c='23456'].get(0);
        si.RecordTypeId = converted;

        Case cLinkCase2 = new Case(Subject = 'New Case', Status = 'New', Type = 'Request', Impact__c = '2. High', StockItem__c = si.Id, AssetId = null);
        insert cLinkCase2;
        List<Case> lCases = [SELECT Id, AssetId FROM Case];

        Test.StartTest();
        update s2;
        update si;
        update lCases;
        Test.StopTest();
        lCases = [SELECT Id, AssetId FROM Case WHERE AssetId!=null];
        system.assert(lCases.size()==3);

    }

    @IsTest
    static void testFindSerialNumber() {

        StockItem__c s2 = [SELECT Id FROM StockItem__c WHERE SerialNumber__c='23000'].get(0);

        // change serial number of s2 to the same as si - should fail
        s2.SerialNumber__c = '23456';

        try {
            update s2;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unable to save the stock item because other stock items with the same serial numbers already exist'));
        }
    }

    @IsTest
    static void testFindExistingSerialNumber() {

        StockItem__c s2 = [SELECT Id FROM StockItem__c WHERE SerialNumber__c='23000'].get(0);

        // change serial number of s2 to the same as si - should fail
        s2.SerialNumber__c = '13456';

        try {
            update s2;
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unable to save the stock item because assets with these serial numbers already exist:'));
        }

    }
}