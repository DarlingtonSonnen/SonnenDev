/*
* Version 2.0 - 21/08/2018 
	- added opt.BillingCountryIsoCode - line 49

* Version 2.1 - 12/11/2018 by Bartosz
	- changed API version to 44
	- replaced query for opportunity record type Id by Schema.SObjectType method re
	- added 'opt.Pricebook2Id = pricebookId' when creating opportunity to make sure the right pricebook is assigned.
	- modified record type assignment to opportunity - now parameter in custom metadata types

*/

@RestResource(urlMapping='/createOpp/v2/*')
global without sharing class createOpportunityEndpoint {

	@HttpPost
	global static Opportunity createOpportunityEndpoint() {

		RestRequest req =  RestContext.request;
		RestResponse res = RestContext.response;

		String jsonInput = req.requestBody.toString();
		System.debug(jsonInput);
		//deserialize body to the wrapper object
		OppWrapper opp = (OppWrapper) JSON.deserialize(jsonInput, OppWrapper.class);

		//query custom metadata WRSetting to find info for opportunity
		WrSettings__mdt wr = [SELECT OpportunityName__c, OpportunityRecordSource__c, OpportunityStage__c,
								CloseDateFormula__c, PriceBookName__c, OpportunityRecordTypeDevName__c
								FROM WrSettings__mdt WHERE MasterLabel = 'WRApi' LIMIT 1];

		//Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND Name = 'Direct Sales'].Id;
		Id recordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get(wr.OpportunityRecordTypeDevName__c).getRecordTypeId();
		Id pricebookId = [SELECT Id FROM Pricebook2 WHERE Name = :wr.PriceBookName__c LIMIT 1].Id;

		Opportunity opt = new Opportunity();
		if(opp.opportunityId != null && opp.opportunityId != '') {
			opt = [SELECT Id, AccountId, ProposedSBC__c, Name, StageName, CloseDate, RecordSource__c, PowerPvPlant__c, EnergyConsumption__c, RoofOrientation__c, 
								GeneratorsOutput__c FROM Opportunity WHERE Id = :opp.opportunityId];
		}
		
		opt.ProposedSBC__c = (Id) opp.partnerId;
		opt.Name = wr.OpportunityName__c;
		opt.RecordTypeId = recordTypeId;
		opt.StageName = wr.OpportunityStage__c;
		opt.CloseDate = Date.today().addMonths(2);
		opt.RecordSource__c = wr.OpportunityRecordSource__c;
		opt.PowerPvPlant__c = (String) opp.powerPvPlant;
		opt.EnergyConsumption__c = (Decimal) opp.energyConsumption;
		opt.RoofOrientation__c = (String) opp.roofOrientation;
		opt.GeneratorsOutput__c = (Decimal) opp.generatorsOutput;
		opt.FirstName__c = (String) opp.firstName;
		opt.LastName__c = (String) opp.lastName;
		opt.Company__c = (String) opp.company;
		opt.Email__c = (String) opp.email;
		opt.BillingCity__c = (String) opp.city;
		opt.BillingPostalCode__c = (String) opp.postCode;
		opt.BillingStreet__c = (String) opp.street;
		opt.Country__c = (String) CountryWrapper.ConvertCountry().get(opp.country);
        opt.BillingCountryIsoCode__c = (String) CountryWrapper.ConvertCountryIso().get(opp.country);
		opt.Pricebook2Id = pricebookId;
		
		List<Opportunity> oppList = new List<Opportunity>();
		oppList.add(opt);
		
       	DuplicateCheckHandlerv3 dch = new DuplicateCheckHandlerv3(oppList);
        opt.AccountId = dch.handleObjectsv2().get(opt.Id).get('Account');
        
		System.debug(opt);
		System.debug(opt.AccountId);
		try{
			upsert opt;
		}
		catch(Exception e) {
			System.debug(e);
		}

		System.debug(opt);

		List<OpportunityLineItem> listItems = new List<OpportunityLineItem>();
		List<PriceBookEntry> pbeList = (List<PriceBookEntry>) opp.pbeIds;
		System.debug('pbeList: '+pbeList);
		// if opportunity is an update and product entries are passed, delete existing opportunity products and create new ones
		if(pbeList != null && opp.opportunityId != null && opp.opportunityId != ''){
			List<OpportunityLineItem> oppProds = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId =:opp.opportunityId];
			delete oppProds;
		}

		if(pbeList != null) {
			for(PriceBookEntry i : pbeList) {
				OpportunityLineItem oil = new OpportunityLineItem();
				oil.OpportunityId = opt.Id;
				oil.PricebookEntryId = i.Id;
				oil.Quantity = 1;
				oil.UnitPrice = i.UnitPrice;
				listItems.add(oil);
			}			
		}

		insert listItems;
		return opt;
	}	

	global class OppWrapper {
		String opportunityId;
		String accountId;
		String partnerId;
		Decimal energyConsumption;
		String powerPvPlant;
		String roofOrientation;
		Decimal generatorsOutput;
		List<PriceBookEntry> pbeIds;
		String firstName;
		String lastName;
		String company;
		String email;
		String city;
		String postCode;
		String street;
		String country;
	}
}