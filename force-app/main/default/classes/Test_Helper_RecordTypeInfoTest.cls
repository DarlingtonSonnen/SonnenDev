@isTest
private class Test_Helper_RecordTypeInfoTest {

   @isTest 
    private static void populateRecordTypeCache() {
       Test.startTest();
       Map<String, Map<String, Id>> rtap = Helper_RecordTypeInfo.rtInfo();
       Test.stopTest();
    } 
   
      
  @isTest 
    private static void populateRecordTypeCacheParams() {


    	RecordType rt = [SELECT Id, DeveloperName, sObjectType FROM RecordType LIMIT 1];
       Test.startTest();
       System.Assert(Helper_RecordTypeInfo.rtInfo(rt.sOBjectType,rt.DeveloperName) == rt.Id);
       Test.stopTest();
    } 
}