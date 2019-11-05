@isTest
public class RecommendationTariff_Testv5 {
    
    @testSetup static void createTestData() {
        //String products = 'Product2:{Name=sonnenFlat 4250, AmountFreeEnergy__c=4250}, Product2:{Name=sonnenFlat 5500, AmountFreeEnergy__c=5500}, Product2:{Name=sonnenFlat 6750, AmountFreeEnergy__c=6750}, Product2:{Name=sonnenFlat 8000, AmountFreeEnergy__c=8000}, Product2:{Name=sonnenStrom plus})';

        List<Product2> products2 = new List<Product2>();

        Product2 p1 = new Product2();
        p1.Name = 'sonnenFlat 4250';
        //p1.StockKeepingUnit = 'es-rc-sonnenFlat-home-4250-v3.0-de';
        p1.StockKeepingUnit = 'a';
        p1.AmountFreeEnergy__c = 4250;
        p1.Type__c = 'Electricity contract';
        p1.IsActive = true;
        p1.IncludeInRecommendationLogic__c = true;
        products2.add(p1);

        Product2 p2 = new Product2();
        p2.Name = 'sonnenFlat 5500';
        //p2.StockKeepingUnit = 'es-rc-sonnenFlat-home-5500-v3.0-de';
        p2.StockKeepingUnit = 'b';
        p2.AmountFreeEnergy__c = 5500;
        p2.Type__c = 'Electricity contract';
        p2.IsActive = true;
        p2.IncludeInRecommendationLogic__c = true;
        products2.add(p2);

        Product2 p3 = new Product2();
        p3.Name = 'sonnenFlat 6750';
        //p3.StockKeepingUnit = 'es-rc-sonnenFlat-home-6750-v3.0-de';
        p3.StockKeepingUnit = 'c';
        p3.AmountFreeEnergy__c = 6750;
        p3.Type__c = 'Electricity contract';
        p3.IsActive = true;
        p3.IncludeInRecommendationLogic__c = true;
        products2.add(p3);

        Product2 p4 = new Product2();
        p4.Name = 'sonnenFlat 8000';
        p4.StockKeepingUnit = 'es-rc-sonnenFlat-home-8000-v3.0-de';
        p4.StockKeepingUnit = 'd';
        p4.AmountFreeEnergy__c = 8000;
        p4.Type__c = 'Electricity contract';
        p4.IsActive = true;
        p4.IncludeInRecommendationLogic__c = true;
        products2.add(p4);

        Product2 p5 = new Product2();
        p5.Name = 'sonnenStrom plus';
        //p5.StockKeepingUnit = 'es-rc-sonnenStrom-plus-v1.0-de';
        p5.StockKeepingUnit = 'e';
        p5.AmountFreeEnergy__c = 0;
        p5.Type__c = 'Electricity contract';
        p5.IsActive = true;
        p5.IncludeInRecommendationLogic__c = true;
        products2.add(p5);
        
        Product2 p6 = new Product2();
        p6.Name = 'sonnenFlat individual';
        //p6.StockKeepingUnit = 'es-rc-sonnenFlat-home-flex-v3.0-de';
        p6.StockKeepingUnit = 'f';
        p6.AmountFreeEnergy__c = 0;
        p6.Type__c = 'Electricity contract';
        p6.IsActive = true;
        p6.IncludeInRecommendationLogic__c = false;
        products2.add(p6);
        
        Product2 p7 = new Product2();
        p7.Name = 'sonnenCommunity Flat 8000';
        //p7.StockKeepingUnit = 'es-rc-sonnenCommunity-flat-v1.0-de-8000';
        p7.StockKeepingUnit = 'g';
        p7.AmountFreeEnergy__c = 0;
        p7.Type__c = 'Electricity contract';
        p7.IsActive = true;
        p7.IncludeInRecommendationLogic__c = false;
        products2.add(p7);
        
        Product2 p8 = new Product2();
        p8.Name = 'sonnenCommunity Flat';
        //p8.StockKeepingUnit = 'es-rc-sonnenCommunity-flat-de';
        p8.StockKeepingUnit = 'h';
        p8.AmountFreeEnergy__c = 0;
        p8.Type__c = 'Electricity contract';
        p8.IsActive = true;
        p8.IncludeInRecommendationLogic__c = false;
        products2.add(p8);
        
        Product2 p9 = new Product2();
        p9.Name = 'sonnenFlat flex8000';
        //p8.StockKeepingUnit = 'es-rc-sonnenCommunity-flat-de';
        p9.StockKeepingUnit = 'i';
        p9.AmountFreeEnergy__c = 0;
        p9.Type__c = 'Electricity contract';
        p9.IsActive = true;
        p9.IncludeInRecommendationLogic__c = false;
        products2.add(p9);

        insert products2;
        System.debug(products2);

        Pricebook2 pb = new Pricebook2(Name = 'sonnen Sales DE', Description = 'sonnen Sales DE', IsActive = true);
        insert pb;

        List<PriceBookEntry> pbeList = new List<PricebookEntry>();
        // standard price book
        // obtain Id of standard pricebook
        Id standard = Test.getStandardPricebookId();

        //create pricebook entries for the standard Price book
        PricebookEntry pbs1 = new PricebookEntry(Product2Id=p1.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=4400.00, MaximalConsumption__c=4750, RecommendedBatteryCapacity2__c='6 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=standard, isActive=true);
        pbeList.add(pbs1);

        PricebookEntry pbs2 = new PricebookEntry(Product2Id=p2.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=6000, MaximalConsumption__c=100000, RecommendedBatteryCapacity2__c='8 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=standard, isActive=true);
        pbeList.add(pbs2);

        PricebookEntry pbs3 = new PricebookEntry(Product2Id=p3.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=7600, MaximalConsumption__c=100000, RecommendedBatteryCapacity2__c='10 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=standard, isActive=true);
        pbeList.add(pbs3);

        PricebookEntry pbs4 = new PricebookEntry(Product2Id=p4.Id, UnitPrice=29.99, MinYearlyEnergyProduction__c=7600, MaximalConsumption__c=100000, RecommendedBatteryCapacity2__c='12 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=standard, isActive=true);
        pbeList.add(pbs4);

        PricebookEntry pbs5 = new PricebookEntry(Product2Id=p5.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=0, MaximalConsumption__c=100000, ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=standard, isActive=true);
        pbeList.add(pbs5);

        // sonnen Sales DE price book

        PricebookEntry pbe1 = new PricebookEntry(Product2Id=p1.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=4400.00, MaximalConsumption__c=10000, RecommendedBatteryCapacity2__c='6 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=pb.Id, isActive=true);
        pbeList.add(pbe1);

        PricebookEntry pbe2 = new PricebookEntry(Product2Id=p2.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=6000, MaximalConsumption__c=100000, RecommendedBatteryCapacity2__c='8 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=pb.Id, isActive=true);
        pbeList.add(pbe2);

        PricebookEntry pbe3 = new PricebookEntry(Product2Id=p3.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=7600, MaximalConsumption__c=100000, RecommendedBatteryCapacity2__c='10 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=pb.Id, isActive=true);
        pbeList.add(pbe3);

        PricebookEntry pbe4 = new PricebookEntry(Product2Id=p4.Id, UnitPrice=29.99, MinYearlyEnergyProduction__c=7600, MaximalConsumption__c=100000, RecommendedBatteryCapacity2__c='12 kWh', ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=pb.Id, isActive=true);
        pbeList.add(pbe4);

        PricebookEntry pbe5 = new PricebookEntry(Product2Id=p5.Id, UnitPrice=19.99, MinYearlyEnergyProduction__c=0, MaximalConsumption__c=100000, ElectricityPrice__c=0.2300, ElectricityPrice2000__c=0.2590, Pricebook2Id=pb.Id, isActive=true);
        pbeList.add(pbe5);

        insert pbeList;
    }
   
    // new test methods - Elena's Testfaelle
    static testMethod void scenarioN1() {
                
        String jsonMessage = '{ "energyConsumption": 4250, "yearlyProduction": 4400, "batterySize": 6, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 4250', (String) responseMap.get('name'));
    }
   	
    static testMethod void scenarioN2() {
                
        String jsonMessage = '{ "energyConsumption": 5500, "yearlyProduction": 6000, "batterySize": 8, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 5500', (String) responseMap.get('name'));
    }
    
    static testMethod void scenarioN3() {
                
        String jsonMessage = '{ "energyConsumption": 6750, "yearlyProduction": 7600, "batterySize": 10, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 6750', (String) responseMap.get('name'));
    }
    
    static testMethod void scenarioN4() {
                
        String jsonMessage = '{ "energyConsumption": 8000, "yearlyProduction": 7600, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 8000', (String) responseMap.get('name'));
    }
    
    static testMethod void scenarioN5() {
                
        String jsonMessage = '{ "energyConsumption": 2000, "yearlyProduction": 6000, "batterySize": 6, "nominalPower": 2.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenStrom plus', (String) responseMap.get('name'));
    }
    
    static testMethod void scenarioN6() {
                
        String jsonMessage = '{ "energyConsumption": 2000, "yearlyProduction": 1860, "batterySize": 6, "nominalPower": 3.1 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenStrom plus', (String) responseMap.get('name'));
    }
    	
    static testMethod void scenarioN7() {
                
        String jsonMessage = '{ "energyConsumption": 3250, "yearlyProduction": 3850, "batterySize": 6, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(0, (Decimal) responseMap.get('monthlyAdvPayment'));
        System.assertEquals(3820, (Decimal) responseMap.get('freeElectricity'));
        
    }
    
    static testMethod void scenarioN8() {
                
        String jsonMessage = '{ "energyConsumption": 4000, "yearlyProduction": 3850, "batterySize": 6, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(3.45, (Decimal) responseMap.get('monthlyAdvPayment'));
        System.assertEquals(3820, (Decimal) responseMap.get('freeElectricity'));
        
    }
    
    static testMethod void scenarioN9() {
                
        String jsonMessage = '{ "energyConsumption": 8000, "yearlyProduction": 7600, "batterySize": 10, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(23.96, (Decimal) responseMap.get('monthlyAdvPayment'));
        System.assertEquals(6750, (Decimal) responseMap.get('freeElectricity'));
        
    }
    
    static testMethod void scenarioN10() {
                
        String jsonMessage = '{ "energyConsumption": 6750, "yearlyProduction": 7600, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(0, (Decimal) responseMap.get('monthlyAdvPayment'));
        System.assertEquals(8000, (Decimal) responseMap.get('freeElectricity'));
        
    }
    
    static testMethod void scenarioN11() {
                
        String jsonMessage = '{ "energyConsumption": 7271, "yearlyProduction": 7600, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(0, (Decimal) responseMap.get('monthlyAdvPayment'));
        System.assertEquals(8000, (Decimal) responseMap.get('freeElectricity'));
        
    }
    
    static testMethod void scenarioN12() {
                
        String jsonMessage = '{ "energyConsumption": 7272, "yearlyProduction": 7600, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(0, (Decimal) responseMap.get('monthlyAdvPayment'));
        System.assertEquals(8000, (Decimal) responseMap.get('freeElectricity'));
        
    }
    
    static testMethod void scenarioN13() {
                
        String jsonMessage = '{ "energyConsumption": 7271, "yearlyProduction": 7500, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 8000', (String) responseMap.get('name'));
        System.assertEquals(7922, (Decimal) responseMap.get('freeElectricity'));
        System.assertEquals(0, (Decimal) responseMap.get('monthlyAdvPayment'));
        
    }
    
    static testMethod void scenarioN14() {
                    
        String jsonMessage = '{ "energyConsumption": 7272, "yearlyProduction": 7500, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 8000', (String) responseMap.get('name'));
        System.assertEquals(7922, (Decimal) responseMap.get('freeElectricity'));
        System.assertEquals(0, (Decimal) responseMap.get('monthlyAdvPayment'));
    }
    
   	static testMethod void scenarioN15() {
                    
        String jsonMessage = '{ "energyConsumption": 9600, "yearlyProduction": 7200, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 8000', (String) responseMap.get('name'));
        System.assertEquals(7688, (Decimal) responseMap.get('freeElectricity'));
        System.assertEquals(36.65, (Decimal) responseMap.get('monthlyAdvPayment'));
    }
    
    static testMethod void scenarioN16() {
                    
        String jsonMessage = '{ "energyConsumption": 6900, "yearlyProduction": 7200, "batterySize": 12, "nominalPower": 5.5 }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = URL.getSalesforceBaseUrl().toExternalForm() + '/services/apexrest/recommendTariff/v2';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonMessage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RecommendationTariffv5.recommendTariff();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('sonnenFlat 6750', (String) responseMap.get('name'));
        System.assertEquals(6438, (Decimal) responseMap.get('freeElectricity'));
        System.assertEquals(8.86, (Decimal) responseMap.get('monthlyAdvPayment'));
    } 
}