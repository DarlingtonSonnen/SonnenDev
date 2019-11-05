/**
 * @author Polina Drobot <polina.drobot@codeswat.com>
 * @version 1.0.0 - 2017-08-18
 */
@isTest
private class AccountChangeRecordTypeCtrlTest {

	@isTest 
	static void testPersonAmbassador() {
		String accountName = AccountChangeRecordTypeCtrl.ACCOUNT;

		String rtName = AccountChangeRecordTypeCtrl.RT_PERSON_AMBASSADOR;
		String invRtName = AccountChangeRecordTypeCtrl.RT_AMBASSADOR;

		Id rtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :rtName].Id;
		Id invRtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :invRtName].Id;

		Account a = new Account(LastName = 'Test ' + rtName, RecordTypeId = rtId);
		insert a;

		AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);

		a = [SELECT Id, RecordTypeId FROM Account WHERE Id = :a.Id];

		System.assertEquals(a.RecordTypeId, invRtId);
	}

	@isTest 
	static void testAmbassador() {
		String accountName = AccountChangeRecordTypeCtrl.ACCOUNT;

		String rtName = AccountChangeRecordTypeCtrl.RT_AMBASSADOR;
		String invRtName = AccountChangeRecordTypeCtrl.RT_PERSON_AMBASSADOR;

		Id rtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :rtName].Id;
		Id invRtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :invRtName].Id;

		Account a = new Account(Name = 'Test ' + rtName, RecordTypeId = rtId);
		insert a;

		Contact c = new Contact(LastName = 'Test ' + rtName, AccountId = a.Id);
		insert c;

		AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);

		a = [SELECT Id, RecordTypeId FROM Account WHERE Id = :a.Id];

		System.assertEquals(a.RecordTypeId, invRtId);
	}

	@isTest 
	static void testPrivate() {
		String accountName = AccountChangeRecordTypeCtrl.ACCOUNT;

		String rtName = AccountChangeRecordTypeCtrl.RT_PRIVATE;
		String invRtName = AccountChangeRecordTypeCtrl.RT_BUSINESS_ACCOUNT;

		Id rtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :rtName].Id;
		Id invRtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :invRtName].Id;

		Account a = new Account(LastName = 'Test ' + rtName, RecordTypeId = rtId);
		insert a;

		AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);

		a = [SELECT Id, RecordTypeId FROM Account WHERE Id = :a.Id];

		System.assertEquals(a.RecordTypeId, invRtId);
	}

	@isTest 
	static void testBusinessAccount() {
		String accountName = AccountChangeRecordTypeCtrl.ACCOUNT;

		String rtName = AccountChangeRecordTypeCtrl.RT_BUSINESS_ACCOUNT;
		String invRtName = AccountChangeRecordTypeCtrl.RT_PRIVATE;

		Id rtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :rtName].Id;
		Id invRtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :invRtName].Id;

		Account a = new Account(Name = 'Test ' + rtName, RecordTypeId = rtId);
		insert a;
		
		Contact c = new Contact(LastName = 'Test ' + rtName, AccountId = a.Id);
		insert c;

		AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);

		a = [SELECT Id, RecordTypeId FROM Account WHERE Id = :a.Id];

		System.assertEquals(a.RecordTypeId, invRtId);
	}

	@isTest 
	static void testBusinessAccountErrors() {
		String accountName = AccountChangeRecordTypeCtrl.ACCOUNT;

		String rtName = AccountChangeRecordTypeCtrl.RT_BUSINESS_ACCOUNT;
		String invRtName = AccountChangeRecordTypeCtrl.RT_PRIVATE;

		Id rtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :rtName].Id;
		Id invRtId = [SELECT Id FROM RecordType WHERE SobjectType = :accountName AND DeveloperName = :invRtName].Id;

		Account a = new Account(Name = 'Test ' + rtName, RecordTypeId = rtId);
		insert a;
		
		AuraHandledException ahe = null;

		// test CONTACTS_NUM_MSG
		try {
			AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);
		} catch(AuraHandledException e) {
			ahe = e;
		}
		System.assertNotEquals(null, ahe);
		ahe = null;


		// test REPORT_TO_EXISTS_MSG
		Account tmpA = new Account(Name = 'Tmp', RecordTypeId = rtId);
		insert tmpA;
		Contact tmpC = new Contact(LastName = 'Tmp ', AccountId = tmpA.Id);
		insert tmpC;
		Contact c = new Contact(LastName = 'Test ' + rtName, AccountId = a.Id, ReportsToId = tmpC.Id);
		insert c;

		try {
			AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);
		} catch(AuraHandledException e) {
			ahe = e;
		}
		System.assertNotEquals(null, ahe);
		ahe = null;
		c.ReportsToId = null;
		update c;


		// test PARENT_EXISTS_MSG
		a.ParentId = tmpA.Id;
		update a;

		try {
			AccountChangeRecordTypeCtrl.changeRTFromBusinessToPrivate(a.Id);
		} catch(AuraHandledException e) {
			ahe = e;
		}
		System.assertNotEquals(null, ahe);
		ahe = null;
	}
}