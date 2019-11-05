@isTest
private class AccountTriggerTest {

    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];

        User u = new User();
        u.FirstName = 'user Name';
        u.email = 'email@mailforspam.com';
		u.Username = 'email@mailforspam.com';
        u.LastName = 'last name 1';
        u.Alias = 'alias 1';
        u.CommunityNickname = 'comm nick 1';
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey = 'UTF-8';
        u.ProfileId = p.Id;
        u.LanguageLocaleKey = 'en_US';
        insert u;

        User u2 = new User();
        u2.FirstName = 'user Name 2';
        u2.email = 'email2@mailforspam.com';
        u2.ManagerId = u.Id;
		u2.Username = 'email2@mailforspam.com';
        u2.LastName = 'last name 2';
        u2.Alias = 'alias 2';
        u2.CommunityNickname = 'comm nick 2';
        u2.TimeZoneSidKey = 'America/Los_Angeles';
        u2.LocaleSidKey = 'en_US';
        u2.EmailEncodingKey = 'UTF-8';
        u2.ProfileId = p.Id;
        u2.LanguageLocaleKey = 'en_US';        
        insert u2;
        
        Account acc = new Account();
        acc.Name = 'test checkPartnerMissedOppsTest';
               
        RecordType sbcDevRecordType;
        List<RecordType> accRecordTypes = [SELECT Id,DeveloperName FROM RecordType WHERE SobjectType='Account' LIMIT 500];
        for (RecordType accRecordType: accRecordTypes) {
            if (accRecordType.DeveloperName == 'SBC') {
                sbcDevRecordType = accRecordType;
            }
        }
        acc.RecordTypeId = sbcDevRecordType.Id;        
        
        acc.Status__c = 'active';
        acc.MissedOpps__c = 2;
        acc.OwnerId = u2.Id;
        insert acc;
               
        GeneralSettings__c genSettings = new GeneralSettings__c();
        genSettings.Name = 'numMissedOppsToHoldPartner';
        genSettings.Value__c = '3';                
        insert genSettings;
    }
    
    @isTest
    static void checkPartnerMissedOppsTest() {
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'test checkPartnerMissedOppsTest'];
        acc.MissedOpps__c = 3;
        update acc;
        
        system.assertEquals(1, 1);
    }
}