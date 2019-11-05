/*
 * Created by Bartosz Jarmolinski
 * The test covers DuplicateCheckHandlerv3, DuplicateCheck, DuplicateCheckObject classes
*/ 

@isTest
private class DuplicateCheck_testv3 {

	@testSetup static void createTestData() {
		//create accounts
		DuplicateCheckSetting__mdt cmt = [SELECT RecordTypeIdPersonAccount__c, RecordTypeIdBusinessAccount__c FROM DuplicateCheckSetting__mdt WHERE Label = 'Account'];
		List<Account> accounts = new List<Account>();
		
		// one match scenario
		Account a = new Account();
		a.Name = 'oneMatchingBusinessAccount';
		a.BillingStreet = 'Zossener strasse 56';
		a.BillingCity = 'Berlin';
		a.BillingPostalCode = '10961';
		a.BillingCountryCode = 'DE';
		a.RecordTypeId = cmt.RecordTypeIdBusinessAccount__c;
		accounts.add(a);

		Account a1 = new Account();
		a1.FirstName = 'OneMatching';
		a1.LastName = 'PrivateAccount';
		a1.PersonEmail = 'oneMatching@account.com';
		a1.BillingStreet = 'Nalepa Strasse 56';
		a1.BillingCity = 'Berlin';
		a1.BillingPostalCode = '12459';
		a1.BillingCountryCode = 'DE';
		a1.RecordTypeId = cmt.RecordTypeIdPersonAccount__c;
		accounts.add(a1);

		// multiple matches scenario, one has contract
		Account a5 = new Account();
		a5.FirstName = 'Multiple';
		a5.LastName = 'Match2';
		a5.PersonEmail = 'multipleMatching2@account.com';
		a5.BillingStreet = 'Erich-Weinert-Str. 133';
		a5.BillingCity = 'Berlin';
		a5.BillingPostalCode = '10245';
		a5.BillingCountryCode = 'DE';
		a5.RecordTypeId = cmt.RecordTypeIdPersonAccount__c;
		accounts.add(a5);

			// add contract to the account
		Account a6 = new Account();
		a6.FirstName = 'Multiple';
		a6.LastName = 'Match2';
		a6.PersonEmail = 'multipleMatching2@account.com';
		a6.BillingStreet = '';
		a6.BillingCity = 'Berlin';
		a6.BillingPostalCode = '10245';
		a6.BillingCountryCode = 'DE';
		a6.RecordTypeId = cmt.RecordTypeIdPersonAccount__c;
		accounts.add(a6);						

		// multiple matches scenario none has contract
		Account a2 = new Account();
		a2.Name = 'Multiple Match';
		a2.BillingStreet = 'Stralauer Allee 4';
		a2.BillingCity = 'Berlin';
		a2.BillingPostalCode = '10245';
		a2.BillingCountryCode = 'DE';
		a2.RecordTypeId = cmt.RecordTypeIdBusinessAccount__c;
		accounts.add(a2);

		Account a3 = new Account();
		a3.Name = 'Multiple Match';
		a3.BillingStreet = 'Stralauer Al. 4';
		a3.BillingCity = 'Berlin';
		a3.BillingPostalCode = '10245';
		a3.BillingCountryCode = 'DE';
		a3.RecordTypeId = cmt.RecordTypeIdBusinessAccount__c;
		accounts.add(a3);

		Account a4 = new Account();
		a4.FirstName = 'Multiple';
		a4.LastName = 'Match';
		a4.PersonEmail = 'multipleMatching@account.com';
		a4.BillingStreet = 'Stralauer Strasse 4';
		a4.BillingCity = 'Berlin';
		a4.BillingPostalCode = '10245';
		a4.BillingCountryCode = 'DE';
		a4.RecordTypeId = cmt.RecordTypeIdPersonAccount__c;
		accounts.add(a4);		

		insert accounts;

		// insert contacts
		List<Contact> contacts = new List<Contact>();
		Contact c = new Contact();
		c.FirstName = 'User';
		c.LastName = 'One';
		c.Email = 'oneUser@sonnen.de';
		c.AccountId = [SELECT Id FROM Account WHERE Name = 'oneMatchingBusinessAccount'].Id;
		contacts.add(c);

		Contact c2 = new Contact();
		c2.FirstName = 'Multiple';
		c2.LastName = 'Match';
		c2.Email = 'multipleMatching@account.com';
		c2.AccountId = [SELECT Id FROM Account WHERE Name = 'Multiple Match' AND BillingStreet = 'Stralauer Allee 4'].Id;
		contacts.add(c2);

		Contact c3 = new Contact();
		c3.FirstName = 'Multiple';
		c3.LastName = 'Match';
		c3.Email = 'multipleMatching@account.com';
		c3.AccountId = [SELECT Id FROM Account WHERE Name = 'Multiple Match' AND BillingStreet = 'Stralauer Al. 4'].Id;		
		contacts.add(c3);

		insert contacts;
		// create list of opportunities
		Contract ct = new Contract();
		ct.AccountId = [SELECT Id FROM Account WHERE Name = 'Multiple Match2' AND BillingStreet = ''].Id;
		ct.Type__c = 'sonnenbatterieHome-DE';
		ct.StartDate = Date.today();
		ct.Status = 'Draft';
		insert ct;

		// group 1. with company__c filled in
		// group2. company__c not filled in 
	}
	
	@isTest static void testOpportunities() {
		// scenario 1
		// opportunity matches only one account - Company = account name, email = contact email, postal code, city
		List<Opportunity> opportunities = new List<Opportunity>();

		Opportunity o = new Opportunity();
		o.Name = 'Opp scenario 1';
		o.StageName = 'Open';
		o.CloseDate = Date.today().addDays(14);
		o.Company__c = 'oneMatchingBusinessAccount';
		o.Country__c = 'Germany';
		o.BillingCountryIsoCode__c = 'DE';
		o.FirstName__c = 'User';
		o.LastName__c = 'One';
		o.BillingStreet__c = '';
		o.BillingPostalCode__c = '10961';
		o.BillingCity__c = 'Berlin';
		o.Email__c = 'oneUser@sonnen.de';
		opportunities.add(o);

		// scenario 2
		// opportunity matches only one private account = first + last name = account name, email = PersonEmail, postal code, city
		Opportunity o1 = new Opportunity();
		o1.Name = 'Opp scenario 2';
		o1.StageName = 'Open';
		o1.CloseDate = Date.today().addDays(14);
		o1.Company__c = NULL;
		o1.FirstName__c = 'OneMatching';
		o1.LastName__c = 'PrivateAccount';
		o1.Country__c = 'Germany';
		o1.BillingCountryIsoCode__c = 'DE';
		o1.BillingStreet__c = '';
		o1.BillingPostalCode__c = '12459';
		o1.BillingCity__c = 'Berlin';
		o1.Email__c = 'oneMatching@account.com';
		opportunities.add(o1);		

		// scenario 3
		// opportunity matches multiple accounts - one with contract - check if the one with contract was chosen
		Opportunity o6 = new Opportunity();
		o6.Name = 'Opp scenario 3';
		o6.StageName = 'Open';
		o6.CloseDate = Date.today().addDays(14);
		o6.FirstName__c = 'Multiple';
		o6.LastName__c = 'Match2';
		o6.Company__c = NULL;
		o6.Country__c = 'Germany';
		o6.BillingCountryIsoCode__c = 'DE';
		o6.BillingStreet__c = 'Erich-Weinert-Str 133';
		o6.BillingPostalCode__c = '10409';
		o6.BillingCity__c = 'Berlin';
		o6.Email__c = 'multipleMatching2@account.com';
		opportunities.add(o6);			

		// scenario 4
		//  opportunity matches multiple accounts, none has contract - each has different street - verify that the one with the most matching street has been recommended
		Opportunity o2 = new Opportunity();
		o2.Name = 'Opp scenario 4';
		o2.StageName = 'Open';
		o2.CloseDate = Date.today().addDays(14);
		o2.FirstName__c = 'Multiple';
		o2.LastName__c = 'Match';
		o2.Company__c = NULL;
		o2.Country__c = 'Germany';
		o2.BillingCountryIsoCode__c = 'DE';
		o2.BillingStreet__c = 'Stralauer Allee';
        o2.BillingStreetNo__c = '4';
		o2.BillingPostalCode__c = '10245';
		o2.BillingCity__c = 'Berlin';
		o2.Email__c = 'multipleMatching@account.com';
		opportunities.add(o2);

		// scenario 5
		// opportunity does not match any account - company__c is filled in, verify that business account got created
		Opportunity oNew = new Opportunity();
		oNew.Name = 'Opp scenario 5';
		oNew.StageName = 'Open';
		oNew.CloseDate = Date.today().addDays(14);
		oNew.FirstName__c = 'New';
		oNew.LastName__c = 'Contact';
		oNew.Company__c = 'Unknown yet company';
		oNew.Country__c = 'Germany';
		oNew.Language__c = 'de';
		oNew.BillingCountryIsoCode__c = 'DE';
		oNew.BillingStreet__c = 'Schuetzenstr. 70';
		oNew.BillingPostalCode__c = '10117';
		oNew.BillingCity__c = 'Berlin';
		oNew.Email__c = 'new@sonnen.de';
		opportunities.add(oNew);		

		// scenario 6
		// opportunity does not match any account - company__c is null, verify that person account has been created. 
		Opportunity oNew2 = new Opportunity();
		oNew2.Name = 'Opp scenario 6';
		oNew2.StageName = 'Open';
		oNew2.CloseDate = Date.today().addDays(14);
		oNew2.FirstName__c = 'Another';
		oNew2.LastName__c = 'Cont';
		oNew2.Company__c = NULL;
		oNew2.Country__c = 'Germany';
		oNew2.BillingCountryIsoCode__c = 'DE';
		oNew2.BillingStreet__c = 'Am Riedbach';
        oNew2.BillingStreetNo__c = '1';
		oNew2.BillingPostalCode__c = '87499';
		oNew2.BillingCity__c = 'Wildpoldsried';
		oNew2.Email__c = 'new@sonnenbatterie.de';
		opportunities.add(oNew2);	

		//scenrario 7
		//insert 101 opportunties with no match - verify that test will not fail due to limits
		List<Opportunity> bulkOpps = new List<Opportunity>();
		for (Integer i=0; i < 101; i++) {
			Opportunity ob = new Opportunity();
			ob.Name = 'Opp scenario 7_' + i;
			ob.StageName = 'Open';
			ob.CloseDate = Date.today().addDays(14);
			ob.FirstName__c = 'name' + i;
			ob.LastName__c = 'lastname' +i;
			ob.Email__c = 'name'+i +'@example.com';
			ob.Country__c = 'Germany';
			ob.BillingCountryIsoCode__c = 'DE';
			ob.BillingStreet__c = 'WhateverStreet' + i;
			ob.BillingPostalCode__c = '00001';
			ob.BillingCity__c = 'Wipo';
			opportunities.add(ob);
		}

		insert opportunities;
		Test.startTest();
		DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(opportunities);
		//Map<Id, Id> oppAccId = dch.handleOpportunities();
		Map<Id, Map<String, Id>> oppAccId = dch.handleObjectsv2();
		System.debug('oppAccId: '+oppAccId);
		for(Opportunity oi : opportunities) {
			System.debug(oi);
            Map<String,Id> returnMap = oppAccId.get(oi.Id);
			oi.AccountId = returnMap.get('Account');
			System.debug(oi.Id);
			System.debug(oi.AccountId);
		}

		update opportunities;
		Test.stopTest();

		// scenario 1
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 1'].AccountId, [SELECT Id FROM Account WHERE Name = 'oneMatchingBusinessAccount'].Id);
		// scenario 2
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 2'].AccountId, [SELECT Id FROM Account WHERE PersonEmail = 'oneMatching@account.com'].Id);
		//scenario 3
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 3'].AccountId, [SELECT Id FROM Account WHERE Name = 'Multiple Match2' AND BillingStreet = NULL].Id);
		// scenario 4
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 4'].AccountId, [SELECT Id FROM Account WHERE Name = 'Multiple Match' AND BillingStreet = 'Stralauer Allee 4'].Id);
		//scenario 5
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 5'].AccountId, [SELECT Id FROM Account WHERE Name = 'Unknown yet company'].Id);
		// scenario 6
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 6'].AccountId, [SELECT Id FROM Account WHERE Name = 'Another Cont'].Id);
		// scenario 7
		System.assertEquals(0, [SELECT Id FROM Opportunity WHERE AccountId = NULL].size());

	}
	
	@isTest static void testAssets() {
		
		Contact c = new Contact();
		c.FirstName = 'Temporary';
		c.LastName = 'contacts';
		c.AccountId = [SELECT Id FROM Account WHERE Name = 'oneMatchingBusinessAccount'].Id;
		insert c;

		List<Asset> assets = new List<Asset>();

		// scenario 1
		Asset a = new Asset();
		a.Name = 'Asset scenario 1';
		a.INClientCountry__c = 'Deutschland';
		a.Country__c = 'DE';
		a.INClientFirstName__c = 'User';
		a.INClientLastName__c = 'One';
		a.INClientStreet__c = '';
		a.INClientZIPCode__c = '10961';
		a.INClientCity__c = 'Berlin';
		a.INClientEmail__c = 'oneuser@sonnen.de';
		a.ContactId = c.Id;
		assets.add(a);

		// scenario 2
		// asset matches only one private account = first + last name = account name, email = PersonEmail, postal code, city

		Asset a1 = new Asset();
		a1.Name = 'Asset scenario 2';
		a1.INClientCountry__c = 'Germany';
		a1.Country__c = 'DE';
		a1.INClientFirstName__c = 'OneMatching';
		a1.INClientLastName__c = 'PrivateAccount';
		a1.INClientStreet__c = '';
		a1.INClientZIPCode__c = '12459';
		a1.INClientCity__c = 'Berlin';
		a1.INClientEmail__c = 'oneMatching@account.com';
		a1.ContactId = c.Id;
		assets.add(a1);

		// scenario 3
		// asset matches multiple accounts - one with contract - check if the one with contract was chosen
		Asset a6 = new Asset();
		a6.INClientCountry__c = 'Germany';
		a6.Country__c = 'DE';
		a6.INClientFirstName__c = 'Multiple';
		a6.INClientLastName__c = 'Match2';
		a6.INClientStreet__c = 'Erich-Weinert-Str 133';
		a6.INClientZIPCode__c = '10409';
		a6.INClientCity__c = 'Berlin';
		a6.INClientEmail__c = 'multipleMatching2@account.com';
		a6.Name = 'Asset scenario 3';
		a6.ContactId = c.Id;
		assets.add(a6);		
		
		// scenario 4
		//  opportunity matches multiple accounts, none has contract - each has different street - verify that the one with the most matching street has been recommended
		Asset a2 = new Asset();
		a2.INClientCountry__c = 'Germany';
		a2.Country__c = 'DE';
		a2.INClientFirstName__c = 'Multiple';
		a2.INClientLastName__c = 'Match';
		a2.INClientStreet__c = 'Stralauer Allee 4';
		a2.INClientZIPCode__c = '10245';
		a2.INClientCity__c = 'Berlin';
		a2.INClientEmail__c = 'multipleMatching@account.com';
		a2.Name = 'Asset scenario 4';
		a2.ContactId = c.Id;
		assets.add(a2);	

		// scenario 5
		// asset does not match any account - company__c is filled in, verify that business account got created
		Asset aNew = new Asset();
		aNew.INClientCountry__c = 'Germany';
		aNew.Country__c = 'DE';
		aNew.INClientFirstName__c = 'New';
		aNew.INClientLastName__c = 'Contact';
		aNew.INClientStreet__c = 'Schuetzenstr. 70';
		aNew.INClientZIPCode__c = '10117';
		aNew.INClientCity__c = 'Berlin';
		aNew.INClientEmail__c = 'new@sonnen.de';
		aNew.Name = 'Asset scenario 5';
		aNew.ContactId = c.Id;
		assets.add(aNew);	

		// scenario 6
		// asset does not match any account - company__c is null, verify that person account has been created. 
		Asset aNew2 = new Asset();
		aNew2.INClientCountry__c = 'Germany';
		aNew2.Country__c = 'DE';
		aNew2.INClientFirstName__c = 'Another';
		aNew2.INClientLastName__c = 'Cont';
		aNew2.INClientStreet__c = 'Am Riedbach 1';
		aNew2.INClientZIPCode__c = '87499';
        aNew2.INClientLanguage__c = 'de';
		aNew2.INClientCity__c = 'Wildpoldsried';
		aNew2.INClientEmail__c = 'new@sonnenbatterie.de';
		aNew2.Name = 'Asset scenario 6';
		aNew2.ContactId = c.Id;
		assets.add(aNew2);
        
		insert assets;

		Test.startTest();
		DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(assets);
		Map<Id, Map<String, Id>> assetAccId = dch.handleObjectsv2();

		for(Asset oi : assets) {
            Map<String, Id> returnMap = assetAccId.get(oi.Id);
			oi.AccountId = returnMap.get('Account');
		}
		update assets;
		Test.stopTest();		
		
		// add assertions

		// scenario 1
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 1'].AccountId, [SELECT Id FROM Account WHERE Name = 'oneMatchingBusinessAccount'].Id);
		// scenario 2
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 2'].AccountId, [SELECT Id FROM Account WHERE PersonEmail = 'oneMatching@account.com'].Id);
		//scenario 3
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 3'].AccountId, [SELECT Id FROM Account WHERE Name = 'Multiple Match2' AND BillingStreet = NULL].Id);
		// scenario 4        
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 4'].AccountId, [SELECT Id FROM Account WHERE Name = 'Multiple Match' AND BillingStreet = 'Stralauer Allee 4'].Id);
		//scenario 5
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 5'].AccountId, [SELECT Id FROM Account WHERE Name = 'New Contact'].Id);
		// scenario 6
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 6'].AccountId, [SELECT Id FROM Account WHERE Name = 'Another Cont'].Id);
		// scenario 7
		System.assertEquals(0, [SELECT Id FROM Asset WHERE AccountId = NULL].size());

	}
    
    @isTest static void uncommitedOpportunity() {        
        // scenario when Opportunity is not saved, thus has no recordId - exists only in the execution context
        // happens if a record is created and ID/Duplicate Check is used for generating accountID and/or contactId
        
        List<Opportunity> opportunities = new List<Opportunity>();
       	Opportunity o2 = new Opportunity();
		o2.Name = 'Opp scenario 4';
		o2.StageName = 'Open';
		o2.CloseDate = Date.today().addDays(14);
		o2.FirstName__c = 'Multiple';
		o2.LastName__c = 'Match';
		o2.Company__c = NULL;
		o2.Country__c = 'Germany';
		o2.BillingCountryIsoCode__c = 'DE';
		o2.BillingStreet__c = 'Stralauer Allee 4';
		o2.BillingPostalCode__c = '10245';
		o2.BillingCity__c = 'Berlin';
		o2.Email__c = 'multipleMatching@account.com';
        opportunities.add(o2);
        
		Test.startTest();
		DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(opportunities);

		Map<Id, Map<String, Id>> oppAccId = dch.handleObjectsv2();
		System.debug('oppAccId: '+oppAccId);
		for(Opportunity oi : opportunities) {
			System.debug(oi);
            Map<String,Id> returnMap = oppAccId.get(oi.Id);
			oi.AccountId = returnMap.get('Account');
			System.debug(oi.Id);
			System.debug(oi.AccountId);
		}

		upsert opportunities;
		Test.stopTest();
        
		// scenario 4
		System.assertEquals([SELECT AccountId FROM Opportunity WHERE Name = 'Opp scenario 4'].AccountId, [SELECT Id FROM Account WHERE Name = 'Multiple Match' AND BillingStreet = 'Stralauer Allee 4'].Id);
       	// verify that case has been created
       	System.assertEquals(1, [SELECT Id FROM Case ].size());
    } 
    @isTest static void uncommitedAsset() {
        // scenario when asset is not saved, thus has no recordId - is the only record in the execution context
        // happens if a record is created and ID/Duplicate Check is used for generating accountID and/or contactId

        List<Asset> assets = new List<Asset>();
		Asset a2 = new Asset();
		a2.INClientCountry__c = 'Germany';
		a2.Country__c = 'DE';
		a2.INClientFirstName__c = 'Multiple';
		a2.INClientLastName__c = 'Match';
		a2.INClientStreet__c = 'Stralauer Allee 4';
		a2.INClientZIPCode__c = '10245';
		a2.INClientCity__c = 'Berlin';
		a2.INClientEmail__c = 'multipleMatching@account.com';
		a2.Name = 'Asset scenario 4';
		a2.ContactId = null;
        a2.AccountId = null;
		assets.add(a2);
        
        Test.startTest();
		DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(assets);
		Map<Id, Map<String, Id>> assetAccId = dch.handleObjectsv2();

		for(Asset oi : assets) {
            Map<String, Id> returnMap = assetAccId.get(oi.Id);
			oi.AccountId = returnMap.get('Account');
		}
		upsert assets;
		Test.stopTest();
        
        // scenario 4        
		System.assertEquals([SELECT AccountId FROM Asset WHERE Name = 'Asset scenario 4'].AccountId, [SELECT Id FROM Account WHERE Name = 'Multiple Match' AND BillingStreet = 'Stralauer Allee 4'].Id);
    	// verify that case has been created
    	System.assertEquals(1, [SELECT Id FROM Case ].size());
    }
}