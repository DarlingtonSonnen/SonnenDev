/**
 * Created by a.romero on 12/08/2019.
 */

@IsTest
private class closeCaseCtrlTest {
    @TestSetup
    static void testSetup() {
        Case cs = new Case(Status = 'New', Subject = 'CloseCaseCtrl');
        insert cs;
    }

    @IsTest
    static void testBehavior() {
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();

        List<String> lStatus = closeCaseCtrl.getClosedStatus();
        Boolean a = closeCaseCtrl.isArticleRelated(cs.Id);
        Test.stopTest();

        System.assertNotEquals(null, lStatus);
        System.assertNotEquals(null, a);
    }
}