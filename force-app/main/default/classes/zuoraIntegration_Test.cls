/*
* Created by Bartosz Jarmolinski
* Created on 25/06/2018
* 
* The class is to test custom integration of salesforce and zuora
* classes to test: zuoraIntegrationv2, ZuoraGenerator6
*
* Version 2.0 on 17/01/2019 by Bartosz
* Added test_method_six - tests scenario with multiple contracts in the context - reaching governance limits
*/

@isTest
private class zuoraIntegration_Test {
	
	@testSetup static void createData() {

		// create Account
		List<RecordType> recordTypes = [SELECT Id, Name, DeveloperName FROM RecordType WHERE DeveloperName = 'Private' OR DeveloperName = 'WebOrder' OR DeveloperName = 'SonnenFlat'];
		Map<String, Id> recordTypesMap = new Map<String, Id>();
		for (RecordType rt : recordTypes) {
			recordTypesMap.put(rt.DeveloperName, rt.Id);
		}

		//Pricebook2 pbsStnd= [SELECT ID FROM Pricebook2 WHERE IsStandard = true];
		Id pbsStnd = Test.getStandardPricebookId();

		Id recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();

		Account a = new Account(FirstName = 'Marie', LastName = 'Schmidt', Salutation='Ms.', BillingStreet='Meine Strasse 53', BillingCity='Berlin', 
								BillingPostalCode='22333', BillingCountryCode='DE', ShippingStreet='Meine Strasse 55', ShippingPostalCode='22333',
								ShippingCity='Berlin', PersonMailingStreet='Meine Strasse 55', PersonMailingCity='Berlin', 
								PersonMailingPostalCode='22333', RecordSource__c='Web', RecordTypeId=recTypeId);
		insert a;

		Zuora__Subscription__c subs = new Zuora__Subscription__c();
		subs.Zuora__Account__c = a.Id;
		subs.Zuora__Zuora_Id__c = '8adc8f9965d230d40165ece21b981bec';
		insert subs;

		// create product
		Product2 p = new Product2(Name='sonnenFlat 4250', Family='sonnenFlat', Type__c = 'Electricity contract', zProductRatePlan__c='8adc8f9961c148440161d18cf81a681d', AmountFreeEnergy__c = 4250);
		insert p;

		PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pbsStnd, UnitPrice=16.8, IsActive=true, Product2Id = p.Id );
		insert pbe;
		// create webOpportunity

		Opportunity weboppt = new Opportunity(AccountId=a.Id, RecordTypeId = recordTypesMap.get('WebOrder'), Name='Web Order test', StageName='Requested', Amount=19.99, Probability=75, CloseDate=(Date.today()+10), 
											RecordSource__c='Web', BillingCity__c = 'Testdorf', BillingPostalCode__c = '56789', BillingStreet__c = 'Testweg',
											Email__c = 'test@test.de', FirstName__c = 'newCustomer', LastName__c = 'hisLastName', ShippingCity__c='TestStadt', ShippingPostalCode__c='3456',
											ShippingStreet__c = 'Teststr.', TargetCountry__c = 'DE' );
		insert weboppt;
		
		// create contract
		Contract ctr = new Contract(AccountId=a.Id, StartDate = Date.today()+10, BillingStreet='Meine Strasse 55', BillingCity='Berlin', BillingPostalCode='22333', 
									BillingCountryCode='DE', ShippingStreet='Meine Strasse 45', ShippingCity='Berlin', ShippingPostalCode='22233', ContractTerm = 6,
									Name='sonnenFlat 4250', AnnualConsumption__c = '6000', OpportunitySource__c = weboppt.Id, RecordTypeId=recordTypesMap.get('SonnenFlat'),
									BankDataIBAN__c='DE12326545789987', contractingPartyEmail__c = 'm.schmidt23@gmail.com', tariffType__c='sonnenFlat', ConfirmedDeliveryStart__c = null,
									RegularPrePayment__c = 8.99, AppointedEnergyRate__c = 0.24, Type__c = 'sonnenbatterieHome-DE' );
		insert ctr;

		//add opportunity product to the opportunity
		OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = weboppt.Id, PricebookEntryId = pbe.Id, Quantity=1, UnitPrice=16.8);
		insert oli;


		// custom metadata settings - to make the tests passing regardless of the org
        zuoraSetting__mdt settings;
        // 00D24000000opic is org Id of sonnen Live org / production
        if(UserInfo.getOrganizationId() != '00D24000000opic' && UserInfo.getOrganizationId() != '00D24000000opicEAA' ) {

			settings = [SELECT url__c, client_id__c, client_secret__c, BonusChargeIdOneTime__c, BonusRatePlanIdOnetime__c,
                        RecurringBonusChargeId__c, RecurringBonusRatePlan__c, BonusProductZuoraId__c
                        FROM zuoraSetting__mdt WHERE Label = 'Sandbox'];            
        } else {

            settings = [SELECT url__c, client_id__c, client_secret__c, BonusChargeIdOneTime__c, BonusRatePlanIdOnetime__c,
                        RecurringBonusChargeId__c, RecurringBonusRatePlan__c, BonusProductZuoraId__c 
                        FROM zuoraSetting__mdt WHERE Label = 'Prod'];            
        }

		// create zProducts
		List<zqu__zProduct__c> zproducts = new List<zqu__zProduct__c>();
		zqu__zProduct__c sf4250 = new zqu__zProduct__c(Name = 'sonnenFlat 4250', zqu__ZuoraId__c='8adc8f9961c148440161d18cf805681b');
		zqu__zProduct__c sf5500 = new zqu__zProduct__c(Name = 'sonnenFlat 5500', zqu__ZuoraId__c='8adce42161407e0d0161470a2b484f2f');
		zqu__zProduct__c sf6750 = new zqu__zProduct__c(Name = 'sonnenFlat 6750', zqu__ZuoraId__c='8adc8f9961c148440161d19165c468b3');
		zqu__zProduct__c sf8000 = new zqu__zProduct__c(Name = 'sonnenFlat 8000', zqu__ZuoraId__c='8adce42161c1652f0161d193008062db');
		zqu__zProduct__c rbates = new zqu__zProduct__c(Name = 'Rabatte & Kulanz Produkte', zqu__ZuoraId__c= settings.BonusProductZuoraId__c);

		zproducts.add(sf4250);
		zproducts.add(sf5500);
		zproducts.add(sf6750);
		zproducts.add(sf8000);
		zproducts.add(rbates);

		insert zProducts;

		// rate plans
		List<zqu__ProductRatePlan__c> zRatePlans = new List<zqu__ProductRatePlan__c>();
		zqu__ProductRatePlan__c rp4250 = new zqu__ProductRatePlan__c(Name='sonnenFlat 4250', zqu__EffectiveStartDate__c = Date.today(), zqu__zProduct__c = sf4250.Id, zqu__EffectiveEndDate__c = Date.today().addYears(20), zqu__ZuoraId__c = '8adc8f9961c148440161d18cf81a681d');
		zqu__ProductRatePlan__c rp5500 = new zqu__ProductRatePlan__c(Name='sonnenFlat 5500', zqu__EffectiveStartDate__c = Date.today(), zqu__zProduct__c = sf5500.Id, zqu__EffectiveEndDate__c = Date.today().addYears(20), zqu__ZuoraId__c = '8adce42161407e0d0161470a2b664f31');
		zqu__ProductRatePlan__c rp6750 = new zqu__ProductRatePlan__c(Name='sonnenFlat 6750', zqu__EffectiveStartDate__c = Date.today(), zqu__zProduct__c = sf6750.Id, zqu__EffectiveEndDate__c = Date.today().addYears(20), zqu__ZuoraId__c = '8adc8f9961c148440161d19165d868b5');
		zqu__ProductRatePlan__c rp8000 = new zqu__ProductRatePlan__c(Name='sonnenFlat 8000', zqu__EffectiveStartDate__c = Date.today(), zqu__zProduct__c = sf8000.Id, zqu__EffectiveEndDate__c = Date.today().addYears(20), zqu__ZuoraId__c = '8adce42161c1652f0161d19300a562dd');
		zqu__ProductRatePlan__c oneTimeBonus = new zqu__ProductRatePlan__c(Name='One-time Bonus', zqu__EffectiveStartDate__c = Date.today(), zqu__zProduct__c = rbates.Id, zqu__EffectiveEndDate__c = Date.today().addYears(20), zqu__ZuoraId__c = settings.BonusRatePlanIdOnetime__c);
		zqu__ProductRatePlan__c recurringBonus = new zqu__ProductRatePlan__c(Name='Recurring Bonus', zqu__EffectiveStartDate__c = Date.today(), zqu__zProduct__c = rbates.Id, zqu__EffectiveEndDate__c = Date.today().addYears(20), zqu__ZuoraId__c = settings.RecurringBonusRatePlan__c);

		zRatePlans.add(rp4250);
		zRatePlans.add(rp5500);
		zRatePlans.add(rp6750);
		zRatePlans.add(rp8000);
		zRatePlans.add(oneTimeBonus);
		zRatePlans.add(recurringBonus);

		insert zRatePlans;

		// rate plan charges
		List<zqu__ProductRatePlanCharge__c> zRatePlanCharges = new List<zqu__ProductRatePlanCharge__c>();
		zqu__ProductRatePlanCharge__c rpc4250Comm = new zqu__ProductRatePlanCharge__c(Name='Community Fee', zqu__ProductRatePlan__c = rp4250.Id, zqu__ListPrice__c = 19.99, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adc8f9961c148440161d18cf826681f', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date'  );
		zqu__ProductRatePlanCharge__c rpc4250Absc = new zqu__ProductRatePlanCharge__c(Name='Abschlag', zqu__ProductRatePlan__c = rp4250.Id, zqu__ListPrice__c = 9.99, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adc8f9961c148440161d18cf8426822', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date'  );
		zqu__ProductRatePlanCharge__c rpc42502000 = new zqu__ProductRatePlanCharge__c(Name='Verbrauch nach 2.000 kWh', zqu__ProductRatePlan__c = rp4250.Id, zqu__ListPrice__c = 0.259, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adc8f9961c148440161d18cf85c6825', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date');
		zqu__ProductRatePlanCharge__c rpc4250Verb = new zqu__ProductRatePlanCharge__c(Name='Verbrauch bis 2000 kWh', zqu__ProductRatePlan__c = rp4250.Id, zqu__ListPrice__c = 0.23, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adc8f9961c148440161d18cf8756828', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date');
		zqu__ProductRatePlanCharge__c rpc4250Gele = new zqu__ProductRatePlanCharge__c(Name='Geleistete Abschlagszahlungen', zqu__ProductRatePlan__c = rp4250.Id, zqu__ListPrice__c = -0.01,zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adc8f9961c148440161d18cf88f682b', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date');

		zRatePlanCharges.add(rpc4250Comm);
		zRatePlanCharges.add(rpc4250Absc);
		zRatePlanCharges.add(rpc4250Verb);
		zRatePlanCharges.add(rpc42502000);
		zRatePlanCharges.add(rpc4250Gele);

		zqu__ProductRatePlanCharge__c rpc5500Comm = new zqu__ProductRatePlanCharge__c(Name='Community Fee', zqu__ProductRatePlan__c = rp5500.Id, zqu__ListPrice__c = 19.99 );
		zqu__ProductRatePlanCharge__c rpc5500Absc = new zqu__ProductRatePlanCharge__c(Name='Abschlag', zqu__ProductRatePlan__c = rp5500.Id, zqu__ListPrice__c = 9.99 );
		zqu__ProductRatePlanCharge__c rpc55002000 = new zqu__ProductRatePlanCharge__c(Name='Verbrauch nach 2.000 kWh', zqu__ProductRatePlan__c = rp5500.Id, zqu__ListPrice__c = 0.259 );
		zqu__ProductRatePlanCharge__c rpc5500Verb = new zqu__ProductRatePlanCharge__c(Name='Verbrauch bis 2000 kWh', zqu__ProductRatePlan__c = rp5500.Id, zqu__ListPrice__c = 0.23 );
		zqu__ProductRatePlanCharge__c rpc5500Gele = new zqu__ProductRatePlanCharge__c(Name='Geleistete Abschlagszahlungen', zqu__ProductRatePlan__c = rp5500.Id, zqu__ListPrice__c = -0.01 );

		zRatePlanCharges.add(rpc5500Comm);
		zRatePlanCharges.add(rpc5500Absc);
		zRatePlanCharges.add(rpc5500Verb);
		zRatePlanCharges.add(rpc55002000);
		zRatePlanCharges.add(rpc5500Gele);

		zqu__ProductRatePlanCharge__c rpc6750Comm = new zqu__ProductRatePlanCharge__c(Name='Community Fee', zqu__ProductRatePlan__c = rp6750.Id, zqu__ListPrice__c = 19.99 );
		zqu__ProductRatePlanCharge__c rpc6750Absc = new zqu__ProductRatePlanCharge__c(Name='Abschlag', zqu__ProductRatePlan__c = rp6750.Id, zqu__ListPrice__c = 9.99 );
		zqu__ProductRatePlanCharge__c rpc67502000 = new zqu__ProductRatePlanCharge__c(Name='Verbrauch nach 2.000 kWh', zqu__ProductRatePlan__c = rp6750.Id, zqu__ListPrice__c = 0.259 );
		zqu__ProductRatePlanCharge__c rpc6750Verb = new zqu__ProductRatePlanCharge__c(Name='Verbrauch bis 2000 kWh', zqu__ProductRatePlan__c = rp6750.Id, zqu__ListPrice__c = 0.23 );
		zqu__ProductRatePlanCharge__c rpc6750Gele = new zqu__ProductRatePlanCharge__c(Name='Geleistete Abschlagszahlungen', zqu__ProductRatePlan__c = rp6750.Id, zqu__ListPrice__c = -0.01 );

		zRatePlanCharges.add(rpc6750Comm);
		zRatePlanCharges.add(rpc6750Absc);
		zRatePlanCharges.add(rpc6750Verb);
		zRatePlanCharges.add(rpc67502000);
		zRatePlanCharges.add(rpc6750Gele);

		zqu__ProductRatePlanCharge__c rpc8000Comm = new zqu__ProductRatePlanCharge__c(Name='Community Fee', zqu__ProductRatePlan__c = rp8000.Id, zqu__ListPrice__c = 29.99, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adce42161c1652f0161d19300bb62df', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date' );
		zqu__ProductRatePlanCharge__c rpc8000Absc = new zqu__ProductRatePlanCharge__c(Name='Abschlag', zqu__ProductRatePlan__c = rp8000.Id, zqu__ListPrice__c = 9.99, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adce42161c1652f0161d19300eb62e2', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date' );
		zqu__ProductRatePlanCharge__c rpc80002000 = new zqu__ProductRatePlanCharge__c(Name='Verbrauch nach 2.000 kWh', zqu__ProductRatePlan__c = rp8000.Id, zqu__ListPrice__c = 0.259, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adce42161c1652f0161d193011962e5', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date' );
		zqu__ProductRatePlanCharge__c rpc8000Verb = new zqu__ProductRatePlanCharge__c(Name='Verbrauch bis 2000 kWh', zqu__ProductRatePlan__c = rp8000.Id, zqu__ListPrice__c = 0.23, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adce42161c1652f0161d193014862e8', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date' );
		zqu__ProductRatePlanCharge__c rpc8000Gele = new zqu__ProductRatePlanCharge__c(Name='Geleistete Abschlagszahlungen', zqu__ProductRatePlan__c = rp8000.Id, zqu__ListPrice__c = -0.01, zqu__Type__c = 'Recurring', zqu__ZuoraId__c = '8adce42161c1652f0161d193017762eb', 	zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date');

		zRatePlanCharges.add(rpc8000Comm);
		zRatePlanCharges.add(rpc8000Absc);
		zRatePlanCharges.add(rpc8000Verb);
		zRatePlanCharges.add(rpc80002000);
		zRatePlanCharges.add(rpc8000Gele);

		zqu__ProductRatePlanCharge__c oneTimeBonusChrg = new zqu__ProductRatePlanCharge__c(Name='One-time Bonus', zqu__ProductRatePlan__c = oneTimeBonus.Id, zqu__ListPrice__c = 0.99, zqu__ZuoraId__c = settings.BonusChargeIdOneTime__c, zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Flat Fee Pricing', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date' );
		zqu__ProductRatePlanCharge__c recurringBonusChrg = new zqu__ProductRatePlanCharge__c(Name='Bonus', zqu__ProductRatePlan__c = recurringBonus.Id, zqu__ListPrice__c = 0.99, zqu__ZuoraId__c = settings.RecurringBonusChargeId__c, zqu__ListPriceBase__c = 'Per Billing Period', zqu__Model__c = 'Discount-Fixed Amount', zqu__TriggerEvent__c = 'Upon Service Activation', zqu__BillCycleType__c = 'Default From Customer Account',zqu__BillingPeriodAlignment__c = 'Align To Charge', zqu__EndDateCondition__c = 'Subscription End Date' );

		zRatePlanCharges.add(oneTimeBonusChrg);
		zRatePlanCharges.add(recurringBonusChrg);

		insert zRatePlanCharges;
		System.debug('zRatePlanCharges '+ zRatePlanCharges);
	}

	@isTest static void test_method_one() {
		// code coverage for the class ZuoraQuoteGenerator6
		
		// test zquote creation
		Contract ct = [SELECT Id, ConfirmedDeliveryStart__c, AccountId, StartDate, BillingStreet, BillingCity, BillingPostalCode,
						ShippingStreet, ShippingCity, ShippingPostalCode, ContractTerm, Name, AnnualConsumption__c, OpportunitySource__c,
						RecordTypeId, BankDataIBAN__c, contractingPartyEmail__c, tariffType__c
						FROM Contract WHERE Name = 'sonnenFlat 4250'];

		ct.ConfirmedDeliveryStart__c = Date.today()+10;

		List<Contract> contracts = new List<Contract>();
		contracts.add(ct);

		Test.startTest();
		//update ct;
		ZuoraQuoteGenerator6.generateQuote(contracts); // the method needs to be called as long as the logic is initialized from process builder
		Test.stopTest();

		// assertions
		List<zqu__Quote__c> zquotes = [SELECT Id, Contract__c FROM zqu__Quote__c WHERE Contract__c = :ct.Id];
		List<zqu__QuoteRatePlan__c> zquoteCharges = [SELECT Id, zqu__ProductRatePlanZuoraId__c FROM zqu__QuoteRatePlan__c WHERE zqu__Quote__c =:zquotes[0].Id];
		
		// check that zQuote has been created and related to the contract once the Confirmed deliver date has been filled in.
		System.assertNotEquals(0, zquotes.size());
		// check that right product plan has been chosen
		System.assertEquals([SELECT zqu__ZuoraId__c FROM zqu__ProductRatePlan__c WHERE Name = 'sonnenFlat 4250' LIMIT 1].zqu__zuoraId__c, zquoteCharges[0].zqu__ProductRatePlanZuoraId__c);
	}

	@isTest static void test_method_two() {
		// test adding bonus code - zuoraIntegrationV2 class

		// create subscription under account
		Zuora__Subscription__c subs = new Zuora__Subscription__c();
		subs.Zuora__Account__c = [SELECT Id FROM Account WHERE Name = 'Marie Schmidt'].Id;
		subs.Zuora__Zuora_Id__c = 'A-S00000051';
		subs.Zuora__QuoteNumber__c = 'Q001454';
		subs.Zuora__SubscriptionNumber__c = '8adc8f9963ecb5c20163ef014eb100b4';
		subs.Zuora__Status__c = 'Active';
		insert subs;

		// create campaign
		Campaign cm1 = new Campaign();
		cm1.Name = '1000 kwh Überschussstrom';
		cm1.IsActive = true;
		cm1.Status = 'In Progress';
		cm1.RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Bonus'].Id;
		cm1.BonusContractType__c = 'Energy';
		cm1.TargetCountry__c = 'DE';
		cm1.BonusAmount__c = 1000;
		cm1.BonusUnit__c = 'kWh';
		cm1.BonusType__c = 'periodical';
		cm1.BonusNoOfMonths__c = 5;
		insert cm1;

		// create campaign 2nd campaign 
		Campaign cm2 = new Campaign();
		cm2.Name = '1 Month Community Bonus - Sales';
		cm2.IsActive = true;
		cm2.Status = 'In Progress';
		cm2.RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Bonus'].Id;
		cm2.TargetCountry__c = 'DE';
		cm2.BonusAmount__c = 19.99;
		cm2.BonusUnit__c = 'Euro';
		cm2.BonusType__c = 'oneshot';
		cm2.BonusNoOfMonths__c = 1;
		insert cm2;

		List<Bonus__c> bonuses = new List<Bonus__c>();
		// create bonus
		// *** Electricity recurring ***
		Bonus__c b1 = new Bonus__c();
		b1.Contract__c = [SELECT Id, ConfirmedDeliveryStart__c FROM Contract WHERE Name = 'sonnenFlat 4250'].Id;
		b1.CampaignId__c = cm1.Id;
		b1.Account__c = [SELECT Id FROM Account WHERE Name = 'Marie Schmidt' LIMIT 1].Id;
		b1.BonusInitiator__c = 'eService';
		b1.BonusReason__c = 'Service Goodwill';
		b1.Approval_Status__c = 'Pending';
		b1.RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Energy' AND SObjectType = 'Bonus__c' LIMIT 1].Id;
		b1.BonusType__c = 'periodical';
		b1.Amount__c = 200;
		b1.Unit__c = 'kWh';
		b1.ApplyTo__c = 'consumption';
		b1.NoOfMonths__c = 5;
		b1.StartDate__c = Date.today().addDays(10);
		//insert b1;
		bonuses.add(b1);
		// update bonus status to trigger callout to zuora
//		b1.Approval_Status__c = 'Approved';
//		update b1;

		// another bonus - one time:
		Bonus__c b2 = new Bonus__c();
		b2.Contract__c = [SELECT Id, ConfirmedDeliveryStart__c FROM Contract WHERE Name = 'sonnenFlat 4250'].Id;
		b2.Account__c = [SELECT Id FROM Account WHERE Name = 'Marie Schmidt' LIMIT 1].Id;
		b2.CampaignId__c = cm1.Id;
		b2.BonusInitiator__c = 'eService';
		b2.BonusReason__c = 'Service Goodwill';
		b2.Approval_Status__c = 'Pending';
		b2.RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Energy' AND SObjectType = 'Bonus__c' LIMIT 1].Id;
		b2.BonusType__c = 'oneshot';
		b2.Amount__c = 19.99;
		b2.Unit__c = 'Euro';
		b2.ApplyTo__c = 'consumption';
		b2.NoOfMonths__c = 1;
		b2.StartDate__c = Date.today().addDays(10);

		bonuses.add(b2);
		insert bonuses;

		for (Bonus__c b : bonuses) {
			b.Approval_Status__c = 'Approved';
		}
		Test.startTest();
		update bonuses;
		Test.stopTest();

		// assert creation
		System.assertEquals(2, [SELECT Id FROM Bonus__c].size());
		System.assertEquals(2, [SELECT Id, Process__c FROM zuoraSync__c WHERE Process__c = 'zuoraIntegrationV2'].size());
	}

    @isTest static void test_method_three() {
        // tests code which sends amendment to zuora following change in the field Contract.RegularPrepayment__c
        // the code in the class zuoraIntegrationV2

        List<Contract> ctr = [SELECT Id, AccountId, RegularPrePayment__c FROM Contract WHERE Name = 'sonnenFlat 4250'];
        ctr[0].RegularPrePayment__c = 12.0;

        Test.startTest();
        update ctr[0];
        Test.stopTest();

        List<zuoraSync__c> zS = [SELECT Id, Process__c, ResponseCode__c FROM zuoraSync__c];
        System.assertEquals(1, zS.size());
        System.assertEquals('200', zS[0].ResponseCode__c);
    }

//    @isTest static void test_method_four() {
//        // test queueable logic - more than 50 contract are populated with confirmed delivery date
//        List<Contract> contracts = new List<Contract>();
//        List<Account> accounts = new List<Account>();
//		List<Opportunity> opps = new List<Opportunity>();
//		List<OpportunityLineItem> oppProducts = new List<OpportunityLineItem>();
//
//        Id webOppId = [SELECT Id FROM Opportunity WHERE Name = 'Web Order test'].Id;
//        Id recordTypeId = Schema.SObjectType.Contract.getRecordTypeInfosByName().get('SonnenFlat').getRecordTypeId();
//        Id recTypeIdAcc = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
//		Id recTypeOpp = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('WebOrder').getRecordTypeId();
//		Id priceBookEntryId = [SELECT Id FROM PricebookEntry LIMIT 1].Id;
//
//
//        for (Integer i=0; i < 2; i++) {
//            Account a = new Account(FirstName = 'Marie', LastName = 'Schmidt ' +i, Salutation='Ms.', BillingStreet='Meine Strasse 53', BillingCity='Berlin',
//                    BillingPostalCode='22333', BillingCountryCode='DE', ShippingStreet='Meine Strasse 55', ShippingPostalCode='22333',
//                    ShippingCity='Berlin', PersonMailingStreet='Meine Strasse 55', PersonMailingCity='Berlin',
//                    PersonMailingPostalCode='22333', RecordSource__c='Web', RecordTypeId=recTypeIdAcc);
//
//            accounts.add(a);
//        }
//        insert accounts;
//
//		for (Account a : accounts) {
//			Opportunity weboppt = new Opportunity(AccountId=a.Id, RecordTypeId = recTypeOpp, Name='Web Order test', StageName='Requested', Amount=19.99, Probability=75, CloseDate=(Date.today()+10),
//					RecordSource__c='Web', BillingCity__c = 'Testdorf', BillingPostalCode__c = '56789', BillingStreet__c = 'Testweg',
//					Email__c = 'test@test.de', FirstName__c = 'newCustomer', LastName__c = 'hisLastName', ShippingCity__c='TestStadt', ShippingPostalCode__c='3456',
//					ShippingStreet__c = 'Teststr.', TargetCountry__c = 'DE' );
//
//			opps.add(weboppt);
//		}
//		insert opps;
//
//		for (Opportunity o : opps) {
//			OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = priceBookEntryId, Quantity=1, UnitPrice=16.8);
//			oppProducts.add(oli);
//
//			// create contract
//			Contract ctr = new Contract(AccountId=o.AccountId, StartDate = Date.today()+10, BillingStreet='Meine Strasse 55', BillingCity='Berlin', BillingPostalCode='22333',
//					BillingCountryCode='DE', ShippingStreet='Meine Strasse 45', ShippingCity='Berlin', ShippingPostalCode='22233', ContractTerm = 6,
//					Name='sonnenFlat 4250', AnnualConsumption__c = '6000', OpportunitySource__c = o.Id, RecordTypeId=recordTypeId,
//					BankDataIBAN__c='DE12326545789987', contractingPartyEmail__c = 'm.schmidt23@gmail.com', tariffType__c='sonnenFlat', ConfirmedDeliveryStart__c = null,
//					RegularPrePayment__c = 8.99, AppointedEnergyRate__c = 0.24, Type__c = 'sonnenbatterieHome-DE' );
//			contracts.add(ctr);
//
//		}
//		insert oppProducts;
//
////        for (Integer i=0; i < 60; i++) {
////            // create contract
////            Contract ctr = new Contract(AccountId=accounts[i].Id, StartDate = Date.today()+10, BillingStreet='Meine Strasse 55', BillingCity='Berlin', BillingPostalCode='22333',
////                    BillingCountryCode='DE', ShippingStreet='Meine Strasse 45', ShippingCity='Berlin', ShippingPostalCode='22233', ContractTerm = 6,
////                    Name='sonnenFlat 4250', AnnualConsumption__c = '6000', OpportunitySource__c = webOppId, RecordTypeId=recordTypeId,
////                    BankDataIBAN__c='DE12326545789987', contractingPartyEmail__c = 'm.schmidt23@gmail.com', tariffType__c='sonnenFlat', ConfirmedDeliveryStart__c = null,
////                    RegularPrePayment__c = 8.99, AppointedEnergyRate__c = 0.24, Type__c = 'sonnenbatterieHome-DE' );
////            contracts.add(ctr);
////        }
//        insert contracts;
//
//        for (Contract c : contracts) {
//            c.ConfirmedDeliveryStart__c = Date.today() + 10;
//        }
//        Test.startTest();
//        //update contracts;
//        ZuoraQuoteGenerator7.generateQuote(contracts); // the method needs to be called as long as the logic is initialized from process builder
//        Test.stopTest();
//    }
    @isTest static void test_method_five() {

        Id webOppId = [SELECT Id FROM Opportunity WHERE Name = 'Web Order test'].Id;
        Contact c = new Contact(FirstName = 'Angus', LastName = 'MacGyver', Email = 'a.macgyver@sonnen.de');
        insert c;

        zqu__Quote__c q = new zqu__Quote__c();
        q.zqu__Opportunity__c = webOppId;
        q.zqu__Status__c = 'Sent to Z-Billing';
        q.zqu__BillToContact__c = c.Id;
        q.zqu__SoldToContact__c = c.Id;
        q.zqu__BillingBatch__c = 'Batch1';
        q.zqu__PaymentTerm__c = 'Due Upon Receipt';
        q.zqu__PaymentMethod__c = 'Wire Transfer';
        q.zqu__Customer_Acceptance_Date__c = Date.today() + 10;
        q.zqu__StartDate__c = Date.today() + 10;
        q.zqu__Subscription_Term_Type__c = 'Evergreen';
        q.zqu__Service_Activation_Date__c = Date.today() + 10;
        q.zqu__ZuoraAccountID__c = '8adc8f996512644e0165135aa958105a';
        q.zqu__Zuora_Account_Number__c = 'A00000084';
        insert q;

        String zProductRatePlanId = [SELECT Id FROM zqu__ProductRatePlan__c WHERE Name LIKE 'sonnenFlat%' LIMIT 1].Id;
        zqu.zChargeGroup newChargeGroup = zqu.zQuoteUtil.getChargeGroup(q.Id, zProductRatePlanId);
        zqu.ZQuoteUtil.addChargeGroup(newChargeGroup);
    }
	@isTest static void test_method_six() {
		// tests scenario where multiple quotes are passed to the zuoraQuoteGenerator6 which can potentially hit governance limits.
		// the method test if the limits are hit

		Contract ct = [SELECT Id, ConfirmedDeliveryStart__c, AccountId, StartDate, BillingStreet, BillingCity, BillingPostalCode,
				ShippingStreet, ShippingCity, ShippingPostalCode, ContractTerm, Name, AnnualConsumption__c, OpportunitySource__c,
				RecordTypeId, BankDataIBAN__c, contractingPartyEmail__c, TariffType__c, Type__c
		FROM Contract WHERE Name = 'sonnenFlat 4250'];

		ct.ConfirmedDeliveryStart__c = Date.today()+10;

		List<Contract> contracts = new List<Contract>();
		//contracts.add(ct);

		List<Account> accounts = new List<Account>();
		Id recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Private').getRecordTypeId();
		for (Integer i=0; i < 20; i++) {
			Account a = new Account(FirstName = 'Marie', LastName = 'Schmidt', Salutation='Ms.', BillingStreet='Meine Strasse 53', BillingCity='Berlin',
					BillingPostalCode='22333', BillingCountryCode='DE', ShippingStreet='Meine Strasse 55', ShippingPostalCode='22333',
					ShippingCity='Berlin', PersonMailingStreet='Meine Strasse 55', PersonMailingCity='Berlin',
					PersonMailingPostalCode='22333', RecordSource__c='Web', RecordTypeId=recTypeId);

			accounts.add(a);
		}
		insert accounts;

		for (Account a : accounts) {
			Account a0 = new Account(FirstName = 'Marie', LastName = 'Schmidt', Salutation='Ms.', BillingStreet='Meine Strasse 53', BillingCity='Berlin',
									BillingPostalCode='22333', BillingCountryCode='DE', ShippingStreet='Meine Strasse 55', ShippingPostalCode='22333',
									ShippingCity='Berlin', PersonMailingStreet='Meine Strasse 55', PersonMailingCity='Berlin',
									PersonMailingPostalCode='22333', RecordSource__c='Web', RecordTypeId=recTypeId);

			Contract ct0 = ct.clone();
			ct0.AccountId = a.Id;
			ct0.Id = null;
            ct0.Tariff_Version__c = 'sFh 2.0';
            ct0.TariffType__c = 'sonnenFlat';
            ct0.Type__c = 'sonnenbatterieHome-DE';
			contracts.add(ct0);
        }

        insert contracts;
        Test.startTest();
		ZuoraQuoteGenerator6.generateQuote(contracts); // the method needs to be called as long as the logic is initialized from process builder
        Test.stopTest();

	}
	@isTest static void test_method_seven() {

        Map<String, Schema.SObjectField> objectFields = Schema.getGlobalDescribe().get('Contract').getDescribe().fields.getMap();
        List<String> listFields = new List<String>();
        listFields.addAll(objectFields.keySet());

        String query = 'SELECT';

        for (Integer i=0; i < listFields.size(); i++) {
            if (i < listFields.size() - 1) {
                query = query + ' ' + listFields[i] + ', ';
            } else {
                query = query + listFields[i] + ' ';
            }
        }
        query = query + 'FROM Contract';
        System.debug(query);
        List<Contract> contracts = Database.query(query);

        //fill confirmed delivery start
        for (Contract c : contracts) {
            c.ConfirmedDeliveryStart__c = Date.today();
        }

		List<zuoraSync__c> zuoraSyncs = new List<zuoraSync__c>();

		zuoraSync__c sync = new zuoraSync__c();
		sync.RemainingContracts__c = JSON.serialize(contracts);
		sync.Message__c = 'Zuora quote creation delayed for the contracts in Remaining Contracts field in order to avoid SF limits.';
		sync.Process__c = 'Delayed quote creation';
		zuoraSyncs.add(sync);

		Test.startTest();
		zuoraCreateQuoteWrapper.generateQuote(zuoraSyncs);
		Test.stopTest();

        System.assertEquals(1, [SELECT Id FROM zqu__Quote__c].size());
	}
}