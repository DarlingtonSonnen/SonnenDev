@isTest
private class DiaUtilitiesTest {
    
    static testMethod void testUtilities() {
        
        String email = 'test@test.de';
        Contact contact = new Contact(
            LastName = 'Bogus',
            Email = email 
        );        
        
        // Test stringValueOrNull()
        System.assertEquals(NULL, DiaUtilities.stringValueOrNull(contact, 'FirstName'));
        System.assertEquals(email, DiaUtilities.stringValueOrNull(contact, 'Email'));
        
        // Test isEmpty()
        System.assertEquals(TRUE, DiaUtilities.isEmpty(contact.Id));
        System.assertEquals(FALSE, DiaUtilities.isEmpty(contact.Email));
    
        // Test getClassName()
        System.assertEquals('Contact', DiaUtilities.getClassName(contact));        
        
        // Test getRecordTypeIdByObjectAndName()
        // Cannot really be tested as we cannot create recordTypes in tests
                
        // Test extractStreetNumber()
		Map<String,String> street = DiaUtilities.extractStreetNumber('Bogusstreet 14a');
        System.assertEquals('Bogusstreet', street.get('street'));                
        System.assertEquals('14a', street.get('number')); 
        
		street = DiaUtilities.extractStreetNumber('Voidpalace');
        System.assertEquals('Voidpalace', street.get('street'));                
        System.assertEquals('', street.get('number')); 
        
        // Test returnAllFieldsAsList()
        Set<String> fields = new Set<String>(DiaUtilities.returnAllFieldsAsList('Contact'));
        System.debug(fields);
        System.assert(fields.contains('name'));
        
        // Test returnAllFieldsAsString()
        String fieldsAsString = DiaUtilities.returnAllFieldsAsString('Contact');
        System.assert(fieldsAsString.length() > 0);
        
        // Test returnSelectAllQuery()
        String query = DiaUtilities.returnSelectAllQuery('Contact');
        System.assert(query.length() > 0);
        
        // Test generateRandomString()
        String randomString = DiaUtilities.generateRandomString(20);
        System.assert(randomString.length() == 20);
        
        // Test getRandomNumber()
        Integer randomNumber = DiaUtilities.generateRandomNumber(5);
        System.assert((randomNumber > 0 && randomNumber < 100000), 'Number is not in range 1-100000: ' + randomNumber);
        
        // Test generateRandomString()
        String paddedString = DiaUtilities.padWithZero(String.valueOf(20), 4);
        System.assertEquals('0020', paddedString);

        // Test orgIsSandbox()
        DiaUtilities.orgIsSandbox();
        DiaUtilities.orgIsSandbox(TRUE);

        // Test getObjectValuesAsMap()
        Map<String,String> mapValues = DiaUtilities.getObjectValuesAsMap(contact);
        System.assertEquals(contact.Email, mapValues.get('Email'));

        // Test getRecordTypeMap()
        DiaUtilities.getRecordTypeMap(new List<String>{'Account', 'Contact'});

        // Test getRecordTypeIdByObjectAndName()
        DiaUtilities.getRecordTypeIdByObjectAndName('Account', 'PersonAccount');
    }        
}