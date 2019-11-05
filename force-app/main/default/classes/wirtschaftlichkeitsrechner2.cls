/*
- Rest endpoint for Wirtschaftlichkeitsrechner App. 
- Author: Bartosz Jarmolinski
- parameters: consumption, maxLeistung, pvErzeugung, stromvertrag - all to be included in JSON Payload and cannot be null - validation on the website
- the class invokes another class: suggestProduct, where product recommendation logic is included
- the return element of the suggestProduct class is then passed as response to the original external callout from the app.
***
* CHANGES
* - 21/06/2018 - changed suggestProduct class version to 9
*/



@RestResource(urlMapping='/calculator2')
global with sharing class wirtschaftlichkeitsrechner2  {

    @HttpPost
    global static String method1() {

        // parameters to be received as REST request body
        Integer consumption;
        Decimal maxLeistung;
        Decimal pvErzeugung;
        Decimal stromertrag;

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String jsonInput = req.requestBody.toString();
        System.debug(jsonInput);

        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(jsonInput);
        System.debug(m);

        ID accountId = (Id) m.get('accountId');
        if(m.get('electricityConsumption') != null) {
            consumption = (Integer) m.get('electricityConsumption');
        }
        if(m.get('maxLeistung') != null) {
            maxLeistung = (Decimal) m.get('maxLeistung');
        }
        if(m.get('PVErzeugung') != null) {
            pvErzeugung = (Decimal) m.get('PVErzeugung');
        }
        if(m.get('Stromertrag') != null) {
            stromertrag = (Decimal) m.get('Stromertrag');
        }

        System.debug('consumption: '+consumption);
        System.debug('max Leistung: '+maxLeistung);
        System.debug('pvErzeugung: '+pvErzeugung);
        System.debug('Stromertrag: '+stromertrag);
    
        //call recommendation logic and get suggested products in JSON string format
        //suggestProduct9 sp = new suggestProduct9();
        //String jsonResponse = sp.suggestProduct(consumption, maxLeistung, stromertrag, pvErzeugung);
        
        suggestProduct7 sp = new suggestProduct7();
        String jsonResponse = sp.suggestProduct(consumption, maxLeistung, stromertrag, pvErzeugung);
        
        System.debug(jsonResponse);
        
        return jsonResponse;

    }

}