/**
 * Created by m.muchow on 24.07.2019.
 */

public without sharing class BoCEndpoint {

    public static Map<String, Object> checkAndCreateCustomer(Map<String, Object> mBoCRequestMap, String sBoCJson) {

        System.debug('map Endpoint '+mBoCRequestMap);

        // get Account Record Type Id for Partner Accounts
        Id aPartnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('SBC').getRecordTypeId();

        // initialize Objects & Lists
        Opportunity newOpportunity = new Opportunity();
        List<Account> pAccountList = new List<Account>();
        List<User> pUserIdList = new List<User>();
        List<Contact> pContactList = new List<Contact>();

        // initialize Maps
        Map<String, Object> mAccountMap = new Map<String, Object>();
        Map<String, Object> mOpportunityMap = new Map<String, Object>();
        Map<String, Object> mBillingMap = new Map<String, Object>();
        Map<String, Object> mShippingMap = new Map<String, Object>();
        Map<String, Object> mResponseMap = new Map<String, Object>();

        // initialize Sets for closed Opportunity stages
        Set<String> oppStagesSet = new Set<String>();

        List<OpportunityStage> oppStages = [SELECT ApiName FROM OpportunityStage WHERE (IsClosed = TRUE OR IsWon = TRUE) AND IsActive = TRUE];

        for (OpportunityStage stage : oppStages) {
            oppStagesSet.add(String.valueOf(stage.ApiName));
        }

        // get RecordTypeId for Opportunity
        Id oppRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('SalesSolutionPartnerPortal').getRecordTypeId();

        // fill Account, Opportunity and Address Maps
        mAccountMap = (Map<String, Object>) mBoCRequestMap.get('account');
        mOpportunityMap = (Map<String, Object>) mBoCRequestMap.get('opportunity');
        mBillingMap = (Map<String, Object>) mAccountMap.get('invoice_address');
        mShippingMap = (Map<String, Object>) mAccountMap.get('delivery_address');

        // initialize while loop to break if a error appears
        while(true) {
            // check if partner Id is in request
            if ((String) mOpportunityMap.get('partner_id') == null || (String) mOpportunityMap.get('partner_id') == '') {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' => 'Partner Id is missing', 'code' => 'MISSING_PARTNER_ID', 'httpStatusCode' => 401});
                break;
            }
            // get Partner Account Information
            pAccountList = [SELECT Id FROM Account WHERE Id =: (String) mOpportunityMap.get('partner_id') AND RecordTypeId =: aPartnerRecordTypeId LIMIT 1];
            // check if partner is found by Id from request
            if (pAccountList.isEmpty()) {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' => 'No matching Partner found', 'code' => 'NO_PARTNER', 'httpStatusCode' => 401});
                break;
            }
            // check if user/owner/contact Id is in request
            if (((String) mOpportunityMap.get('user_id') == null || (String) mOpportunityMap.get('user_id') == '') && ((String) mOpportunityMap.get('contact_id') == null || (String) mOpportunityMap.get('contact_id') == '')) {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' => 'User or Contact Id is missing', 'code' => 'MISSING_USER_OR_CONTACT_ID', 'httpStatusCode' => 401});
                break;
            }
            // get User Information
            if ((String) mOpportunityMap.get('user_id') != '') {
                pUserIdList = [SELECT Id, Profile.UserLicense.Name, IsActive, ContactId FROM User WHERE Id =: (String) mOpportunityMap.get('user_id') AND Profile.UserLicense.Name = 'Partner Community' LIMIT 1];
            }
            if (!pUserIdList.isEmpty()) {
                // get Contact Information and check if Contact of User is related to Account Id
                pContactList = [SELECT Id FROM Contact WHERE Id =: pUserIdList[0].ContactId AND AccountId =: (String) mOpportunityMap.get('partner_id') LIMIT 1];
            } else {
                pContactList = [SELECT Id FROM Contact WHERE Id =: (String) mOpportunityMap.get('contact_id') AND AccountId =: (String) mOpportunityMap.get('partner_id') LIMIT 1];
            }
            if (pContactList.isEmpty() && (String) mOpportunityMap.get('user_id') != '') {
                Id contactId = [SELECT ContactId FROM User WHERE Id =: (String) mOpportunityMap.get('user_id') LIMIT 1].ContactId;
                pContactList = [SELECT Id FROM Contact WHERE Id =: contactId AND AccountId =: (String) mOpportunityMap.get('partner_id') LIMIT 1];
            }
            if (pContactList.isEmpty()) {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' => 'Contact is not related to Partner Account', 'code' => 'CONTACT_NOT_RELATED', 'httpStatusCode' => 401});
                break;
            } else if (!pUserIdList.isEmpty() && !pUserIdList[0].IsActive){
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' =>'User is not active', 'code' => 'NO_ACTIVE_USER', 'httpStatusCode' => 401});
                break;
            }

            // create Opportunity based on Request Map
            newOpportunity = new Opportunity();
            newOpportunity.RecordTypeId = oppRecordTypeId;
            newOpportunity.StageName = 'Open';
            newOpportunity.Name = (String) mAccountMap.get('first_name')+' '+(String) mAccountMap.get('last_name');
            newOpportunity.ProposedSBC__c = (String) mOpportunityMap.get('partner_id');
            newOpportunity.AcceptedByPartner__c = (Boolean) mOpportunityMap.get('accepted_by_partner');
            newOpportunity.AcceptedByPartnerDate__c = System.today();
            newOpportunity.CloseDate = System.today().addMonths(3);
            if (!pUserIdList.isEmpty()) {
                newOpportunity.OwnerId = pUserIdList[0].Id;
            }
            newOpportunity.PartnerContact__c = pContactList[0].Id;
            newOpportunity.Company__c = (String) mAccountMap.get('company');
            newOpportunity.Salutation__c = (String) mAccountMap.get('salutation');
            newOpportunity.FirstName__c = (String) mAccountMap.get('first_name');
            newOpportunity.LastName__c = (String) mAccountMap.get('last_name');
            newOpportunity.BillingStreet__c = (String) mBillingMap.get('street');
            // StreetNumber is merge in the street information in the request
            //newOpportunity.BillingStreetNo__c = (String) mBillingMap.get('streetNumber');
            newOpportunity.BillingPostalCode__c = (String) mBillingMap.get('zip_code');
            newOpportunity.BillingCity__c = (String) mBillingMap.get('city');
            newOpportunity.BillingCountryIsoCode__c = (String) mBillingMap.get('country');
            // State information are tricky because of different iso codes
            //newOpportunity.BillingState__c = (String) mBillingMap.get('state');

            newOpportunity.ShippingCompany__c = (String)mAccountMap.get('company');
            newOpportunity.ShippingSalutation__c = (String) mAccountMap.get('salutation'); // Text
            newOpportunity.ShippingSalutation2__c = (String) mAccountMap.get('salutation'); // Picklist
            newOpportunity.ShippingFirstName__c = (String) mAccountMap.get('firstName');
            newOpportunity.ShippingLastName__c = (String )mAccountMap.get('lastName');
            newOpportunity.ShippingStreet__c = (String) mShippingMap.get('street');
            // StreetNumber is merge in the street information in the request
            //newOpportunity.ShippingStreetNo__c  = (String) mShippingMap.get('streetNumber');
            newOpportunity.ShippingPostalCode__c = (String) mShippingMap.get('zip_code');
            newOpportunity.ShippingCity__c = (String) mShippingMap.get('city');
            newOpportunity.ShippingCountryIsoCode__c = (String) mShippingMap.get('country');
            // State information are tricky because of different iso codes
            //newOpportunity.ShippingState__c = (String) mShippingMap.get('state');

            newOpportunity.Email__c = (String) mAccountMap.get('email');

            // call duplicate check
            DuplicateCheckHandlerv3 bocDuplicateCheckHandler = new DuplicateCheckHandlerv3(new List<Opportunity> {newOpportunity});
            Map<Id, Map<String, Id>> duplicateIdMap = bocDuplicateCheckHandler.handleObjectsv2();

            // set Ids from Account and Contact from Duplicate Check
            Id accountId = duplicateIdMap.get(newOpportunity.Id).get('Account');
            Id contactId = duplicateIdMap.get(newOpportunity.Id).get('Contact');

            // link Opportunity to Account & Contact
            newOpportunity.AccountId = accountId;
            newOpportunity.ContactId = contactId;

            // call Method to update Account and Contact from Duplicate Check
            Account updatedAccount = updateAccount(accountId, mAccountMap);
            Contact updatedContact = updateContact(contactId, mAccountMap, mBillingMap);

            // check if there is already an open Opportunity for this Customer and Partner
            List<Opportunity> oppToAccList = [SELECT Id, StageName FROM Opportunity WHERE AccountId =: accountId AND StageName NOT IN: oppStagesSet AND ProposedSBC__c =: (String) mOpportunityMap.get('partner_id') AND RecordTypeId =: oppRecordTypeId];
            // if no open Opportunity is present update Account and Contact and insert the Opportunity
            // call method to remove not needed fields/information of the Sobject for the response
            if (oppToAccList.isEmpty()) {
                try {
                    update updatedAccount;
                    update updatedContact;
                    insert newOpportunity;
                    mResponseMap.put('Account', removeFields(updatedAccount));
                    mResponseMap.put('Contact', removeFields(updatedContact));
                    mResponseMap.put('Opportunity', removeFields(newOpportunity));
                // if an error occurs during the update, insert or removal set up an error and debug response
                } catch (Exception e) {
                    mResponseMap.put('Error', new Map<String, Object>{'errorMessage' =>'Bad Request - See Debug', 'code' => 'BAD_REQUEST', 'httpStatusCode' => 400});
                    mResponseMap.put('Debug', e.getTypeName() + ': ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
                }
            // if an open Opportunity is present set up an error and an object response
            } else {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' =>'Already an open Opportunity present, no new Opportunity created', 'code' => 'OPPORTUNITY_PRESENT', 'httpStatusCode' => 400});
                mResponseMap.put('Account', removeFields(updatedAccount));
                mResponseMap.put('Opportunity', oppToAccList[0]);
                mResponseMap.put('Contact', removeFields(updatedContact));
            }
            break;
        }
        // return the response to the endpoint
        return mResponseMap;
    }


    public static Map<String, Object> createOffer(Map<String, Object> mBoCRequestMap, String sBocJson) {

        // initialize Maps
        Map<String, Object> mResponseMap = new Map<String, Object>();
        Map<String, Object> mTypeMap = new Map<String, Object>();

        // initialize Objects & Lists
        List<Opportunity> updateOpportunityList;

        // initialize Sets for closed Opportunity stages
        Set<String> oppStagesSet = new Set<String>();

        List<OpportunityStage> oppStages = [SELECT ApiName FROM OpportunityStage WHERE (IsClosed = TRUE OR IsWon = TRUE) AND IsActive = TRUE];

        for (OpportunityStage stage : oppStages) {
            oppStagesSet.add(String.valueOf(stage.ApiName));
        }

        // initialize while loop to break if a error appears
        while(true) {
            // get Opportunity based on given Id from request
            updateOpportunityList = [SELECT Id, CustomerGuidanceURL__c, StageName, SendOfferEmail__c FROM Opportunity WHERE Id =: (String) mBoCRequestMap.get('opportunity_id') AND StageName NOT IN: oppStagesSet LIMIT 1];
            // check ...
            if (updateOpportunityList.isEmpty()) {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' =>'No open Opportunity found for given Id', 'code' => 'NO_OPEN_OPPORTUNITY', 'httpStatusCode' => 400});
                break;
            }
            if (String.isBlank(updateOpportunityList[0].CustomerGuidanceURL__c)) {
                updateOpportunityList[0].CustomerGuidanceURL__c = (String) mBoCRequestMap.get('customer_guidance_url');
            }
            if (updateOpportunityList[0].StageName == 'Open' || updateOpportunityList[0].StageName == 'On-site visit done') {
                updateOpportunityList[0].StageName = 'Offer Sent';
            }
            updateOpportunityList[0].ConfigurationURL__c = (String) mBoCRequestMap.get('configuration_url');
            if (updateOpportunityList[0].SendOfferEmail__c == false) {
                updateOpportunityList[0].SendOfferEmail__c = true;
            }

            try {
                update updateOpportunityList;
                mResponseMap.put('Opportunity', removeFields(updateOpportunityList[0]));
            } catch (Exception e) {
                mResponseMap.put('Error', new Map<String, Object>{'errorMessage' => 'Bad Request - See Debug', 'code' => 'BAD_REQUEST', 'httpStatusCode' => 400});
                mResponseMap.put('Debug', e.getTypeName() + ': ' + e.getMessage() + ' (' + e.getStackTraceString() + ')');
            }
            break;
        }
        // return the response to the endpoint
        return mResponseMap;
    }

    /**
     * helper methods
     */
    // method to remove not needed information for the response
    private static SObject removeFields(SObject sObj) {
        // create map based on SObject from callout
        Map<String, Object> sobjectMap = new Map<String, Object>(sObj.getPopulatedFieldsAsMap());

        // initialize sets which field information should be left
        Set<String> accKeys = new Set<String>{'Id', 'CustomerNo__c'};
        Set<String> oppKeys = new Set<String>{'Id', 'StageName'};
        Set<String> conKeys = new Set<String>{'Id'};

        // for different types of SObjects loop trough the map and remove fields not in the related set
        // rebuild SObject after loop
        if (String.valueOf(sObj.getSObjectType()) == 'Account') {
            for (String key : sobjectMap.keySet()) {
                if (!accKeys.contains(key)) {
                    sobjectMap.remove(key);
                }
            }
            sObj = (Account) JSON.deserialize(JSON.serialize(sobjectMap), Account.class);
        } else if (String.valueOf(sObj.getSObjectType()) == 'Opportunity') {
            for (String key : sobjectMap.keySet()) {
                if (!oppKeys.contains(key)) {
                    sobjectMap.remove(key);
                }
            }
            sObj = (Opportunity) JSON.deserialize(JSON.serialize(sobjectMap), Opportunity.class);
        } else if (String.valueOf(sObj.getSObjectType()) == 'Contact') {
            for (String key : sobjectMap.keySet()) {
                if (!conKeys.contains(key)) {
                    sobjectMap.remove(key);
                }
            }
            sObj = (Contact) JSON.deserialize(JSON.serialize(sobjectMap), Contact.class);
        }
        // return cleared SObject
        return sObj;
    }

    // method to update the Account given by the duplicate check with further data from request
    private static Account updateAccount(Id accountId, Map<String, Object> mAccountMap) {
        Account updateAccount = [SELECT Id, AccountEmail__c, CustomerNo__c, Phone FROM Account WHERE Id =: accountId LIMIT 1];

        if (((String) mAccountMap.get('Company') != null || (String) mAccountMap.get('Company') != '') && (Boolean) mAccountMap.get('is_business')) {
            if (updateAccount.AccountEmail__c == null || updateAccount.AccountEmail__c == '') {
                updateAccount.AccountEmail__c = (String) mAccountMap.get('email');
            }
        }

        if (updateAccount.Phone == null) {
            updateAccount.Phone = (String) mAccountMap.get('phone');
        }
        return updateAccount;
    }

    // method to update the Contact given by the duplicate check with further data from request
    private static Contact updateContact(Id contactId, Map<String, Object> mContactMap, Map<String, Object> mBillingMap) {

        // get Static Resource to map country code to language code
        StaticResource countryLanguageISOResource = [SELECT Body FROM StaticResource WHERE Name = 'CountryLanguageISO' LIMIT 1];
        Map<String, Object> isoMap = (Map<String, Object>) JSON.deserializeUntyped(countryLanguageISOResource.Body.toString());

        Contact updateContact = [SELECT Id, Phone, MobilePhone, LeadSource, AcademicTitle__c, DoubleOptIn__c, DoubleOptInDate__c, RecordTypeId, Language__c FROM Contact WHERE Id =: contactId LIMIT 1];

        if (((String) mContactMap.get('Company') != null || (String) mContactMap.get('Company') != '') && (Boolean) mContactMap.get('is_business')) {
            Id conRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Standard').getRecordTypeId();
            if (updateContact.RecordTypeId == null) {
                updateContact.RecordTypeId = conRecordTypeId;
            }
        }

        if (updateContact.Language__c == null) {
            updateContact.Language__c = (String) isoMap.get((String) mBillingMap.get('country'));
        }

        if (updateContact.Phone == null) {
            updateContact.Phone = (String) mContactMap.get('phone');
        }

        if (updateContact.MobilePhone == null) {
            updateContact.MobilePhone = (String) mContactMap.get('mobile_phone');
        }

        if (updateContact.LeadSource == null) {
            updateContact.LeadSource = (String) mContactMap.get('lead_source');
        }

        if (updateContact.AcademicTitle__c == null) {
            updateContact.AcademicTitle__c = (String) mContactMap.get('title');
        }

        if (updateContact.DoubleOptIn__c == false) {
            updateContact.DoubleOptIn__c = (Boolean) mContactMap.get('agreed_to_gdpr');
            updateContact.DoubleOptInDate__c = System.today();
        }

        return updateContact;
    }
}