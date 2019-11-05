/*
    UPDATES:
    * 12/11/2018 - added 'AND Pricebook2.Name = 'Sonnen Sales DE' to assertions in the test methods two and three

 */


@isTest
private class Wirtschaftlichkeitsrechner_test {
    	@testSetup static void createData() {
		
		List<Account> accounts = new List<Account>();
		List<Contact> contacts = new List<Contact>();

		Account customer = new Account();
		customer.Name = 'Customer account';
		customer.RecordTypeId = [SELECT Id FROM RecordType WHERE Name LIKE 'Business Customer' AND sObjectType = 'Account' LIMIT 1].Id;
		customer.BillingStreet = 'ZossenerStr. 56';
		customer.BillingCity = 'Berlin';
		customer.BillingPostalCode = '10245';
		customer.BillingCountryCode = 'DE';		
		customer.PrimaryContact__c = null;
		accounts.add(customer);

		Account partner = new Account();
		partner.Name = 'Partner account';
		partner.RecordTypeId = [SELECT Id FROM RecordType WHERE Name LIKE 'Partner' AND sObjectType = 'Account' LIMIT 1].Id;
		partner.BillingStreet = 'ZossenerStr. 56';
		partner.BillingCity = 'Berlin';
		partner.BillingPostalCode = '10245';
		partner.BillingCountryCode = 'DE';	
		partner.Status__c = 'active';	
		partner.PrimaryContact__c = null;
        partner.InterestinLeadimport__c = true;
		accounts.add(partner);
		insert accounts;

		Contact c1 = new Contact();
		c1.LastName = 'Customer';
		c1.RecordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Standard' AND sObjectType = 'Contact' LIMIT 1].Id;
		c1.AccountId = customer.Id;
		c1.MailingStreet = 'ZossenerStr. 56';
		c1.MailingCity = 'Berlin';
		c1.MailingPostalCode = '10245';
		c1.MailingCountryCode = 'DE';
		contacts.add(c1);

		Contact c2 = new Contact();
		c2.LastName = 'Partner';
		c2.RecordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Technician' AND sObjectType = 'Contact' LIMIT 1].Id;
		c2.AccountId = partner.Id;
		c2.MailingStreet = 'ZossenerStr. 56';
		c2.MailingCity = 'Berlin';
		c2.MailingPostalCode = '10245';
		c2.MailingCountryCode = 'DE';		
		contacts.add(c2);
		insert contacts;

		customer.PrimaryContact__c = c1.Id;
		partner.PrimaryContact__c = c2.Id;
		update accounts;

		System.debug(accounts);
		System.debug(contacts);
		System.debug([SELECT Id, (SELECT Id FROM Contacts ORDER BY CreatedDate LIMIT 1) FROM Account]);

		Opportunity opp = new Opportunity();
		opp.Name = 'New Opp from WR';
		opp.CloseDate = Date.today().addMonths(2);
		opp.StageName = 'New';
		opp.ProposedSBC__c = partner.Id;
		opp.PrimaryContact__c = c2.Id;
		insert opp;

		//create test data - products, pricebook, pricebookentries
		PriceBook2 pb = new PriceBook2();
		pb.Name = 'Sonnen Sales DE';
		pb.isActive = true;
		insert pb;

		//create products
		List<Product2> pList = new List<Product2>();
		Product2 p = new Product2();
		p.Name = 'sonnenFlat 4250';
		p.CurrencyISOCode = 'EUR';
		p.AmountFreeEnergy__c = 4250;
		p.IsActive = true;
		p.Type__c = 'Electricity contract';
		p.ContractRunningTime__c = 1;
		p.ContractRenewalTime__c = 1;
		p.DeductionForEachKWpInKWh__c =  625;
		p.MinPVSize__c = 5.5;
        p.IncludeInWirtschaflichkeitsrechner__c = true;
		pList.add(p);

		Product2 p1 = new Product2();
		p1.Name = 'sonnenFlat 8000';
		p1.CurrencyISOCode = 'EUR';
		p1.AmountFreeEnergy__c = 8000;
		p1.IsActive = true;
		p1.Type__c = 'Electricity contract';
		p1.ContractRunningTime__c = 1;
		p1.ContractRenewalTime__c = 1;
		p1.DeductionForEachKWpInKWh__c =  625;
		p1.MinPVSize__c = 9.5;
        p1.IncludeInWirtschaflichkeitsrechner__c = true;
		pList.add(p1);

		Product2 p2 = new Product2();
		p2.Name = 'Battery eco 8 6kWh';
		p2.CurrencyISOCode = 'EUR';
		p2.ProductSize__c = '6 kWh';
		p2.IsActive = true;
		p2.Type__c = 'Battery';
        p2.IncludeInWirtschaflichkeitsrechner__c = true;
		pList.add(p2);

		Product2 p3 = new Product2();
		p3.Name = 'Battery eco 8 12kWh';
		p3.CurrencyISOCode = 'EUR';
		p3.ProductSize__c = '12 kWh';
		p3.IsActive = true;
		p3.Type__c = 'Battery';
        p3.IncludeInWirtschaflichkeitsrechner__c = true;
		pList.add(p3);

		insert pList;
		// obtain Id of standard pricebook
		Id standard = Test.getStandardPricebookId();

		//create pricebook entries for the standard Price book
		List<PriceBookEntry> pbsList = new List<PriceBookEntry>();

		PriceBookEntry pbs = new PriceBookEntry();
		pbs.Pricebook2Id = standard; 
		pbs.Product2Id = p.Id;
		pbs.CurrencyISOCode = 'EUR';
		pbs.UnitPrice = 10;
		pbs.IsActive = true;
		pbs.ElectricityPrice__c = 0.23;
		pbs.ElectricityPrice2000__c = 0.259;
		pbsList.add(pbs);

		PriceBookEntry pbs1 = new PriceBookEntry();
		pbs1.Pricebook2Id = standard; 
		pbs1.Product2Id = p1.Id;
		pbs1.CurrencyISOCode = 'EUR';
		pbs1.UnitPrice = 20;
		pbs1.IsActive = true;
		pbs1.ElectricityPrice__c = 0.23;
		pbs1.ElectricityPrice2000__c = 0.259;
		pbsList.add(pbs1);

		PriceBookEntry pbs2 = new PriceBookEntry();
		pbs2.Pricebook2Id = standard; 
		pbs2.Product2Id = p2.Id;
		pbs2.CurrencyISOCode = 'EUR';
		pbs2.UnitPrice = 9471.50;
		pbs2.IsActive = true;
		pbsList.add(pbs2);

		PriceBookEntry pbs3 = new PriceBookEntry();
		pbs3.Pricebook2Id = standard;
		pbs3.Product2Id = p3.Id;
		pbs3.CurrencyISOCode = 'EUR';
		pbs3.UnitPrice = 14848.50;
		pbs3.IsActive = true;
		pbsList.add(pbs3);

		insert pbsList;

		//create price book entries
		List<PriceBookEntry> pbeList = new List<PriceBookEntry>();

		// PB entries for the sonnen Sales DE pricebook
		PriceBookEntry pbe = new PriceBookEntry();
		pbe.Pricebook2Id = pb.Id; 
		pbe.Product2Id = p.Id;
		pbe.CurrencyISOCode = 'EUR';
		pbe.UnitPrice = 10;
		pbe.IsActive = true;
		pbe.MaximalConsumption__c = 4750;
		pbe.ElectricityPrice__c = 0.23;
		pbe.ElectricityPrice2000__c = 0.259;
		pbe.RecommendedMinimalConsumption__c = 0;
		pbe.RecommendedMaximalConsumption__c = 4250;
		pbe.RecommendedBatteryCapacity2__c = '6 kWh';
		pbe.MinYearlyEnergyProduction__c =4400;
		pbeList.add(pbe);

		PriceBookEntry pbe1 = new PriceBookEntry();
		pbe1.Pricebook2Id = pb.Id; 
		pbe1.Product2Id = p1.Id;
		pbe1.CurrencyISOCode = 'EUR';
		pbe1.UnitPrice = 20;
		pbe1.IsActive = true;
		pbe1.MaximalConsumption__c = 100000;
		pbe1.ElectricityPrice__c = 0.23;
		pbe1.ElectricityPrice2000__c = 0.259;
		pbe1.RecommendedMinimalConsumption__c = 6751;
		pbe1.RecommendedMaximalConsumption__c = 100000;
		pbe1.RecommendedBatteryCapacity2__c = '12 kWh';
		pbe1.MinYearlyEnergyProduction__c = 7600;
		pbeList.add(pbe1);

		PriceBookEntry pbe2 = new PriceBookEntry();
		pbe2.Pricebook2Id = pb.Id; 
		pbe2.Product2Id = p2.Id;
		pbe2.CurrencyISOCode = 'EUR';
		pbe2.UnitPrice = 9471.50;
		pbe2.IsActive = true;
		pbeList.add(pbe2);

		PriceBookEntry pbe3 = new PriceBookEntry();
		pbe3.Pricebook2Id = pb.Id;
		pbe3.Product2Id = p3.Id;
		pbe3.CurrencyISOCode = 'EUR';
		pbe3.UnitPrice = 14848.50;
		pbe3.IsActive = true;
		pbeList.add(pbe3);

		insert pbeList;	

	}

	@isTest static void test_method_one() {

		// test @RestResource endpoint
		String jsonMsg = '{ "accountId": "0019E00000TSwJr", "electricityConsumption": 7900, "maxLeistung": 10.5, "PVErzeugung": 900.3, "Stromertrag": 8000.5 } ';

		RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();

		req.requestURI = Url.getSalesforceBaseUrl().toExternalForm() +'/services/apexrest/calculator2';
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(jsonMsg);

		RestContext.request = req;
		RestContext.response = res; 

		String jsonString = wirtschaftlichkeitsrechner2.method1();

		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
			
		Map<String, Object> mParsed; // the map will hold part of the JSON response which is related to recommended products only 
										//where key is field name e.g. Name, Battery etc.

		List<Object> mlist = (List<Object>)m.get('RecommendedProducts'); 

		for(Object result : mlist) {
			mParsed = (Map<String, Object>)result;
		}
		System.debug(mParsed);
		System.assertEquals('sonnenFlat 8000', (String)mParsed.get('Name'));

		

	}
	@isTest static void test_method_two() {
		//test createOpportunityEndpoint
		Id customerId = [SELECT Id, IsPersonAccount FROM Account WHERE Name = 'Customer account' LIMIT 1].Id;
		Id partnerId = [SELECT Id, IsPersonAccount FROM Account WHERE Name = 'Partner account' LIMIT 1].Id;
		//Id oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;
		PriceBookEntry pbe1 = [SELECT Id, UnitPrice FROM PriceBookEntry WHERE Product2.Name = 'sonnenFlat 8000' AND
								Pricebook2.Name = 'Sonnen Sales DE' LIMIT 1];
		PriceBookEntry pbe3 = [SELECT Id, UnitPrice FROM PriceBookEntry WHERE Product2.Name = 'Battery eco 8 12kWh' AND
								Pricebook2.Name = 'Sonnen Sales DE'LIMIT 1];

		System.debug(partnerId);
		

		JSONGenerator gen = JSON.createGenerator(true);
		gen.writeStartObject();
		gen.writeIdField('accountId', customerId);
		gen.writeIdField('partnerId', partnerId);
		gen.writeNumberField('energyConsumption', 1200.5);
		gen.writeStringField('powerPvPlant', '6.4');
		gen.writeNumberField('generatorsOutput', 7.5);
		gen.writeStringField('roofOrientation', 'East');
		gen.writeFieldName('pbeIds');
		gen.writeStartArray();
		gen.writeStartObject();
		gen.writeStringField('Id', pbe1.Id);
		gen.writeNumberField('UnitPrice', pbe1.UnitPrice);
		gen.writeEndObject();
		gen.writeStartObject();
		gen.writeStringField('Id', pbe3.Id);
		gen.writeNumberField('UnitPrice', pbe3.UnitPrice);
		gen.writeEndObject();
		gen.writeEndArray();
		gen.writeStringField('firstName', 'customer2');
		gen.writeStringField('lastName', 'lastName2');
		gen.writeStringField('company', 'secret service');
		gen.writeStringField('email', 'a.mcgyver@gmail.com');
		gen.writeStringField('city', 'Berlin');
		gen.writeStringField('postCode', '12456');
		gen.writeStringField('street', 'Am reidbach');
		gen.writeStringField('country', 'DE');
		gen.writeEndObject();

		String jsonOpp = gen.getAsString();

		RestRequest req2 = new RestRequest();
		RestResponse res2 = new RestResponse();

		req2.requestURI = Url.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/createOpp/v2';
		req2.httpMethod = 'POST';
		req2.requestBody = Blob.valueOf(jsonOpp);

		RestContext.request = req2;
		RestContext.response = res2;


		Opportunity o = createOpportunityEndpoint.createOpportunityEndpoint();
		System.debug(o);

		System.assertEquals(2, [SELECT Id FROM OpportunityLineItem WHERE OpportunityId =:o.Id].size());


	}
	@isTest static void test_method_three() {
		Test.startTest();
		//test createOpportunityEndpoint
		Id customerId = [SELECT Id, IsPersonAccount FROM Account WHERE Name = 'Customer account' LIMIT 1].Id;
		Id partnerId = [SELECT Id, IsPersonAccount FROM Account WHERE Name = 'Partner account' LIMIT 1].Id;
		Id oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;

		PriceBookEntry pbe1 = [SELECT Id, UnitPrice FROM PriceBookEntry WHERE Product2.Name = 'sonnenFlat 8000' AND
								Pricebook2.Name = 'Sonnen Sales DE' LIMIT 1];
		PriceBookEntry pbe3 = [SELECT Id, UnitPrice FROM PriceBookEntry WHERE Product2.Name = 'Battery eco 8 12kWh' AND
								Pricebook2.Name = 'Sonnen Sales DE' LIMIT 1];

		System.debug(partnerId);

		//test opportunity  update
		JSONGenerator gen2 = JSON.createGenerator(true);
		gen2.writeStartObject();
		gen2.writeStringField('opportunityId', oppId);
		gen2.writeIdField('accountId', customerId);
		gen2.writeIdField('partnerId', partnerId);
		gen2.writeNumberField('energyConsumption', 2000);
		gen2.writeStringField('powerPvPlant', '6.4');
		gen2.writeNumberField('generatorsOutput', 7.4);
		gen2.writeStringField('roofOrientation', 'East');
		gen2.writeFieldName('pbeIds');
		gen2.writeStartArray();
		gen2.writeStartObject();
		gen2.writeStringField('Id', pbe1.Id);
		gen2.writeNumberField('UnitPrice', pbe1.UnitPrice);
		gen2.writeEndObject();
		gen2.writeStartObject();
		gen2.writeStringField('Id', pbe3.Id);
		gen2.writeNumberField('UnitPrice', pbe3.UnitPrice);
		gen2.writeEndObject();
		gen2.writeEndArray();
		gen2.writeStringField('firstName', 'customer1');
		gen2.writeStringField('lastName', 'lastName');
		gen2.writeNullField('company');
		gen2.writeStringField('email', 'a.mcgyver@gmail.com');
		gen2.writeStringField('city', 'Wipo');
		gen2.writeStringField('postCode', '12456');
		gen2.writeStringField('street', 'Am reidbach');
		gen2.writeStringField('country', 'DE');
		gen2.writeEndObject();

		String jsonOpp2 = gen2.getAsString();
		System.debug(jsonOpp2);

		RestRequest req3 = new RestRequest();
		RestResponse res3 = new RestResponse();

		req3.requestURI = Url.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/createOpp/v2';
		req3.httpMethod = 'POST';
		req3.requestBody = Blob.valueOf(jsonOpp2);

		RestContext.request = req3;
		RestContext.response = res3;

		Opportunity o = createOpportunityEndpoint.createOpportunityEndpoint();
		System.debug(o);
		
		System.assertEquals(2, [SELECT Id FROM OpportunityLineItem WHERE OpportunityId =:oppId].size());
		System.assertEquals(2000, [SELECT Id, EnergyConsumption__c FROM Opportunity WHERE Id =:oppId].EnergyConsumption__c);
		Test.stopTest();
	}

	@isTest static void test_method_four() {
		// testing null response if the entry criteria are not fulfilled
		// test @RestResource endpoint
		String jsonMsg = '{ "accountId": "0019E00000TSwJr", "electricityConsumption": 4000, "maxLeistung": 2.5, "PVErzeugung": 900.3, "Stromertrag": 2300 } ';

		RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();

		req.requestURI = Url.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/calculator2';
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(jsonMsg);

		RestContext.request = req;
		RestContext.response = res;

		String jsonString = wirtschaftlichkeitsrechner2.method1();

		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

		System.debug(m);
		System.assertEquals('KWp must be greater than 3.0 and electricity production must be greater than 2400 KWh', (String) m.get('Error') );
	}

	@isTest static void test_method_five() {
		// testing calculation of free allowance if applicable (Freistrommenge)
		// test @RestResource endpoint
		String jsonMsg = '{ "accountId": "0019E00000TSwJr", "electricityConsumption": 6000, "maxLeistung": 3.5, "PVErzeugung": 900.3, "Stromertrag": 5000 } ';

		RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();

		req.requestURI = Url.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/calculator2';
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(jsonMsg);

		RestContext.request = req;
		RestContext.response = res;

		String jsonString = wirtschaftlichkeitsrechner2.method1();

		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

		Map<String, Object> mParsed; // the map will hold part of the JSON response which is related to recommended products only
		//where key is field name e.g. Name, Battery etc.

		List<Object> mlist = (List<Object>)m.get('RecommendedProducts');

		for(Object result : mlist) {
			mParsed = (Map<String, Object>)result;
		}
		System.debug(mParsed);
		System.assertEquals('sonnenFlat 8000', (String)mParsed.get('Name'));
		System.assertEquals(5969, (Decimal) mParsed.get('FreeElectricitySupply'));

	}
}