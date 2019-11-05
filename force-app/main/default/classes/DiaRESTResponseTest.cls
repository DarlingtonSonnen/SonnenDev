@isTest
private class DiaRESTResponseTest {

    static testMethod void createResponse() {
    
        List<Contact> contacts = new List<Contact>();        
        List<Account> accounts = new List<Account>();        
        
        contacts.add(new Contact(LastName = 'Test1'));
        contacts.add(new Contact(LastName = 'Test2'));        
        
        DiaRESTResponse response = new DiaRESTResponse('Contact');

        response.setObjects(contacts);
        response.setObjects(contacts, contacts.size());
        response.setObjects(contacts, contacts.size(), 1, 1);
        response.addDebug('Debug Test');
        response.setError('Error message', 'ERROR_CODE');
        
        System.assert(response.hasError());
        System.assert(response.getError() != NULL);
        
        response.addReferences('account', accounts);
        response.getReferences();
        
        response.getPagination();
        response.getObjects();
                                                   
        System.assertEquals(response.getStatus(), 'NOK');    

		// Set generic objects via List<Contact>       
        response.setGenericObjects(contacts);
		List<Map<String,String>> objectList = response.getGenericObjects();
        
        System.assertEquals(contacts.size(), objectList.size());
        System.assert(contacts.get(0).get('LastName') != NULL);
        
        // Set generic objects via Map
        response.setGenericObjects(objectList);        
    }
}