/*
* Author: Bartosz Jarmolinski

* The class includes product recommendation logic - sonnenFlat contract and matching battery
* parameters: consumption (per year), maxLeistung (peak power of the PV which can be installed), stromertag (yearly electricity production), 
* the method returns JSON string which contains recommended electricity contract together with battery as well as other available products
*
* Update 19/11/2018
* - added 'settings.RecommendedBatteryFamily__c != settings.BatteryFamilyOnProducts__c' to else if clause flagging products as recommended
* Update 16/11/2018
* - Added fields ProductSizeTranslations__c and BatteryFamilyOnProducts__c fields to custom metadata query settings
*   Added map creation batterySizeMap - to accommodate situation when different battery family is recommended via WR and
*   different battery size recommendations are saved on products (price book entries)
* - Added else if (bttSize == batterySizeMap.get(recSizeS) && p.Product2.Family == settings.RecommendedBatteryFamily__c)
*
* Update 15/11/2018
* Change recSize from Integer to Decimal to accommodate LFP2 battery sizes which are decimals
*
* Update 27/06/2018
* Replaced battery sizes from Integers to Decimals (Map batterySizeInt)
* 
* Update 20/02/2018
* Added query for field MinYearlyEnergyProduction__c, modified energy allowance calculation to include MinYearlyEnergyProduction in the calculation
*
*/

public with sharing class suggestProduct7 {
    public String suggestProduct(Integer consumption, Decimal maxLeistung, Decimal stromertrag, Decimal pvErzeugung) {

        WrSettings__mdt settings = [SELECT PriceBookName__c, RecommendedBatteryFamily__c, BatteryFamilyOnProducts__c,
                                    ProductSizeTranslations__c
                                    FROM WrSettings__mdt WHERE MasterLabel = 'WRApi'];

        List<PricebookEntry> productList; // list of products with prices which will be returned as suggested products
        //Pricebook entry and not products because the latter does not contain unit price

        List<PriceBookEntry> tarifs = new List<PriceBookEntry>(); // list of tariff products
        List<PriceBookEntry> batteries = new List<PriceBookEntry>(); // list of battery products
        Map<String, PriceBookEntry> batteryRecommend = new Map<String, PriceBookEntry>(); // map of sonnenFlat name and recommened battery
        Map<String, PriceBookEntry> batterySize = new Map<String, PriceBookEntry>(); // map of battery size in kWh and corresponding price book record
        Map<Decimal, PriceBookEntry> batterySizeInt = new Map<Decimal, PriceBookEntry>(); // map of battery size and corresponding price book, with key stripped to integer
        Map<Id, PriceBookEntry> batteryAllMap = new Map<Id, PriceBookEntry>(); // map of all batteries and their IDs
        Set<String> recommendedBatterySizes = new Set<String>(); // set of battery sizes which are recommended for the tariffs

        String sonnenFlatTarif;  // name of suggested sonnenFlat
        String batteryCapacity;  // capacity of the battery recommened for the sonnenFlat

        Decimal freeElectricityCalc; // calculated as per recommendation logic
        Map<String, Decimal> freeElectricityMap; // calculated free electricity for each tariff

        // query batteries and sonnenFlat contracts from the sonnen sales DE price book - price book logic to be reviewed in the future if
        // further countries or different groups of partners are to be included.
        productList = [SELECT id, Name, Product2.Name, UnitPrice, Product2.AmountFreeEnergy__c, Product2.MaxConsumption__c, Product2.MinConsumption__c,
                Product2.ContractRunningTime__c, Product2.ContractRenewalTime__c, ElectricityPrice__c, ElectricityPrice2000__c, Product2.Type__c,
                Product2.ProductSize__c, Product2.DeductionForEachKWpInKWh__c, Product2.MinBatteryCapacity__c, MinYearlyEnergyProduction__c, Product2.MinPVSize__c,
                RecommendedMaximalConsumption__c, RecommendedMinimalConsumption__c, MaximalConsumption__c, RecommendedBatteryCapacity2__c, Product2.Family
                FROM PricebookEntry WHERE Pricebook2.Name = :settings.PriceBookName__c AND Product2.IncludeInWirtschaflichkeitsrechner__c = true AND
                (Product2.Type__c != 'Electricity contract' OR MaximalConsumption__c >= :consumption) AND
                (Product2.Type__c = 'Electricity contract' OR Product2.Type__c = 'Battery') AND IsActive = true ORDER BY Product2.Type__c DESC];

        // construct list of tarifs (electricity contract products) only
        for(PriceBookEntry pbe : productList){
            if(pbe.Product2.Type__c == 'Electricity contract') {
                tarifs.add(pbe);
                recommendedBatterySizes.add(pbe.RecommendedBatteryCapacity2__c);
            }
            else if(pbe.Product2.Type__c == 'Battery') {
                batteries.add(pbe);
                batterySize.put(pbe.Product2.ProductSize__c, pbe);
                // pbe.Product2.ProductSize__c is a string - needs to be splitted. First element of the split is always a number of kWh, which then is converted into Integer
                List<String> ls = pbe.Product2.ProductSize__c.split(' ');
                Decimal size = Decimal.valueOf(ls[0]);
                batterySizeInt.put(size, pbe);
            }
        }
        System.debug('batterySize: '+batterySize);

        // recommendation logic 2.0 - find recommended tarif based on parameters in the if conditions and assign to recommened-variables
        for(PriceBookEntry pbe : tarifs) {
            if(consumption <= pbe.MaximalConsumption__c && consumption >= pbe.RecommendedMinimalConsumption__c && consumption <= pbe.RecommendedMaximalConsumption__c) {
                sonnenFlatTarif = pbe.Name;
                batteryCapacity = pbe.RecommendedBatteryCapacity2__c;
            }
            batteryRecommend.put(pbe.Name, batterySize.get(pbe.RecommendedBatteryCapacity2__c));
        }
        System.debug('batteryRecommend: '+batteryRecommend);

//        //get custom metadata type WRAllowance where parameters for calculating free enegry allowance are stored
//        List<WRAllowance__mdt> wr = [SELECT Label, maxOutput__c FROM WRAllowance__mdt];
//        Map<String, Decimal> allowanceMap = new Map<String, Decimal>();
//        for(WRAllowance__mdt a : wr) {
//            allowanceMap.put(a.Label, a.maxOutput__c);
//        }
        // adjust battery sizes if different product family is displayed on the product and via WR
        Map<String, Decimal> batterySizeMap = (Map<String, Decimal>) JSON.deserialize(settings.ProductSizeTranslations__c, Map<String, Decimal>.class);

        //contruct JSON string with the recommended products and other products which will be returned as response
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeFieldName('RecommendedProducts');
        gen.writeStartArray();
        for(PricebookEntry pbe : tarifs){
            gen.writeStartObject();
            gen.writeStringField('Id', pbe.Id);
            if(pbe.Name == sonnenFlatTarif) {
                gen.writeBooleanField('Recommended', true);
            }
            else {
                gen.writeBooleanField('Recommended', false);
            }
            gen.writeStringField('Name', pbe.Name);
            gen.writeNumberField('ContractRunningTime', pbe.Product2.ContractRunningTime__c);
            gen.writeNumberField('ContractRenewalTime', pbe.Product2.ContractRenewalTime__c);
            gen.writeNumberField('CommunityChargePerMonth', pbe.UnitPrice);
            gen.writeStringField('ProductType', pbe.Product2.Type__c);


            //** free allowance calculation 2.0
            if (stromertrag > pbe.MinYearlyEnergyProduction__c) {
                gen.writeNumberField('FreeElectricitySupply', pbe.Product2.AmountFreeEnergy__c);
            } else if (maxLeistung < 3 || stromertrag < 2400){
                JSONGenerator gen1 = JSON.createGenerator(true);
                gen1.writeStartObject();
                gen1.writeStringField('Error', 'KWp must be greater than 3.0 and electricity production must be greater than 2400 KWh');
                gen1.writeEndObject();
                String err = gen1.getAsString();
                return err;
            }
            else {
                Decimal allowance = pbe.Product2.AmountFreeEnergy__c - (pbe.MinYearlyEnergyProduction__c - stromertrag)*((Decimal)625/800);
                allowance = allowance.setScale(0);
                System.debug(pbe.Product2.AmountFreeEnergy__c);
                System.debug(pbe.MinYearlyEnergyProduction__c);
                System.debug(stromertrag);
                System.debug(allowance);

                gen.writeNumberField('FreeElectricitySupply', allowance);
            }
            //**

            gen.writeNumberField('ElectricityPrice', pbe.ElectricityPrice__c);
            gen.writeNumberField('ElectricityPrice2000', pbe.ElectricityPrice2000__c);

            gen.writeFieldName('Batteries');
            gen.writeStartArray();

            String recSizeS = pbe.RecommendedBatteryCapacity2__c.split(' ')[0];

            Decimal recSize = Decimal.valueOf(recSizeS);
            for (PriceBookEntry p : batteries) {
                //Integer bttSize = Integer.valueOf(p.Product2.ProductSize__c.split(' ')[0]);
                Decimal bttSize = Decimal.valueOf(p.Product2.ProductSize__c.split(' ')[0]);
                if (bttSize >= recSize) {
                    gen.writeStartObject();
                    gen.writeStringField('Id', p.Id);
                    gen.writeStringField('Name', p.Product2.Name);
                    
                    System.debug(settings.RecommendedBatteryFamily__c);
                    System.debug(settings.BatteryFamilyOnProducts__c);

                    if (bttSize == recSize && p.Product2.Family == settings.RecommendedBatteryFamily__c &&
                            settings.RecommendedBatteryFamily__c == settings.BatteryFamilyOnProducts__c) {
                        gen.writeBooleanField('Recommended', true);
                    } else if (bttSize == batterySizeMap.get(recSizeS) && p.Product2.Family == settings.RecommendedBatteryFamily__c &&
                            settings.RecommendedBatteryFamily__c != settings.BatteryFamilyOnProducts__c) {
                        gen.writeBooleanField('Recommended', true);
                    } else {
                        gen.writeBooleanField('Recommended', false);
                    }
                    gen.writeEndObject();
                }
            }

            gen.writeEndArray();
            gen.writeEndObject();
        }
        gen.writeEndArray();
        gen.writeEndObject();

        String jsonResponse = gen.getAsString();
        System.debug(jsonResponse);

        return jsonResponse;
    }
}