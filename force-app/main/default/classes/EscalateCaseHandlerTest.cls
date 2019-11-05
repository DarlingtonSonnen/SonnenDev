/**
 * Created by m.muchow on 29.08.2019.
 */

@IsTest
private class EscalateCaseHandlerTest {
    @TestSetup
    static void testSetup() {
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;

        User newUser = new User(Alias = 'test123', Email = 'test@test123.test123', EmailEncodingKey = 'UTF-8', FirstName = 'Test', LastName = 'User', LanguageLocaleKey='en_US', ProfileId = profileId, Username='test@test123.test123', TimeZoneSidKey = 'Europe/Berlin', LocaleSidKey = 'de_DE');
        insert newUser;
    }

    @IsTest
    static void userNoPermission() {
        Id userId = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User' LIMIT 1].Id;

        Test.startTest();
        Boolean getUserPermission = EscalateCaseController.getUserPermission(userId);
        Test.stopTest();

        System.assertEquals(false, getUserPermission);
    }
}