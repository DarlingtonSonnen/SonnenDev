/*
* Created by Bartosz Jarmolinski
* Created on 14/04/2018
* tested by DuplicateCheck_testv3
*
* * 23/11/2018 by Bartosz
* * - modifed the method findAccounts() to identify match also when only last name is the same and first names are different
*
* * 25/10/2018 by Bartosz
* 	- Added language as parameter to DuplicateCheckObject
* 	- Added language when Account / Contact is created
* * 18/10/2018 by Bartosz
*   - Change definition of initializeAccount and initializeContact methods - now accept DuplicateCheckObject as input, not String parameters
*   - Account are now created with billing, shipping addresses
*   - contacts are now created with billing addresses
*   - added method writeStreet - creates Street in the format depending on the countryCode
*   - replaced SOQL query searching for Case record type Id with method Schema.DescribeSObjectResult.getRecordTypeInfosByDeveloperName()
*   - changed API version of the class to 43.0 - in order to use the getRecordTypeInfosByDeveloperName() method
*
* * 22/08/2018 by Bartosz Jarmolinski
* 	- changed country property to ISO country code
*
* * 27/07/2018 by Bartosz Jarmolinski
* 	- replaced 'Company != null' with String.isBlank(company) in the initializeAccount method
*
* * 10/07/2018 by Bartosz Jarmolinski
*	- Added salutation and phone to wrapper class - DuplicateCheckObject
*	- Added salutation and phone to the accounts/contacts created by the DuplicateCheck
*
* * 04/07/2018 by Bartosz Jarmolinski
* 	- Added logic for creating cases when multiple matches found - dynamic values based on custom metadata types
* 	- fixed null pointer error when creating multiple match case in situation when record has not been saved yet and thus has no ID
*
* * 20/06/2018 by Bartosz Jarmolinski
* 	- line 80 - changed to String.isBlank(dco.company) in order to include empty string in the validatation. was: == null
*
* * v3 - 14/05/2018
* 	- changed return argument to Map<Id, Map<String, Id>> (from the method handleObjectsv2)
* 	- implemented search for accounts for every sObject passed to the constructor (previously only if accountId was null)
* 	- added findContracts() method in order to avoid SOQL query in the DuplicateCheck.FindBestAccountId - could potentially hit governance limit
*/


public with sharing class DuplicateCheckHandlerv3 {

	private List<Opportunity> oppList; // list of opportunities passed e.g. from trigger
	private List<Asset> assetList; // list of opportunities passed e.g. from trigger
	private List<Contact> cList; // list of contacts to insert
	private List<Account> aList; // list of accounts to link primary contact
	private Map<Id, Id> accIdMap; // return map - key value pairs of opportunity IDs passed to the class and corresponding accountIDs which were found or created
	private List<Case> caseList;
	private Map<Id, Account> oppIdAccMap; //  opportunity Id as key and account to be inserted as value
	private Map<Id, Account> accountsMap; // account Id as key, account record as value - for linking primary contacts
	private List<DuplicateCheckObject> duplicateObjectList;
	private Map<Id, Map<String, Id>> returnMap; // return map method handleObjectv2
	private List<Account> allAccounts; // all accounts found as potential matches for the sObjects in contructor

	public DuplicateCheckHandlerv3(List<Opportunity> oppList) {
		this.oppList = oppList;
		generateDuplicateCheckObject();
	}

	public DuplicateCheckHandlerv3(List<Asset> assetList)  {
		this.assetList = assetList;
		generateDuplicateCheckObject();
	}

	public List<DuplicateCheckObject> generateDuplicateCheckObject() {
		// method called by constructors - packs sObjects into wrapper DuplicateCheckObjects and creates a list of them

		duplicateObjectList = new List<DuplicateCheckObject>();

		if (oppList != NULL && !oppList.isEmpty()) {
			for (Opportunity o : oppList) {
				DuplicateCheckObject dco = new DuplicateCheckObject(o);
				duplicateObjectList.add(dco.getDuplicateCheckObject());
			}
		}

		else if (assetList != NULL && !assetList.isEmpty()) {
			for (Asset a : assetList) {
				DuplicateCheckObject dco = new DuplicateCheckObject(a);
				duplicateObjectList.add(dco.getDuplicateCheckObject());
			}
		}

		return duplicateObjectList;
	}
	public Map<Id,Map<String,Id>> handleObjectsv2() {
		// main method - needs to be called to run the ID check - the map returned here is the ultimate output of the ID check

		DuplicateCheckSetting__mdt cmt = [SELECT RecordTypeIdPersonAccount__c, RecordTypeIdBusinessAccount__c, CaseOwnerId__c, CaseOwnerIdAssets__c, CaseOwnerOpportunity__c,
				CaseRecordTypeAsset__c, CaseRecordTypeOpportunity__c, CaseStatusOpportunity__c, CaseSubject__c, CaseType__c, CaseStatusAsset__c
		FROM DuplicateCheckSetting__mdt WHERE Label = 'Account'];

		System.debug('duplicateObjectList' + duplicateObjectList);
		caseList = new List<Case>();
		oppIdAccMap =  new Map<Id, Account>();
		accountsMap = new Map<Id, Account>();
		cList = new List<Contact>();
		aList = new List<Account>();
		accIdMap = new Map<Id, Id>();
		returnMap = new Map<Id, Map<String, Id>>();

		Map<Id, List<Account>> oppAccMap = findAccounts();
		Map<Id, Integer> contractCountMap = findContracts(); // accountId as key, count of contracts per account as value

		for (DuplicateCheckObject dco : duplicateObjectList)  {

			List<Account> matchingAccounts = oppAccMap.get(dco.recId);

			if (matchingAccounts.isEmpty()) {
				// create new account
				Account a = new Account();
				if (String.isBlank(dco.company)) {
					a = initializeNewAccount(dco, cmt.RecordTypeIdPersonAccount__c);
				} else {
					a = initializeNewAccount(dco, cmt.RecordTypeIdBusinessAccount__c);
				}
				oppIdAccMap.put(dco.recId, a);

			} else if (matchingAccounts.size() == 1) {
				// one matching account found, no other action needed
				accIdMap.put(dco.recId, matchingAccounts[0].Id);
			} else {
				// multiple matches found, find the best matching one and add to the return map
				DuplicateCheck dc = new DuplicateCheck(dco);
				accIdMap.put(dco.recId, dc.FindBestAccountID(matchingAccounts, contractCountMap ));

				Case cs = new Case();

				String obj;
				// schema check recId what object it is, control statements to assign to correct field
				if (dco.recId != null) {
					if (dco.recId.getSobjectType() == Schema.Opportunity.sObjectType) {
						obj = 'Opportunity';
					} else if (dco.recId.getSobjectType() == Schema.Asset.sObjectType) {
						obj = 'Asset';
					}
				} else {
					if (oppList != null) {
						obj = 'Opportunity';
					} else if (assetList != null) {
						obj = 'Asset';
					}
				}

				if (obj == 'Opportunity') {
					cs.OpportunityName__c = dco.recId;
					cs.OwnerId = cmt.CaseOwnerOpportunity__c;
					cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(cmt.CaseRecordTypeOpportunity__c).getRecordTypeId();
					cs.Status = cmt.CaseStatusOpportunity__c;
				}
				else if (obj == 'Asset') {
					cs.AssetId = dco.recId;
					cs.OwnerId = cmt.CaseOwnerIdAssets__c;
					cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(cmt.CaseRecordTypeAsset__c).getRecordTypeId();
					cs.Status = cmt.CaseStatusAsset__c;
				}

				cs.Subject = cmt.CaseSubject__c;
				cs.AccountId = accIdMap.get(dco.recId);
				cs.Type = cmt.CaseType__c;
				cs.Description = 'The ' + obj + ' in this case has been linked with an account but there are other accounts which potentially it could be linked to. Verify if the chosen account was correct. All possible accounts matching the criteria: '+ matchingAccounts;
				caseList.add(cs);
			}
		}
		// insert cases
		if (caseList.size() > 0) {
			insert caseList;
		}
		if (oppIdAccMap.values().size() > 0) {
			insert oppIdAccMap.values();

		}

		// add ID pairs of newly created accounts to the return map
		for (Id i : oppIdAccMap.keySet()) {
			accIdMap.put(i, oppIdAccMap.get(i).Id);
			accountsMap.put(oppIdAccMap.get(i).Id, oppIdAccMap.get(i));
		}

		// create contacts for newly created business accounts
		for (DuplicateCheckObject dco : duplicateObjectList) {
			if (oppIdAccMap.containsKey(dco.recId) && oppIdAccMap.get(dco.recId).RecordTypeId == cmt.RecordTypeIdBusinessAccount__c ) {

				Id accountId = oppIdAccMap.get(dco.recId).Id;

				Contact c = initializeContact(dco, accountId);
				cList.add(c);
			}
		}
		insert cList;

		// loop through the list of inserted contacts and link them as primary contacts to their respective accounts
		for (Contact c : cList) {
			Account a = accountsMap.get(c.accountId);
			a.PrimaryContact__c = c.Id;
			aList.add(a);
		}
		update aList;

		System.debug(accIdMap);

		Map<Id, Id> accountContMap = matchContact(accIdMap);

		for (DuplicateCheckObject dco : duplicateObjectList) {
			Map<String, Id> tempMap = new Map<String, Id>();

			Id accountId = accIdMap.get(dco.recId);
			tempMap.put('Account', accountId);
			tempMap.put('Contact', accountContMap.get(accountId));
			returnMap.put(dco.recId, tempMap);
		}

		return returnMap;
	}

	private Account initializeNewAccount(DuplicateCheckObject dco, Id recordTypeId) {
		// creates account if needed (no match has been found to existing accounts)

		Account a = new Account();
		a.BillingStreet = writeStreet(dco.countryCode, dco.street, dco.streetNum, dco.addition);
		a.BillingCity = dco.city;
		a.BillingPostalCode = dco.postCode;
		a.BillingCountryCode = dco.CountryCode;
		a.BillingStateCode = dco.stateCode;
		a.RecordTypeId = recordTypeId;
		a.Phone = dco.phone;

		if (!String.isBlank(dco.shippingStreet)) {
			a.ShippingStreet = writeStreet(dco.countryCode, dco.shippingStreet, dco.shippingStreetNum, dco.shippingAddition);
		} else {
			a.ShippingStreet = a.BillingStreet;
		}
		if (!String.isBlank(dco.shippingCity)) {
			a.shippingCity = dco.shippingCity;
		} else {
			a.shippingCity = dco.city;
		}
		if (!String.isBlank(dco.shippingPostCode)) {
			a.shippingPostalCode = dco.shippingPostCode;
		} else {
			a.shippingPostalCode = dco.postCode;
		}
		if (!String.isBlank(dco.shippingCountryCode)) {
			a.shippingCountryCode = dco.shippingCountryCode;
		} else {
			a.shippingCountryCode = dco.countryCode;
		}
		if (!String.isBlank(dco.shippingStateCode)) {
			a.shippingStateCode = dco.shippingStateCode;
		} else {
			a.shippingStateCode = dco.stateCode;
		}

		if (!String.isBlank(dco.company)) {
			// business account
			a.Name = dco.company;
		} else {
			// person account
			a.FirstName = dco.firstName;
			a.LastName = dco.lastName;
			a.PersonEmail = dco.email;
			a.Salutation = dco.salutation;
			a.PersonMailingStreet = a.BillingStreet;
			a.PersonMailingCity = a.BillingCity;
			a.PersonMailingPostalCode = a.BillingPostalCode;
			a.PersonMailingCountryCode = a.BillingCountryCode;
			a.PersonMailingStateCode = a.BillingStateCode;
			a.Language__pc = dco.language;
		}
		return a;
	}


	private Contact initializeContact(DuplicateCheckObject dco, Id accountId) {
		// creates contact for new created business account

		Contact c = new Contact();
		c.Salutation = dco.salutation;
		c.FirstName = dco.firstName;
		c.LastName = dco.lastName;
		c.Email = dco.email;
		c.AccountId = accountId;
		c.Phone = dco.phone;
		c.Language__c = dco.language;

		c.MailingCountryCode = dco.countryCode;
		c.MailingCity = dco.city;
		c.MailingStreet = writeStreet(dco.countryCode, dco.street, dco.streetNum, dco.addition);
		c.MailingPostalCode = dco.postCode;
		c.MailingStateCode = dco.stateCode;

		return c;
	}

	private String writeStreet(String country, String str, String streetNum, String streetAdd) {
		// the method returns street in the country specific format concatenated with street number and possibly an addition
		String street = str;

		// check if the street contains number, if so do not concatenate the number any more
		Pattern p = Pattern.compile('[^0-9]');
		String numericOutput = p.matcher(street).replaceAll('');

		if (!String.isBlank(numericOutput)) {
			// if the street contains the number, return the street with no further processing
			return street;
		} else {
			// if there is no number in the street string, concatenate numbers respectively, depending on country.
			if (country == 'AU' || country == 'US' || country == 'GB') {
				if (!String.isBlank(streetNum)) {
					street = streetNum + ' ' + street;
				}
				if (!String.isBlank(streetAdd)) {
					street = street + ' ' + streetAdd;
				}
			} else if (country == 'DE' || country == 'AT' || country == 'IT' || country == 'CH') {
				if (!String.isBlank(streetNum)) {
					street = street + ' ' + streetNum;
				}
				if (!String.isBlank(streetAdd)) {
					street = street + ' ' + streetAdd;
				}
			} else {
				if (!String.isBlank(streetNum)) {
					street = street + ' ' + streetNum;
				}
				if (!String.isBlank(streetAdd)) {
					street = street + ' ' + streetAdd;
				}
			}
		}
		return street;
	}

	private Map<Id, List<Account>> findAccounts() {
		// the method searches for accounts and returns a map of sObject recordId (opportunity or asset) and the list of matching accounts

		Set<String> names = new Set<String>(); // set of all names to query accounts against
		Set<String> cities = new Set<String>();
		Set<String> postalCodes = new Set<String>();
		Set<String> emails = new Set<String>();
		Map<Id, List<Account>> idAccountMap = new Map<Id, List<Account>>(); // the return map - record Id as key, list of potential matching accounts as value

		for (DuplicateCheckObject dco : duplicateObjectList) {

			if (dco.city != NULL) {
				cities.add(dco.city);
			}
			//if (dco.company != NULL) {
			if (!String.isBlank(dco.company)) {
				names.add(dco.company);
			} else if (dco.firstName != NULL && dco.lastName != NULL) {
				String name = dco.firstName + ' ' + dco.lastName;
				names.add(name);
				names.add(dco.lastName); // adding last name as well to find account where only last name is the same
			}
			if (dco.postCode != NULL) {
				postalCodes.add(dco.postCode);
			}
			if (dco.email != NULL) {
				emails.add(dco.email);
			}
		}

        System.debug(names);


		// account id as key, set of contact emails belonging to the account as value
		Map<Id, Set<String>> emailsMap = new Map<Id, Set<String>>();

		// query contacts for their account names - in order to handle situation where company name is NULL but contact belongs to a business account (thus its account name is different than the contact name)
		List<Contact> contactList = [SELECT Account.Name, Name FROM Contact WHERE Name IN :names];
		Map<String, String> contactAccMap = new Map<String, String>();

		for (Contact c : contactList) {
			contactAccMap.put(c.Name, c.Account.Name);
			names.add(c.Account.Name);
		}

		List<Account> potentialMatch = [SELECT Id, Name, BillingStreet, BillingPostalCode, BillingCity, LastName,
										(SELECT AccountId, Name, Email FROM Contacts WHERE Email IN :emails)
										FROM Account WHERE (Name IN:names OR (LastName != null AND LastName IN:names))
                                        AND (BillingCity IN :cities OR BillingPostalCode IN :postalCodes)
										AND Id IN (SELECT AccountId FROM Contact WHERE Email IN :emails)];
        System.debug(potentialMatch);
		this.allAccounts = potentialMatch; // assign all accounts to the variable allAccounts - it is used to look for accounts in contracts
		// create map of account id and set of contact email under that account
		for (Account a : potentialMatch) {
			Set<String> cntsSet = new Set<String>(); // set of contact emails belonging to the account
			List<Contact> cntsList = a.Contacts;

			for (Contact c : cntsList) {
				cntsSet.add(c.Email);
			}
			emailsMap.put(a.Id, cntsSet);
		}

		for (DuplicateCheckObject dco : duplicateObjectList) {
			List<Account> newList = new List<Account>();

			for (Account a : potentialMatch) {

				String personName = dco.firstName + ' ' + dco.lastName;

//				if ((a.Name == dco.company || a.Name == personName || a.Name == contactAccMap.get(personName)) &&
//						(a.BillingCity == dco.city || a.BillingPostalCode == dco.postCode) &&
//						emailsMap.get(a.Id).contains(dco.email.toLowerCase())) {

				if ((a.Name == dco.company || (a.LastName != null && a.LastName == dco.lastName) || a.Name == contactAccMap.get(personName)) &&
						(a.BillingCity == dco.city || a.BillingPostalCode == dco.postCode) &&
						emailsMap.get(a.Id).contains(dco.email.toLowerCase())) {

					newList.add(a);
				}
			}
			idAccountMap.put(dco.recId, newList);
		}

		return idAccountMap;
	}
	private Map<Id, Id> matchContact(Map<Id, Id> accIdMap) {
		// the method receives map of sObject Id (passed to the constructor) as key and AccountId as value. It returns accountId as key and contactId as value

		Map<Id, Id> aIdcId = new Map<Id, Id>(); // return map, account Id as key, contact Id as value

		// create pairs of dco email and the account
		Map<Id, String> accIdEmail = new Map<Id, String>();
		Map<Id, DuplicateCheckObject> dcoMap = new Map<Id, DuplicateCheckObject>(); // account id as key, dco as value
		for (DuplicateCheckObject dco : duplicateObjectList) {
			accIdEmail.put(accIdMap.get(dco.recId), dco.email);
			dcoMap.put(accIdMap.get(dco.recId), dco);
		}

		List<Contact> contactList = [SELECT Id, AccountId, Email FROM Contact WHERE AccountId IN :accIdMap.values()];
		for (Contact c : contactList) {
			if (accIdEmail.get(c.AccountId) == c.Email) {
				aIdcId.put(c.AccountId, c.Id);
			}
		}
		for (Id i : accIdMap.values()) {
			if (!aIdcId.keySet().contains(i)) {
				initializeContact(dcoMap.get(i), i);
			}
		}
		return aIdcId;
	}
	private Map<Id, Integer> findContracts() {
		// return map of account ID and count of contracts - existance of contract is an indicator that account may be the best match

		Map<Id, Integer> contractNumMap = new Map<Id, Integer>();
		Set<Id> accountIds = new Set<Id>();
		for (Account a : allAccounts) {
			accountIds.add(a.Id);
		}
		List<AggregateResult> contractNum = [SELECT AccountId, count(Id) num FROM Contract WHERE AccountId IN:accountIds GROUP BY AccountId ];
		for (AggregateResult ar : contractNum) {
			contractNumMap.put((Id) ar.get('AccountId'), (Integer) ar.get('num'));
		}
		return contractNumMap;
	}
}