@RestResource (urlMapping='/recommendTariff/v2/*')
global without sharing class recommendationTariffv5 {

	@HttpPost
    global static void recommendTariff() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String jsonBody = req.requestBody.toString();

        Map<String, Object> desMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        // POST parameters
        Decimal energyConsumption = (Decimal) desMap.get('energyConsumption');  // Verbrauch
        Decimal yearlyProduction = (Decimal) desMap.get('yearlyProduction');   // Erzeugung pro Jahr
        Decimal batterySize = (Decimal) desMap.get('batterySize');
        Decimal nominalPower = (Decimal) desMap.get('nominalPower'); // max Leistung kWp

        // query custom metadata types for parameters
        WrSettings__mdt settings = [SELECT PriceBookName__c, Factor__c, sf8000Threshold__c, ProductsForRecommendation__c, Community8000ProductName__c,
                                    CommunityFlatProductName__c, Flex8000ProductName__c, FlexProductName__c
                                    FROM WrSettings__mdt WHERE Label = 'WRApi'];
        System.debug(settings.PriceBookName__c);
        // query pricebook entries
        List<PriceBookEntry> productList = [SELECT Id, Product2.Name, MinYearlyEnergyProduction__c, MaximalConsumption__c, Product2.AmountFreeEnergy__c,
                                            RecommendedBatteryCapacity2__c, ElectricityPrice__c, ElectricityPrice2000__c, Product2.StockKeepingUnit
                                            FROM PriceBookEntry WHERE Product2.Type__c = 'Electricity contract' AND Pricebook2.Name = :settings.PriceBookName__c 
                                            AND isActive = true AND Product2.IncludeInRecommendationLogic__c = true];

        System.debug(productList.size());
        // return variables
        String productName;
        Decimal freeElectricity;
        Decimal monthlyAdvPayment;

        // recommendation logic
        Map<Decimal, String> prodNameMap = new Map<Decimal, String>();
        Map<String, Decimal> minProdMap = new Map<String,Decimal>();
        Map<String, Decimal> freeElectricityMap = new Map<String, Decimal>();
        Map<String, Decimal> priceMap = new Map<String, Decimal>();
		Map<String, Decimal> price2000Map = new Map<String, Decimal>();
        
        for (PriceBookEntry  pbe : productList) {
            if (pbe.Product2.Name.contains('sonnenFlat')) {
                
                List<String> sList = pbe.RecommendedBatteryCapacity2__c.split(' ');
                Decimal size = Decimal.valueOf(sList[0]);
                
                String prodName = pbe.Product2.Name;
                prodNameMap.put(size, pbe.Product2.Name);
                minProdMap.put(prodName, (Decimal)pbe.MinYearlyEnergyProduction__c);
                freeElectricityMap.put(prodName, (Decimal) pbe.Product2.AmountFreeEnergy__c);
                priceMap.put(prodName, pbe.ElectricityPrice__c);
                price2000Map.put(prodName, pbe.ElectricityPrice2000__c);
                
                
                
            } else if (pbe.Product2.Name.contains('sonnenStrom plus')) {
                prodNameMap.put(0, pbe.Product2.Name);
            }
        }
        System.debug(prodNameMap);
        System.debug('nominalPower '+nominalPower);
        System.debug('yearlyProduction '+yearlyProduction);
        System.debug('batterySize '+batterySize);
        
        // create sku variables 
        String sonnenCommunity;
        String tariff;
		
        // find SKUs    
        List<String> prodNames = settings.ProductsForRecommendation__c.split(';');
        
        // query products for SKU data
        List<Product2> pList = [SELECT Id, Name, StockKeepingUnit FROM Product2 WHERE Name IN :prodNames AND StockKeepingUnit != null];
        
        Map<String, String> skuMap = new Map<String, String>();
        
        for (Product2 p : pList) {
            skuMap.put(p.Name, p.StockKeepingUnit);
        }
        System.debug('skuMap '+ skuMap);
        
        
        if (nominalPower >= 3 && yearlyProduction >= 2400 && batterySize >= 6) {
            productName = prodNameMap.get(batterySize);
            if (productName == null && batterySize > 12) {
                productName = prodNameMap.get(12);
            }
            
            // free Electricity calculation
            System.debug(minProdMap);
            System.debug(freeElectricityMap);
            Decimal minProduction = minProdMap.get(productName);
            Decimal maxFreeAllowance = freeElectricityMap.get(productName);
            FreeElectricityCalculation fec = new FreeElectricityCalculation(yearlyProduction, minProduction, maxFreeAllowance, settings.Factor__c);
            freeElectricity = fec.calculateAllowance();
            
            // monthly payments
            //MonthlyAdvancePayment monAdvPay = new MonthlyAdvancePayment(energyConsumption, freeElectricity, priceMap.get(productName), price2000Map.get(productName));
            //monthlyAdvPayment = monAdvPay.calculate();
            monthlyAdvPayment = MonthlyAdvancePayment.calculate(energyConsumption, freeElectricity, priceMap.get(productName), price2000Map.get(productName));
            System.debug('freeElectricity '+freeElectricity);
            // SKUs
            if (maxFreeAllowance > freeElectricity) {
                
                // flex SKUs - 
                if (productName == 'sonnenFlat 8000') {
                    FreeElectricityCalculation fec6750 = new FreeElectricityCalculation(yearlyProduction, minProdMap.get('sonnenFlat 6750'), freeElectricityMap.get('sonnenFlat 6750'), settings.Factor__c);
                    Decimal freeElectricity6750 = fec6750.calculateAllowance();          
					System.debug('freeElectricity6750 '+freeElectricity6750);					
                    
                    Decimal monthlyAdvPayment6750 = MonthlyAdvancePayment.calculate(energyConsumption, freeElectricity6750, priceMap.get('sonnenFlat 6750'), price2000Map.get('sonnenFlat 6750'));
                    System.debug('monthlyAdvPayment6750 '+monthlyAdvPayment6750);
					                    
                    if(monthlyAdvPayment6750 < 10) {
                        productName = 'sonnenFlat 6750';
                        freeElectricity = freeElectricity6750;
                        monthlyAdvPayment = monthlyAdvPayment6750;
                    }
                }
                
                if (freeElectricity <= 6750) {
                    tariff = skuMap.get(settings.FlexProductName__c);
                } else {
                    tariff = skuMap.get(settings.Flex8000ProductName__c);
                }       
            } else {
                // standard SKUs
                tariff = skuMap.get(productName);
            }
            if (productName == 'sonnenFlat 8000') {
                sonnenCommunity = skuMap.get(settings.Community8000ProductName__c);
            } else {
                sonnenCommunity = skuMap.get(settings.CommunityFlatProductName__c);
            }

        } else {
            productName = 'sonnenStrom plus';
            freeElectricity = 0;
            monthlyAdvPayment = 0;
            
            // sku
            tariff = skuMap.get(productName);
            sonnenCommunity = 'Not available';
        }
		        
        // for loop through productList
        // construct JSON array
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeFieldName('SKU');
        gen.writeStartObject();
        gen.writeStringField('community', sonnenCommunity);
        gen.writeStringField('tariff', tariff);
        gen.writeEndObject();
        gen.writeStringField('name', productName);
        gen.writeNumberField('freeElectricity', freeElectricity);
        gen.writeNumberField('monthlyAdvPayment', monthlyAdvPayment);
        gen.writeEndObject();

        String jsonRes = gen.getAsString();
        
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(jsonRes);
    }
}