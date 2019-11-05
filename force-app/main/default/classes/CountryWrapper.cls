/*
* created by Bartosz Jarmolinski on 11/06/2018
* The class returns a map of possible ways a country can be written and returns a map transalting that value to a German name - as accepted by 
* country picklist in the sonnen Salesforce org
*
* V2.0
* - added method CounvertCountryIso
*/

public class CountryWrapper {
    
    public static Map<String, String> ConvertCountry() {
        // returns country in German

        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'CountryDecoder'];
		String srBody = sr.Body.toString(); 
        Map<String, String> returnMap = (Map<String, String>) JSON.deserialize(srBody, Map<String, String>.class);
        return returnMap;
    }

    public static Map<String, String> ConvertCountryIso() {
        //return country Iso COde

        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'CountryDecoderIso'];
        String srBody = sr.Body.toString();
        Map<String, String> returnMap = (Map<String, String>) JSON.deserialize(srBody, Map<String, String>.class);
        return returnMap;
    }
}