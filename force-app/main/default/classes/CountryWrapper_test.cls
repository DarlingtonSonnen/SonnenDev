@isTest
public class CountryWrapper_test {
	
    @isTest
    public static void test1() {
        
        StaticResource CountryDecoder = new StaticResource();
        
        String resourceBody = '{ "Germany": "Deutschland", "DE" : "Deutschland", "Deutschland": "Deutschland", "Austria" : "Österreich", "Oesterreich": "Österreich", "AT": "Österreich", "Österreich": "Österreich", "Switzerland": "Schweiz", "Schweiz": "Schweiz", "CH": "Schweiz", "IT": "Italien", "Italy": "Italien", "Italien": "Italien", "USA": "USA", "US": "USA", "Vereinigte Staaten": "USA", "die Vereinigten Staaten": "USA", "Australia": "Australien", "AU": "Australien" }';
        CountryDecoder.Body = Blob.valueOf(resourceBody);
        CountryDecoder.ContentType = 'text/plain';
        
        System.assertEquals('Deutschland', CountryWrapper.ConvertCountry().get('DE'));
    }

    @isTest
    public static void test2() {

        StaticResource CountryDecoder = new StaticResource();

        String resourceBody = '{ "Germany": "DE", "DE" : "DE", "Deutschland": "DE", "Austria" : "AT", "Oesterreich": "AT", "AT": "AT", "Österreich": "AT", "Switzerland": "CH", "Schweiz": "CH", "CH": "CH", "IT": "IT", "Italy": "IT", "Italien": "IT", "USA": "US", "US": "US", "Vereinigte Staaten": "US", "die Vereinigten Staaten": "US", "Australia": "AU", "AU": "AU" }';
        CountryDecoder.Body = Blob.valueOf(resourceBody);
        CountryDecoder.ContentType = 'text/plain';

        System.assertEquals('DE', CountryWrapper.ConvertCountryIso().get('Deutschland'));
    }
}