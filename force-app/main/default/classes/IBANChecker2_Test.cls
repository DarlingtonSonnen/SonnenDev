/*
* @Author: Bartosz Jarmolinski
* Created: 28/02/2018
* The class tests IBAN Checker callout - class IBANChecker4
*/

@isTest
private class IBANChecker2_Test {

    @testSetup static void createData() {
        Account a = new Account();
        a.Name = 'Account test';
        insert a;
        //create bank data with IBAN
        List<BankData__c> bdList = new List<BankData__c>();
        BankData__c bd = new BankData__c();
        bd.Account__c = a.Id;
        bd.SepaDate__c = Date.today();
        bd.FirstName__c = 'Sample';
        bd.LastName__c = 'Customer';
        bd.IBAN__c = 'AT411100000237571500';
        bd.SWIFT__c = 'BHHDFR';
        bdList.add(bd);

        BankData__c bd1 = new BankData__c();
        bd1.Account__c = a.Id;
        bd1.SepaDate__c = Date.today();
        bd1.FirstName__c = 'Sample';
        bd1.LastName__c = 'Customer1';
        bd1.IBAN__c = 'AT411100000237571501';
        bd1.SWIFT__c = 'BHHDFR';        
        bdList.add(bd1);


        Test.startTest();
        insert bdList;
        Test.stopTest();
    }

    static testMethod void testMethod1(){  

        
        //create account

       
        //handle response
        //assert fields on the bank data record
        BankData__c newBD = [SELECT IBANCheckResult__c, BIC__c, BankName__c, IBANvalidated__c FROM BankData__c WHERE LastName__c = 'Customer'];
        
        System.assertEquals('passed', newBD.IBANCheckResult__c);
        System.assertEquals('BOFIIE2DXXX', newBD.BIC__c);
        System.assertEquals('Bank of Ireland', newBD.BankName__c);
    }

    static testMethod void  testMethod2() {

        BankData__c bd2 = new BankData__c();
        bd2.Account__c = [SELECT Id FROM Account].Id;
        bd2.SepaDate__c = Date.today();
        bd2.FirstName__c = 'Sample';
        bd2.LastName__c = 'Customer2';
        bd2.IBAN__c = 'AT411100000237571500';
        bd2.SWIFT__c = 'BHHDFR';
        
        Test.startTest();
        insert bd2;
        Test.stopTest();
        System.debug(bd2);
        
        System.assertEquals('passed', [SELECT IBANCheckResult__c FROM BankData__c WHERE Id =:bd2.Id].IBANCheckResult__c);
        System.assertEquals([SELECT IBANvalidated__c FROM BankData__c WHERE LastName__c = 'Customer'].IBANvalidated__c, [SELECT IBANvalidated__c FROM BankData__c WHERE Id =:bd2.Id].IBANvalidated__c);
    }
    static testMethod void testMethod_webservice() {

		BankData__c bd = new BankData__c();
        bd.Account__c = [SELECT Id FROM Account LIMIT 1].Id;
        bd.SepaDate__c = Date.today();
        bd.FirstName__c = 'Sample';
        bd.LastName__c = 'Customer';
        bd.IBAN__c = 'DE43553645778998';
        bd.SWIFT__c = 'BHHDFR';   
		insert bd;
        
        Test.startTest();
        String s = IBANChecker_ButtonHandler.checkIbanLightning(bd.Id);
        Test.stopTest();
        
        System.assertEquals('Success: the request to validate IBAN has been sent', s);
    }
    
    static testMethod void testMethod_invokeCheckIban() {
        
        BankData__c bd = new BankData__c();
        bd.Account__c = [SELECT Id FROM Account LIMIT 1].Id;
        bd.SepaDate__c = Date.today();
        bd.FirstName__c = 'Sample';
        bd.LastName__c = 'Customer';
        bd.IBAN__c = null;
        bd.SWIFT__c = 'BHHDFR';   
		insert bd;
        
        Test.startTest();
        String s = IBANChecker_ButtonHandler.checkIban(bd.Id);
        Test.stopTest();
    }
}