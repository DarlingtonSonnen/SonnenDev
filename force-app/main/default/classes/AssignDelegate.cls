/**
 * AssignDelegate
 *
 * Delegate to propose
 * - Area Managers (Users) and
 * - Partners (Accounts)
 * according to their geolocation or entries in PostalCodeArea__c
 *
 * Changelog
 * ---------
 *
 * 1.1.1 (2017-03-24)
 * - SOBCRM-908 - Partner mit dem Status__c "inactive" sollen ausgeschlossen werden.
 * 		- proposePartnerAccounts query filter modified
 * 
 * 1.1.0 (2016-11-23)
 * - proposePartnerAccount() (SOBCRM-681)
 *      - now returns the best 5 matches instead of only the first.
 *        This way the result can be use in other classes to show the proposals.
 *      - now provides further information like street and countryCode
 *
 * 1.0.2 (2016-11-15)
 * - Fix: Switched from PostalCodeArea__c.AreaManager__c to PostalCodeArea__c.OwnerId
 *
 * 1.0.1 (2016-10-13)
 * - Fix: Get PostalCodeAreas only if AreaManager__c is not NULL
 *   respectively if AssignedPartner__c is not NULL
 * - Search AreaManagers by profile ID matching name in AREA_MANAGER_PROFILE_STRING
 *
 * v1.0.0 (2016-10-11)
 * - Initial version
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @see https://interaktiv.jira.com/browse/SOBCRM-670
 * @see BatchTests.cls
 * @version 1.1.0 (2016-11-23)
 */
public class AssignDelegate {

    private static final String DEBUG_HEADER = 'AssignDelegate::';

    public static final String AREA_MANAGER_PROFILE_STRING = '* Area Manager';
    
    private static Id idAreaManagerProfile;

    /**
     * Propose Area Managers (Users) for a set of location maps
     *
     * Structure of a map:
     * <objectId> (e.g. Lead) => {countryCode => '', postalCode => '', latitude => '', longitude => ''}
     */
    public static Map<Id,FoundAreaManagerWrapper> proposeAreaManager(Map<Id,Map<String,String>> mapObjectIdLocations) {

        String sDebugString = DEBUG_HEADER + 'proposeAreaManager() - ';

        Map<Id,FoundAreaManagerWrapper> mapObjectIdToFoundAreaManagerWrapper = new Map<Id,FoundAreaManagerWrapper>();

        Map<Id,String> mapObjectIdToPostalCodeAreaSearchString = new Map<Id,String>();

        System.debug(sDebugString + 'Begin with ' + mapObjectIdLocations.size() + ' locations to find: ' + mapObjectIdLocations);

        //================================================
        // Search PostalCodeArea__c for matching ID string
        //================================================
        for (Id idObject : mapObjectIdLocations.keySet()) {

            Map<String,String> mapLocations = mapObjectIdLocations.get(idObject);

            String sCountryCode = mapLocations.get('countryCode');
            String sPostalCode  = mapLocations.get('postalCode');

            if (sCountryCode == NULL || sPostalCode == NULL) {
                continue;
            }

            // Create ID string
            mapObjectIdToPostalCodeAreaSearchString.put(idObject, sCountryCode + sPostalCode);
        }

        // Search by extracted PostalCodeArea search strings
        if (!mapObjectIdToPostalCodeAreaSearchString.isEmpty()) {

            System.debug(sDebugString + 'Search with ' + mapObjectIdToPostalCodeAreaSearchString.size() + ' postalCodeAreaSearchStrings: ' + mapObjectIdToPostalCodeAreaSearchString);

            List<PostalCodeArea__c> listFoundPostalCodeAreas = new List<PostalCodeArea__c>([
                SELECT
                    Id,
                    Country__c,
                    Name,
                    ExtId__c,
                    OwnerId,
                    Owner.Name
                FROM
                    PostalCodeArea__c
                WHERE
                    ExtId__c = :mapObjectIdToPostalCodeAreaSearchString.values() AND
                    OwnerId != NULL
            ]);

            if (!listFoundPostalCodeAreas.isEmpty()) {

                // Make a map PostCodeAreaIdString -> PostalCodeArea__c
                // (ExtId__c is unique!)
                Map<String,PostalCodeArea__c> mapPostalCodeAreaStringToPostCodeAreaObject = new Map<String,PostalCodeArea__c>();
                for (PostalCodeArea__c oPostalCodeArea : listFoundPostalCodeAreas) {
                    mapPostalCodeAreaStringToPostCodeAreaObject.put(oPostalCodeArea.ExtId__c, oPostalCodeArea);
                }

                // Assign found areas to object IDs
                for (Id idObject : mapObjectIdToPostalCodeAreaSearchString.keySet()) {

                    String postalCodeAreaIdString = mapObjectIdToPostalCodeAreaSearchString.get(idObject);

                    // If search found a match for the postal code area string
                    PostalCodeArea__c oFoundPostCodeArea = mapPostalCodeAreaStringToPostCodeAreaObject.get(postalCodeAreaIdString);

                    if (oFoundPostCodeArea != NULL) {

                        mapPostalCodeAreaStringToPostCodeAreaObject.get(postalCodeAreaIdString);

                        // Remove item from incoming map as a match was found.
                        // Left will be processed by nearbySearch beneath.
                        mapObjectIdLocations.remove(idObject);

                        FoundAreaManagerWrapper oFoundAreaManagerWrapper = new FoundAreaManagerWrapper(
                            oFoundPostCodeArea.OwnerId,
                            oFoundPostCodeArea.Owner.Name
                        );
                        oFoundAreaManagerWrapper.processInfo = 'Found "' + oFoundPostCodeArea.Owner.Name + '" (' + oFoundPostCodeArea.OwnerId + ') by postal code string "' + postalCodeAreaIdString + '"';

                        mapObjectIdToFoundAreaManagerWrapper.put(idObject, oFoundAreaManagerWrapper);

                        System.debug(sDebugString + 'Found PostalCodeArea for ' + idObject + ' (' + postalCodeAreaIdString + '): ' + oFoundAreaManagerWrapper);
                    }
                }
            }
        }

        //================================================
        // Else search nearby via geolocation
        //================================================
        Id idAreaManager = AssignDelegate.getAreaManagerProfileId();

        Integer iSoqlQueriesLeft = Limits.getLimitQueries() - Limits.getQueries();
        System.debug(sDebugString + 'Search nearby via geolocation with ' + iSoqlQueriesLeft + ' SOQL queries left for ' + mapObjectIdLocations.size() + ' locations: ' + mapObjectIdLocations);

        for (Id idObject : mapObjectIdLocations.keySet()) {

            Map<String,String> mapLocations = mapObjectIdLocations.get(idObject);

            if (mapLocations.get('longitude') == NULL || mapLocations.get('latitude') == NULL) {
                continue;
            }

            Double longitude = Double.valueOf(mapLocations.get('longitude'));
            Double latitude  = Double.valueOf(mapLocations.get('latitude'));

            List<User> nearbyUsers = new List<User>([
                SELECT
                    Id,
                    Name,
                    City,
                    PostalCode,
                    DISTANCE(Address, GEOLOCATION(:latitude,:longitude), 'km') Distance
                FROM
                    User
                WHERE
                    DISTANCE(Address, GEOLOCATION(:latitude,:longitude), 'km') < 40000 AND // to include 0 but not NULL
                    ProfileId = :idAreaManager
                ORDER BY
                    DISTANCE(Address, GEOLOCATION(:latitude,:longitude), 'km') ASC
                LIMIT 1
            ]);

            if (!nearbyUsers.isEmpty()) {

                User oUser = nearbyUsers.get(0);

                FoundAreaManagerWrapper oFoundAreaManagerWrapper = new FoundAreaManagerWrapper(
                    oUser.Id,
                    oUser.Name
                );
                Double distance = (Double)oUser.get('Distance');

                oFoundAreaManagerWrapper.distance = Integer.valueOf(Math.round(distance));
                oFoundAreaManagerWrapper.postalCode = oUser.PostalCode;
                oFoundAreaManagerWrapper.city = oUser.City;

                oFoundAreaManagerWrapper.processInfo = 'Found "' + oUser.Name + '" (' + oUser.Id + ') by geolocation ' + longitude + ', ' + latitude;

                System.debug(sDebugString + 'Found User for ' + idObject + ' (' + mapLocations + ') : ' + oFoundAreaManagerWrapper);

                mapObjectIdToFoundAreaManagerWrapper.put(idObject, oFoundAreaManagerWrapper);
            }
        }

        System.debug(sDebugString + 'Return map: ' + mapObjectIdToFoundAreaManagerWrapper);

        return mapObjectIdToFoundAreaManagerWrapper;
    }

    /**
     * Propose partner Accounts for a set of location maps
     *
     * Structure of a map:
     * <objectId> (e.g. Lead) => {countryCode => '', postalCode => '', latitude => '', longitude => ''}
     */
    public static Map<Id,List<FoundAccountWrapper>> proposePartnerAccounts(Map<Id,Map<String,String>> mapObjectIdLocations) {

        String sDebugString = DEBUG_HEADER + 'proposePartnerAccounts() - ';

        Map<Id,List<FoundAccountWrapper>> mapObjectIdToFoundAccountWrappers = new Map<Id,List<FoundAccountWrapper>>();

        Map<Id,String> mapObjectIdToPostalCodeAreaSearchString = new Map<Id,String>();

        System.debug(sDebugString + 'Begin with ' + mapObjectIdLocations.size() + ' locations to find: ' + mapObjectIdLocations);

        //================================================
        // Search PostCodeArea__c for matching ID string
        //================================================
        for (Id idObject : mapObjectIdLocations.keySet()) {

            Map<String,String> mapLocations = mapObjectIdLocations.get(idObject);

            String sCountryCode = mapLocations.get('countryCode');
            String sPostalCode  = mapLocations.get('postalCode');

            if (sCountryCode == NULL || sPostalCode == NULL) {
                continue;
            }

            // Create ID string
            mapObjectIdToPostalCodeAreaSearchString.put(idObject, sCountryCode + sPostalCode);
        }

        // Search by extracted PostalCodeArea search strings
        if (!mapObjectIdToPostalCodeAreaSearchString.isEmpty()) {

            System.debug(sDebugString + 'Search with ' + mapObjectIdToPostalCodeAreaSearchString.size() + ' postalCodeAreaSearchStrings: ' + mapObjectIdToPostalCodeAreaSearchString);

            List<PostalCodeArea__c> listFoundPostalCodeAreas = new List<PostalCodeArea__c>([
                SELECT
                    Id,
                    Country__c,
                    Name,
                    ExtId__c,
                    AssignedPartner__c,
                    AssignedPartner__r.Name,
                    AssignedPartner__r.Type,
                    AssignedPartner__r.BillingStreet,
                    AssignedPartner__r.BillingPostalCode,
                    AssignedPartner__r.BillingCity,
                    AssignedPartner__r.BillingCountry,
                    AssignedPartner__r.BillingCountryCode
                FROM
                    PostalCodeArea__c
                WHERE
                    ExtId__c = :mapObjectIdToPostalCodeAreaSearchString.values() AND
                    AssignedPartner__c != NULL AND
                	AssignedPartner__r.Status__c != 'inactive'	// SOBCRM-908 - Partner mit dem Status__c "inactive" sollen ausgeschlossen werden.
            ]);

            if (!listFoundPostalCodeAreas.isEmpty()) {

                // Make a map PostCodeAreaIdString -> PostalCodeArea__c
                // (ExtId__c is unique!)
                Map<String,PostalCodeArea__c> mapPostalCodeAreaStringToPostCodeAreaObject = new Map<String,PostalCodeArea__c>();
                for (PostalCodeArea__c oPostalCodeArea : listFoundPostalCodeAreas) {
                    mapPostalCodeAreaStringToPostCodeAreaObject.put(oPostalCodeArea.ExtId__c, oPostalCodeArea);
                }

                // Assign found areas to object IDs
                for (Id idObject : mapObjectIdToPostalCodeAreaSearchString.keySet()) {

                    String postalCodeAreaIdString = mapObjectIdToPostalCodeAreaSearchString.get(idObject);

                    // If search found a match for the postal code area string
                    PostalCodeArea__c oFoundPostCodeArea = mapPostalCodeAreaStringToPostCodeAreaObject.get(postalCodeAreaIdString);

                    if (oFoundPostCodeArea != NULL) {

                        mapPostalCodeAreaStringToPostCodeAreaObject.get(postalCodeAreaIdString);

                        // Remove item from incoming map as a match was found.
                        // Left will be processed by nearbySearch beneath.
                        mapObjectIdLocations.remove(idObject);

                        FoundAccountWrapper oFoundAccountWrapper = new FoundAccountWrapper(
                            oFoundPostCodeArea.AssignedPartner__c,
                            oFoundPostCodeArea.AssignedPartner__r.Name,
                            oFoundPostCodeArea.AssignedPartner__r.Type
                        );
                        oFoundAccountWrapper.city = oFoundPostCodeArea.AssignedPartner__r.BillingCity;
                        oFoundAccountWrapper.street = oFoundPostCodeArea.AssignedPartner__r.BillingStreet;
                        oFoundAccountWrapper.country = oFoundPostCodeArea.AssignedPartner__r.BillingCountry;
                        oFoundAccountWrapper.countryCode = oFoundPostCodeArea.AssignedPartner__r.BillingCountryCode;

                        oFoundAccountWrapper.processInfo = 'Found "' + oFoundPostCodeArea.AssignedPartner__r.Name + '" (' + oFoundPostCodeArea.AssignedPartner__c + ') by postal code string "' + postalCodeAreaIdString + '"';
                        oFoundAccountWrapper.method = 'postalCodeArea';
                        oFoundAccountWrapper.postalCodeArea = oFoundPostCodeArea;

                        mapObjectIdToFoundAccountWrappers.put(idObject, new List<FoundAccountWrapper>{oFoundAccountWrapper});

                        System.debug(sDebugString + 'Found PostalCodeArea for ' + idObject + ' (' + postalCodeAreaIdString + '): ' + oFoundAccountWrapper);
                    }
                }
            }
        }

        //================================================
        // Else search nearby via geolocation
        //================================================
        Id idAccountPartnerRecordId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Account', 'SBC');

        if (idAccountPartnerRecordId == NULL) {
            throw new AssignDelegateException('RecordType ID for Partner (SBC) Account not defined');
        }

        Integer iSoqlQueriesLeft = Limits.getLimitQueries() - Limits.getQueries();
        System.debug(sDebugString + 'Search nearby via geolocation with ' + iSoqlQueriesLeft + ' SOQL queries left for ' + mapObjectIdLocations.size() + ' locations: ' + mapObjectIdLocations);

        for (Id idObject : mapObjectIdLocations.keySet()) {

            Map<String,String> mapLocations = mapObjectIdLocations.get(idObject);

            if (mapLocations.get('longitude') == NULL || mapLocations.get('latitude') == NULL) {
                continue;
            }

            Double longitude = Double.valueOf(mapLocations.get('longitude'));
            Double latitude  = Double.valueOf(mapLocations.get('latitude'));

            List<Account> nearbyAccounts = new List<Account>([
                SELECT
                    Id,
                    Name,
                    Type,
                    BillingStreet,
                    BillingCity,
                    BillingPostalCode,
                    BillingCountry,
                    BillingCountryCode,
                    DISTANCE(BillingAddress, GEOLOCATION(:latitude,:longitude), 'km') Distance
                FROM
                    Account
                WHERE
                    DISTANCE(BillingAddress, GEOLOCATION(:latitude,:longitude), 'km') < 40000 AND // to include 0 but not NULL
                    RecordTypeId = :idAccountPartnerRecordId
                ORDER BY
                    DISTANCE(BillingAddress, GEOLOCATION(:latitude,:longitude), 'km') ASC
                LIMIT 5
            ]);

            // Initialize list
            mapObjectIdToFoundAccountWrappers.put(idObject, new List<FoundAccountWrapper>());

            if (!nearbyAccounts.isEmpty()) {

                for (Account oPartnerAccount : nearbyAccounts) {

                    FoundAccountWrapper oFoundAccountWrapper = new FoundAccountWrapper(
                        oPartnerAccount.Id,
                        oPartnerAccount.Name,
                        oPartnerAccount.Type
                    );
                    Double distance = (Double)oPartnerAccount.get('Distance');

                    oFoundAccountWrapper.distance = Integer.valueOf(Math.round(distance));
                    oFoundAccountWrapper.postalCode = oPartnerAccount.BillingPostalCode;
                    oFoundAccountWrapper.city = oPartnerAccount.BillingCity;
                    oFoundAccountWrapper.street = oPartnerAccount.BillingStreet;
                    oFoundAccountWrapper.country = oPartnerAccount.BillingCountry;
                    oFoundAccountWrapper.countryCode = oPartnerAccount.BillingCountryCode;

                    oFoundAccountWrapper.processInfo = 'Found "' + oPartnerAccount.Name + '" (' + oPartnerAccount.Id + ') by geolocation ' + longitude + ', ' + latitude;
                    oFoundAccountWrapper.method = 'nearby';

                    System.debug(sDebugString + 'Found Account for ' + idObject + ' (' + mapLocations + ') : ' + oFoundAccountWrapper);

                    mapObjectIdToFoundAccountWrappers.get(idObject).add(oFoundAccountWrapper);
                }
            }
        }

        System.debug(sDebugString + 'Return map: ' + mapObjectIdToFoundAccountWrappers);

        return mapObjectIdToFoundAccountWrappers;
    }

    /**
     * Get profile ID of Area Manager
     */
    public static Id getAreaManagerProfileId () {

        // If already fetched return
        if (idAreaManagerProfile != NULL) {
            return idAreaManagerProfile;
        }

        // Else get it
        List<Profile> listProfiles = [SELECT Id FROM Profile WHERE Name = :AREA_MANAGER_PROFILE_STRING LIMIT 1];

        if (listProfiles.isEmpty()) {
            throw new AssignDelegateException('No user profile found by Name "' + AREA_MANAGER_PROFILE_STRING + '"');
            return NULL;
        }

        return listProfiles.get(0).Id;
    }


    public class FoundAreaManagerWrapper {

        public String name {public get; private set;}
        public Id id {public get; private set;}
        public Integer distance {get; set;}
        public String city {get; set;}
        public String postalCode {get; set;}
        public String processInfo {get; set;}

        public FoundAreaManagerWrapper(Id id, String name) {
            this.name = name;
            this.id = id;
        }
    }

    public class FoundAccountWrapper {

        public Account account {public get; private set;}
        public Integer distance {get; set;}
        public String postalCode {get; set;}
        public String country {get; set;}
        public String countryCode {get; set;}
        public String city {get; set;}
        public String street {get; set;}
        public String processInfo {get; set;}
        public String method {get; set;}
        public PostalCodeArea__c postalCodeArea {get; set;}

        public FoundAccountWrapper(Id id, String name, String Type) {
            this.account = new Account(
                Id = id,
                Name = name,
                Type = type
            );
        }
    }

    public class AssignDelegateException extends Exception {}
}