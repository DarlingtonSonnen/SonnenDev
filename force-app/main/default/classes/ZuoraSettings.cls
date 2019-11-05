/**
 * Created by b.jarmolinski on 24/09/2018.
 *
 * the class contains method which returns zuora custom metadata
 */

public without sharing class ZuoraSettings {

    public static ZuoraSetting__mdt getZuoraSetting() {
        // the method queries and returns all fields within the zuora setting custom metadata type

        SObjectType baType = Schema.getGlobalDescribe().get('ZuoraSetting__mdt');
        Map<String,Schema.SObjectField> mfields = baType.getDescribe().fields.getMap();

        // create a list of all fields in the zuoraSetting__mdt
        List<String> sList = new List<String>();
        for (Schema.SObjectField s : mfields.values()) {
            sList.add(s.getDescribe().getName());
        }

        // create a string for SOQL query by concatenating field names
        String queryString;
        for (Integer i=0; i < sList.size(); i++) {
            if (i == 0) {
                queryString = sList[0] + ', ';
            } else if (i < sList.size() - 1) {
                queryString = queryString + sList[i] + ', ';
            } else {
                queryString = queryString + sList[i] + ' ';
            }
        }

        // query the settings and return the object
        zuoraSetting__mdt settings;
        // 00D24000000opic is org Id of sonnen  Live org / production
        if(UserInfo.getOrganizationId() != '00D24000000opic' && UserInfo.getOrganizationId() != '00D24000000opicEAA' ) {

            queryString = 'SELECT ' + queryString + 'FROM ZuoraSetting__mdt WHERE Label = \'Sandbox\'';
        } else {
            queryString = 'SELECT ' + queryString + 'FROM ZuoraSetting__mdt WHERE Label = \'Prod\'';
        }

        settings = DataBase.query(queryString);
        System.debug(settings);
        return settings;
    }
}