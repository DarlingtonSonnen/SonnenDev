/**
* PostalCodeAreaTriggerHandler
*
* @created    18.01.2017
* @author     dino.ursic@die-interaktiven.de
* @see        SOBCRM-752, SOBCRM-844
* @version	   1.1.1
*
* TODO: Unit tests
*
* Changelog
* ---------
* v1.3.1 (06.08.2019) M.Muchow
* - Filter was changed to SystemModstamp but bug still occurs
* - because feature setLeadsTerritorialExclusivity() is currently not used and is causing the problem, code was comment out
*
* v1.3.0 (05.08.2019)
* - Added filter LastModifiedDate > LAST_120_DAYS to attempt to solve bug (more than 200.000 records) Lines 823
*
*
* v1.2.0 (12.09.2017)
* - SOBCRM-1061: setLeadsTerritorialExclusivity() method onAfterInsert / Update / Delete / Undelete
*
* v1.1.1 (18.08.2017)
* - SOBCRM-1027 -  Added exception handling to trigger to avoId errors caused by JSON Parsing
*                  with polygons and circles in sma__Geometry__c
*
* v1.1.0 (03.08.2017)
* - SOBCRM-1016 - Update Lead's Recommended Partner & Area Manager after PostalCodeArea assignment change
*
* v1.0.1 (28.03.2017)
* - SOBCRM-844 - Create MapAnything Territories for the Partners, same as for the Area Managers in SOBCRM-752
*
* v1.0.0 (18.01.2017)
* - Initial version
*
*/
public class PostalCodeAreaTriggerHandler extends TriggerHandler {

/**
 * After Insert trigger handler
 * Add reference to postal code to MapAnywhere-geometry after PostalCodeArea insert
 */
public overrIde voId afterInsert() {

    Map<Id, Set<String>> geometryCodesByOwner = new Map<Id, Set<String>>();
    Map<Id, Set<String>> geometryCodesByPartner = new Map<Id, Set<String>>();

    for(PostalCodeArea__c pca : (List<PostalCodeArea__c>)Trigger.new) {

        if(!geometryCodesByOwner.containsKey(pca.OwnerId))
            geometryCodesByOwner.put(pca.OwnerId, new Set<String>());

        if(!geometryCodesByPartner.containsKey(pca.AssignedPartner__c))
            geometryCodesByPartner.put(pca.AssignedPartner__c, new Set<String>());

        geometryCodesByOwner.get(pca.OwnerId).add(getGeometryCodeFromPostalCodeArea(pca));
        geometryCodesByPartner.get(pca.AssignedPartner__c).add(getGeometryCodeFromPostalCodeArea(pca));
    }

    LogUtil log = new LogUtil();

    try {

        assignPostalCodesToOwner(geometryCodesByOwner);

    } catch(Exception e) {

        log.error('Error in PostalCodeAreaTriggerHandler','Error while assigning Postalcodes To Owner', e);
    }

    try {

        assignPostalCodesToPartner(geometryCodesByPartner);

    } catch(Exception e) {

        log.error('Error in PostalCodeAreaTriggerHandler','Error while assigning Postalcodes To Partner', e);
    }

    // SOBCRM-1061
    /* M.Muchow Comment Out, not used, Query causing error
    this.setLeadsTerritorialExclusivity();
	*/
}

/**
 * After Update trigger handler
 * If PostalCodeArea's Owner changed
 *    1. Remove PLZ reference from Territory Geometry of old Owner (as if that PostalCodeArea was deleted)
 *    2. Add PLZ reference to Territory Geometry of new Owner (as if that PostalCodeArea was inserted)
 *
 * If PostalCodeArea's PLZ (Name field) changed (TBD)
 *    1. Get Geometries with reference to old PLZ and remove them
 *    2. Insert new PLZ to the Geometry owned by the PostalCodeArea owner
 */
public overrIde voId afterUpdate() {

    Map<Id, PostalCodeArea__c> oldMap = (Map<Id, PostalCodeArea__c>)Trigger.oldMap;
    Map<Id, PostalCodeArea__c> newMap = (Map<Id, PostalCodeArea__c>)Trigger.newMap;

    Map<Id, Set<String>> geometryCodesAssignedToOwner = new Map<Id, Set<String>>();
    Map<Id, Set<String>> geometryCodesRemovedFromOwner = new Map<Id, Set<String>>();
    Map<Id, Set<String>> geometryCodesAssignedToPartner = new Map<Id, Set<String>>();
    Map<Id, Set<String>> geometryCodesRemovedFromPartner = new Map<Id, Set<String>>();

    // SOBCRM-1016 - dino.ursic@die-interaktiven.de
    // When AssignedPartner changes on the PostalCodeArea, AssignedPartner should be updated on the Leads as well
    Map<String, Id> oldAreaManagerIdsByPLZ = new Map<String, Id>();
    Map<String, Id> oldAssignedPartnerIdsByPLZ = new Map<String, Id>();

    for(PostalCodeArea__c newPca : (List<PostalCodeArea__c>)Trigger.new) {

        PostalCodeArea__c oldPca = oldMap.get(newPca.Id);

        // Only changes to the Owner are relevant, so skip otherwise
        // Dino, 03.08.2017 - Maybe AreaManager Lookup should be consIdered rather than Owner field
        if (oldPca.OwnerId != newPca.OwnerId) {

            // If the map does not yet have an entry with the key newPCA.ownerId, create an empty set for that key
            if(!geometryCodesRemovedFromOwner.containsKey(oldPca.OwnerId))
                geometryCodesRemovedFromOwner.put(oldPca.OwnerId, new Set<String>());
            // Add Geometry Code (format 'DEU-35567') to the Set of removed PostalCodes for the oldPCA.OwnerId
            geometryCodesRemovedFromOwner.get(oldPca.OwnerId).add(getGeometryCodeFromPostalCodeArea(oldPca));

            // If the map does not yet have an entry with the key newPCA.ownerId, create an empty set for that key
            if(!geometryCodesAssignedToOwner.containsKey(newPca.OwnerId))
                geometryCodesAssignedToOwner.put(newPca.OwnerId, new Set<String>());
            // Add Geometry Code (format 'DEU-35567') to the Set of newly added PostalCodes for the newPCA.OwnerId
            geometryCodesAssignedToOwner.get(newPca.OwnerId).add(getGeometryCodeFromPostalCodeArea(newPca));
            
            // SOBCRM-1016 - dino.ursic@die-interaktiven.de, 02.08.2017
            // If AreaManager changed on the PostalCodeArea, it should be cleared from the Leads where the partner was AssignedPartner also
            oldAreaManagerIdsByPLZ.put(oldPca.Name, oldPca.OwnerId);
        }

        // Only changes to the Partner are relevant, so skip otherwise
        if (oldPca.AssignedPartner__c != newPca.AssignedPartner__c) {

            // If the map does not yet have an entry with the key newPCA.AssignedPartner__c, create an empty set for that key
            if(!geometryCodesRemovedFromPartner.containsKey(oldPca.AssignedPartner__c))
                geometryCodesRemovedFromPartner.put(oldPca.AssignedPartner__c, new Set<String>());
            // Add Geometry Code (format 'DEU-35567') to the Set of removed PostalCodes for the oldPCA.AssignedPartner__c
            geometryCodesRemovedFromPartner.get(oldPca.AssignedPartner__c).add(getGeometryCodeFromPostalCodeArea(oldPca));

            // If the map does not yet have an entry with the key newPCA.AssignedPartner__c, create an empty set for that key
            if(!geometryCodesAssignedToPartner.containsKey(newPca.AssignedPartner__c))
                geometryCodesAssignedToPartner.put(newPca.AssignedPartner__c, new Set<String>());
            // Add Geometry Code (format 'DEU-35567') to the Set of newly added PostalCodes for the newPCA.AssignedPartner__c
            geometryCodesAssignedToPartner.get(newPca.AssignedPartner__c).add(getGeometryCodeFromPostalCodeArea(newPca));

            // SOBCRM-1016 - dino.ursic@die-interaktiven.de, 02.08.2017
            // If AssignedPartner changed on the PostalCodeArea, it should be cleared from the Leads where the partner was AssignedPartner also
            oldAssignedPartnerIdsByPLZ.put(oldPca.Name, oldPca.AssignedPartner__c);
        }
    }


    LogUtil log = new LogUtil();

    try {

        // Remove PLZ reference from Territory Geometry of old Owner (as if that PostalCodeArea was deleted)
        removePostalCodesFromOwner(geometryCodesRemovedFromOwner);
        // Add PLZ reference to Territory Geometry of new Owner (as if that PostalCodeArea was inserted)
        assignPostalCodesToOwner(geometryCodesAssignedToOwner);

    } catch(Exception e) {

        log.error('Error in PostalCodeAreaTriggerHandler','Error while assigning Postalcodes To Owner', e);
    }

    try {

        // Remove PLZ reference from Territory Geometry of old Partner (as if that PostalCodeArea was deleted)
        removePostalCodesFromPartner(geometryCodesRemovedFromPartner);
        // Add PLZ reference to Territory Geometry of new Partner (as if that PostalCodeArea was inserted)
        assignPostalCodesToPartner(geometryCodesAssignedToPartner);

    } catch(Exception e) {

        log.error('Error in PostalCodeAreaTriggerHandler','Error while assigning Postalcodes To Partner', e);
    }

    // SOBCRM-1016 - dino.ursic@die-interaktiven.de, 02.08.2017
    // If AssignedPartner changed on the PostalCodeArea, it should be cleared from the Leads where the partner was AssignedPartner also
    removeAssignedPartnerOnLeads(oldAssignedPartnerIdsByPLZ);

    // SOBCRM-1061
    /* M.Muchow Comment Out, not used, Query causing error
    this.setLeadsTerritorialExclusivity();
	*/
}

/**
 * After Delete trigger handler
 * Remove reference to postal code from MapAnywhere-geometry after PostalCodeArea delete
 */
public overrIde voId afterDelete() {

    Map<Id, Set<String>> geometryCodesByOwner = new Map<Id, Set<String>>();
    Map<Id, Set<String>> geometryCodesByPartner = new Map<Id, Set<String>>();

    for(PostalCodeArea__c pca : (List<PostalCodeArea__c>)Trigger.old) {

        if(!geometryCodesByOwner.containsKey(pca.OwnerId))
            geometryCodesByOwner.put(pca.OwnerId, new Set<String>());

        if(!geometryCodesByPartner.containsKey(pca.OwnerId))
            geometryCodesByPartner.put(pca.OwnerId, new Set<String>());

        // Add the PCA to the list of to-be-removed-from Owner's MATerritory
        geometryCodesByOwner.get(pca.OwnerId).add(getGeometryCodeFromPostalCodeArea(pca));
        // Add the PCA to the list of to-be-removed-from Partner's MATerritory, only if it had an assigned partner
        if(pca.AssignedPartner__c != null)
            geometryCodesByPartner.get(pca.OwnerId).add(getGeometryCodeFromPostalCodeArea(pca));
    }

    LogUtil log = new LogUtil();

    try {

        removePostalCodesFromOwner(geometryCodesByOwner);

    } catch(Exception e) {

        log.error('Error in PostalCodeAreaTriggerHandler','Error while assigning Postalcodes To Owner', e);
    }

    try {

        removePostalCodesFromPartner(geometryCodesByPartner);

    } catch(Exception e) {

        log.error('Error in PostalCodeAreaTriggerHandler','Error while assigning Postalcodes To Partner', e);
    }

    // SOBCRM-1061
    /* M.Muchow Comment Out, not used, Query causing error
    this.setLeadsTerritorialExclusivity();
	*/
}

public overrIde voId afterUndelete() {
    // SOBCRM-1061
    /* M.Muchow Comment Out, not used, Query causing error
    this.setLeadsTerritorialExclusivity();
	*/
}

public voId assignPostalCodesToOwner(Map<Id, Set<String>> geometryCodesByOwner) {

    User ownerUser;

    // Get Users mapped by UserId (User's FirstName required later during Territory/Geometry creation)
    Map<Id, User> ownerUserById = new Map<Id, User>([SELECT Id, FirstName FROM User WHERE Id IN :geometryCodesByOwner.keySet()]);

    List<sma__MATerritoryGeometry__c> maGeometries = [SELECT Id, sma__Geometry__c,
                                                            sma__Territory__r.OwnerId,
                                                            sma__Territory__r.Owner.FirstName
                                                        FROM sma__MATerritoryGeometry__c
                                                        WHERE sma__Territory__r.OwnerId IN :geometryCodesByOwner.keySet() AND sma__Territory__r.Partner__c = NULL];

    // Find OwnerIds which have no Territory/Geometry records so far
    Map<User, Set<sma__MATerritoryGeometry__c>> maGeometriesByOwner = new Map<User, Set<sma__MATerritoryGeometry__c>>();
    for(sma__MATerritoryGeometry__c maTerrGeo : maGeometries) {
        ownerUser = ownerUserById.get(maTerrGeo.sma__Territory__r.OwnerId);

        if(!maGeometriesByOwner.containsKey(ownerUser))
            maGeometriesByOwner.put(ownerUser, new Set<sma__MATerritoryGeometry__c>());

        maGeometriesByOwner.get(ownerUser).add(maTerrGeo);
    }

    // Create Territory/Geometry record for each user in the Map geometryCodesByOwner if they do not have Territory/Geometry
    Map<sma__MATerritoryGeometry__c, sma__MATerritory__c> territoriesByGeometry = new Map<sma__MATerritoryGeometry__c, sma__MATerritory__c>();
    for(Id ownerId : geometryCodesByOwner.keySet()) {
        ownerUser = ownerUserById.get(ownerId);
        if(!maGeometriesByOwner.containsKey(ownerUser)) {
            sma__MATerritory__c territory = new sma__MATerritory__c(Id=null);
            territory.Name='Area ' + ownerUser.FirstName;
            territory.OwnerId=ownerUser.Id;
            territory.sma__Options__c = '{"country":"DEU",';
            territory.sma__Options__c += '"advancedOptions": {"calculateTerritoryAggregates":false,"dissolveGeometry":true},';
            territory.sma__Options__c += '"colorOptions":{"fillColor":""}}';
            sma__MATerritoryGeometry__c geometry = new sma__MATerritoryGeometry__c();
            geometry.Name = territory.Name + '-geometry';

            // put new territory and geometry record to map
            territoriesByGeometry.put(geometry, territory);
        }
    }
    if(!territoriesByGeometry.values().isEmpty()) {

        // insert territories
        insert territoriesByGeometry.values();

        // then link geometries to territories
        for(sma__MATerritoryGeometry__c geo : territoriesByGeometry.keySet()) {
            geo.sma__Territory__c = territoriesByGeometry.get(geo).Id;
        }

        // and finally insert geometries
        insert new List<sma__MATerritoryGeometry__c>(territoriesByGeometry.keySet());
    }

    // Add newly created MA Geometry records to the list initially retrieved by the SOQL query
    //maGeometries.addAll(territoriesByGeometry.keySet());
    // Actually, have to re-query them to get the reference to sma__Territory parent and it's OwnerId
    maGeometries = [SELECT Id, sma__Geometry__c,
                        sma__Territory__r.OwnerId,
                        sma__Territory__r.Owner.FirstName
                    FROM sma__MATerritoryGeometry__c
                    WHERE sma__Territory__r.OwnerId IN :geometryCodesByOwner.keySet() AND sma__Territory__r.Partner__c = NULL];

    // Iterate over all MapAnything Geometries of Territories owned by the owners of inserted PostalCodeAreas
    for(sma__MATerritoryGeometry__c maTerrGeo : maGeometries) {

        // Get List of inserted PostalCodeAreas for the same owner as current Geometry's Territory Owner
        Set<String> insertedPostalCodes = geometryCodesByOwner.get(maTerrGeo.sma__Territory__r.OwnerId);
        maTerrGeo.sma__Geometry__c = getUpdatedGeometryFieldOnAdd(maTerrGeo.sma__Geometry__c, insertedPostalCodes);
    }

    update maGeometries;
}

public voId removePostalCodesFromOwner(Map<Id, Set<String>> geometryCodesByOwner) {

    List<sma__MATerritoryGeometry__c> maGeometries = [SELECT Id, sma__Geometry__c, sma__Territory__r.OwnerId
                                                        FROM sma__MATerritoryGeometry__c
                                                        WHERE sma__Territory__r.OwnerId IN :geometryCodesByOwner.keySet()];

    // Iterate over all MapAnything Geometries of Territories owned by the owners of deleted PostalCodeAreas
    for(sma__MATerritoryGeometry__c maTerrGeo : maGeometries) {

        // Get List of deleted PostalCodeAreas for the same owner as current Geometry's Territory Owner
        Set<String> deletedPostalCodes = geometryCodesByOwner.get(maTerrGeo.sma__Territory__r.OwnerId);
        maTerrGeo.sma__Geometry__c = getUpdatedGeometryFieldOnRemove(maTerrGeo.sma__Geometry__c, deletedPostalCodes);
    }

    update maGeometries;
}

public voId assignPostalCodesToPartner(Map<Id, Set<String>> geometryCodesByPartner) {

    Account assignedPartner;

    // Get AssignedPartners mapped by AccountId (Partner's Name required later during Territory/Geometry creation)
    Map<Id, Account> assignedPartnerById = new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :geometryCodesByPartner.keySet()]);

    List<sma__MATerritoryGeometry__c> maGeometries = [SELECT Id, sma__Geometry__c,
                                                            sma__Territory__r.Partner__c,
                                                            sma__Territory__r.Partner__r.Name
                                                        FROM sma__MATerritoryGeometry__c
                                                        WHERE sma__Territory__r.Partner__c IN :geometryCodesByPartner.keySet()];

    // Find AccountIds which have no Territory/Geometry records so far
    Map<Account, Set<sma__MATerritoryGeometry__c>> maGeometriesByPartner = new Map<Account, Set<sma__MATerritoryGeometry__c>>();
    for(sma__MATerritoryGeometry__c maTerrGeo : maGeometries) {
        assignedPartner = assignedPartnerById.get(maTerrGeo.sma__Territory__r.Partner__c);

        if(!maGeometriesByPartner.containsKey(assignedPartner))
            maGeometriesByPartner.put(assignedPartner, new Set<sma__MATerritoryGeometry__c>());

        maGeometriesByPartner.get(assignedPartner).add(maTerrGeo);
    }

    // Create Territory/Geometry record for each Account in the Map geometryCodesByPartner if they do not have Territory/Geometry
    Map<sma__MATerritoryGeometry__c, sma__MATerritory__c> territoriesByGeometry = new Map<sma__MATerritoryGeometry__c, sma__MATerritory__c>();
    for(Id partnerId : geometryCodesByPartner.keySet()) {
        assignedPartner = assignedPartnerById.get(partnerId);
        if(!maGeometriesByPartner.containsKey(assignedPartner)) {
            sma__MATerritory__c territory = new sma__MATerritory__c(Id=null);
            territory.Name='Territory ' + assignedPartner.Name;
            territory.Partner__c=assignedPartner.Id;
            territory.sma__Options__c = '{"country":"DEU",';
            territory.sma__Options__c += '"advancedOptions": {"calculateTerritoryAggregates":false,"dissolveGeometry":true},';
            territory.sma__Options__c += '"colorOptions":{"fillColor":""}}';
            sma__MATerritoryGeometry__c geometry = new sma__MATerritoryGeometry__c();
            geometry.Name = territory.Name + '-geometry';

            // put new territory and geometry record to map
            territoriesByGeometry.put(geometry, territory);
        }
    }
    if(!territoriesByGeometry.values().isEmpty()) {

        // insert territories
        insert territoriesByGeometry.values();

        // then link geometries to territories
        for(sma__MATerritoryGeometry__c geo : territoriesByGeometry.keySet()) {
            geo.sma__Territory__c = territoriesByGeometry.get(geo).Id;
        }

        // and finally insert geometries
        insert new List<sma__MATerritoryGeometry__c>(territoriesByGeometry.keySet());
    }

    // Add newly created MA Geometry records to the list initially retrieved by the SOQL query
    //maGeometries.addAll(territoriesByGeometry.keySet());
    // Actually, have to re-query them to get the reference to sma__Territory parent and it's Partner__c
    maGeometries = [SELECT Id, Name, sma__Geometry__c,
                        sma__Territory__r.Partner__c,
                        sma__Territory__r.Partner__r.Name
                    FROM sma__MATerritoryGeometry__c
                    WHERE sma__Territory__r.Partner__c IN :geometryCodesByPartner.keySet()];

    // Iterate over all MapAnything Geometries of Territories owned by the owners of inserted PostalCodeAreas
    for(sma__MATerritoryGeometry__c maTerrGeo : maGeometries) {

        // Get List of inserted PostalCodeAreas for the same owner as current Geometry's Territory Owner
        Set<String> insertedPostalCodes = geometryCodesByPartner.get(maTerrGeo.sma__Territory__r.Partner__c);
        maTerrGeo.sma__Geometry__c = getUpdatedGeometryFieldOnAdd(maTerrGeo.sma__Geometry__c, insertedPostalCodes);
    }

    update maGeometries;
}

public voId removePostalCodesFromPartner(Map<Id, Set<String>> geometryCodesByPartner) {

    List<sma__MATerritoryGeometry__c> maGeometries = [SELECT Id, sma__Geometry__c, sma__Territory__r.Partner__c
                                                        FROM sma__MATerritoryGeometry__c
                                                        WHERE sma__Territory__r.Partner__c IN :geometryCodesByPartner.keySet()];

    // Iterate over all MapAnything Geometries of Territories assigned to the Partners of deleted PostalCodeAreas
    for(sma__MATerritoryGeometry__c maTerrGeo : maGeometries) {

        // Get List of deleted PostalCodeAreas for the same partner as current Geometry's Territory Partner
        Set<String> deletedPostalCodes = geometryCodesByPartner.get(maTerrGeo.sma__Territory__r.Partner__c);
        maTerrGeo.sma__Geometry__c = getUpdatedGeometryFieldOnRemove(maTerrGeo.sma__Geometry__c, deletedPostalCodes);
    }

    update maGeometries;
}

private voId removeAssignedPartnerOnLeads(Map<String, Id> oldAssignedPartnerIdsByPLZ) {

    List<Lead> leads = [SELECT Id, AssignSBC__c, PostalCode, Status
                        FROM Lead
                        WHERE AssignSBC__c IN :oldAssignedPartnerIdsByPLZ.values()];
    List<Lead> leadsForUpdate = new List<Lead>();
    for(Lead l : leads) {

        // E.g. if a Lead with PostalCode 35576 is assigned to Partner responsible for PLZs 35576/35578, but the
        // AssignedPartner for only 35578 has changed - in such case, Leads with PLZ 35576 should remain intact,
        // and only the ones with PLZ 35578 should be re-processed by the LeadAssignPartnerAndManagerBatch job
        if (!oldAssignedPartnerIdsByPLZ.containsKey(l.PostalCode))
            continue;

        if (l.Status != 'Closed - Dead' && l.Status != 'Qualified' && l.Status != 'Duplicate') {
            l.AssignSBC__c = null;
            l.AreaManager__c = null;
            l.WasHandledByPartnerAssignBatch__c = false;
            l.WasHandledByAreaManagerAssignBatch__c = false;
            leadsForUpdate.add(l);
        }
    }
    update leadsForUpdate;
}

private class MapAnythingGeometry {
    private List<String> postalCodeArray { get; set; }
}

private String getUpdatedGeometryFieldOnAdd(String geometryFieldJSON, Set<String> insertedPostalCodes) {

    if(String.isBlank(geometryFieldJSON)) {
        return JSON.serialize(new Map<String, Object>{'5'=>insertedPostalCodes});
    }

    Object geometryFieldObj = JSON.deserializeUntyped(geometryFieldJSON);
    Map<String, Object> geometryFieldMap = (Map<String, Object>)geometryFieldObj;

    String geometryFieldMapFirstKey = (new List<String>(geometryFieldMap.keySet()))[0];
    List<Object> geometryFieldCodeList = (List<Object>)geometryFieldMap.get(geometryFieldMapFirstKey);
    if (geometryFieldCodeList == null)
        geometryFieldCodeList = new List<Object>();

    Set<Object> geometryFieldCodeListSet = new Set<Object>(geometryFieldCodeList);
    for(String insertedPostalCode : insertedPostalCodes) {
        if(!geometryFieldCodeListSet.contains((Object)insertedPostalCode))
            geometryFieldCodeList.add(insertedPostalCode);
    }

    // After the relevant Geometry Codes for the deleted PostalCodeAreas have been removed
    // from the deserialized MapAnythingGeometry.sma__Geometry__c Geometry Codes list, put
    // the list back in the map, and serialize the entire map back to the sma__Geometry__c
    geometryFieldMap.put(geometryFieldMapFirstKey, geometryFieldCodeList);
    return JSON.serialize(geometryFieldMap);
}

private String getUpdatedGeometryFieldOnRemove(String geometryFieldJSON, Set<String> deletedPostalCodes) {

    //Object geometryFieldObj = JSON.deserializeUntyped(geometryFieldJSON);
    //Map<String, Object> geometryFieldMap = (Map<String, Object>)geometryFieldObj;
    Map<String, List<String>> geometryFieldMap = (Map<String, List<String>>)JSON.deserialize(geometryFieldJSON, Map<String, List<String>>.class);

    String geometryFieldMapFirstKey = (new List<String>(geometryFieldMap.keySet()))[0];
    List<String> geometryFieldCodeList = (List<String>)geometryFieldMap.get(geometryFieldMapFirstKey);

    if (geometryFieldCodeList == null)
        return geometryFieldJSON;

    for(Integer i = geometryFieldCodeList.size()-1; i >=0; i--) {
        if(deletedPostalCodes.contains((String)geometryFieldCodeList.get(i))) {
            geometryFieldCodeList.remove(i);
        }
    }

    // After the relevant Geometry Codes for the deleted PostalCodeAreas have been removed
    // from the deserialized MapAnythingGeometry.sma__Geometry__c Geometry Codes list, put
    // the list back in the map, and serialize the entire map back to the sma__Geometry__c
    geometryFieldMap.put(geometryFieldMapFirstKey, geometryFieldCodeList);
    return JSON.serialize(geometryFieldMap);
}

/**
 * Static Methods and Properties
 */
public static String getGeometryCodeFromPostalCodeArea(PostalCodeArea__c pca) {

    if(!countryIsoCodes.containsKey(pca.Country__c))
        return null;

    String countryIsoCode3 = countryIsoCodes.get(pca.Country__c);
    return countryIsoCode3.toLowerCase() + '-' + pca.Name;			// e.g. deu-35576 for Wetzlar :)
}

public static Map<String, String> countryIsoCodes = new Map<String, String>{
    'AF'=>'AFG',
    'AX'=>'ALA',
    'AL'=>'ALB',
    'DZ'=>'DZA',
    'AS'=>'ASM',
    'AD'=>'AND',
    'AO'=>'AGO',
    'AI'=>'AIA',
    'AQ'=>'ATA',
    'AG'=>'ATG',
    'AR'=>'ARG',
    'AM'=>'ARM',
    'AW'=>'ABW',
    'AU'=>'AUS',
    'AT'=>'AUT',
    'AZ'=>'AZE',
    'BS'=>'BHS',
    'BH'=>'BHR',
    'BD'=>'BGD',
    'BB'=>'BRB',
    'BY'=>'BLR',
    'BE'=>'BEL',
    'BZ'=>'BLZ',
    'BJ'=>'BEN',
    'BM'=>'BMU',
    'BT'=>'BTN',
    'BO'=>'BOL',
    'BA'=>'BIH',
    'BW'=>'BWA',
    'BV'=>'BVT',
    'BR'=>'BRA',
    'VG'=>'VGB',
    'IO'=>'IOT',
    'BN'=>'BRN',
    'BG'=>'BGR',
    'BF'=>'BFA',
    'BI'=>'BDI',
    'KH'=>'KHM',
    'CM'=>'CMR',
    'CA'=>'CAN',
    'CV'=>'CPV',
    'KY'=>'CYM',
    'CF'=>'CAF',
    'TD'=>'TCD',
    'CL'=>'CHL',
    'CN'=>'CHN',
    'HK'=>'HKG',
    'MO'=>'MAC',
    'CX'=>'CXR',
    'CC'=>'CCK',
    'CO'=>'COL',
    'KM'=>'COM',
    'CG'=>'COG',
    'CD'=>'COD',
    'CK'=>'COK',
    'CR'=>'CRI',
    'CI'=>'CIV',
    'HR'=>'HRV',
    'CU'=>'CUB',
    'CY'=>'CYP',
    'CZ'=>'CZE',
    'DK'=>'DNK',
    'DJ'=>'DJI',
    'DM'=>'DMA',
    'DO'=>'DOM',
    'EC'=>'ECU',
    'EG'=>'EGY',
    'SV'=>'SLV',
    'GQ'=>'GNQ',
    'ER'=>'ERI',
    'EE'=>'EST',
    'ET'=>'ETH',
    'FK'=>'FLK',
    'FO'=>'FRO',
    'FJ'=>'FJI',
    'FI'=>'FIN',
    'FR'=>'FRA',
    'GF'=>'GUF',
    'PF'=>'PYF',
    'TF'=>'ATF',
    'GA'=>'GAB',
    'GM'=>'GMB',
    'GE'=>'GEO',
    'DE'=>'DEU',
    'GH'=>'GHA',
    'GI'=>'GIB',
    'GR'=>'GRC',
    'GL'=>'GRL',
    'GD'=>'GRD',
    'GP'=>'GLP',
    'GU'=>'GUM',
    'GT'=>'GTM',
    'GG'=>'GGY',
    'GN'=>'GIN',
    'GW'=>'GNB',
    'GY'=>'GUY',
    'HT'=>'HTI',
    'HM'=>'HMD',
    'VA'=>'VAT',
    'HN'=>'HND',
    'HU'=>'HUN',
    'IS'=>'ISL',
    'IN'=>'IND',
    'Id'=>'IdN',
    'IR'=>'IRN',
    'IQ'=>'IRQ',
    'IE'=>'IRL',
    'IM'=>'IMN',
    'IL'=>'ISR',
    'IT'=>'ITA',
    'JM'=>'JAM',
    'JP'=>'JPN',
    'JE'=>'JEY',
    'JO'=>'JOR',
    'KZ'=>'KAZ',
    'KE'=>'KEN',
    'KI'=>'KIR',
    'KP'=>'PRK',
    'KR'=>'KOR',
    'KW'=>'KWT',
    'KG'=>'KGZ',
    'LA'=>'LAO',
    'LV'=>'LVA',
    'LB'=>'LBN',
    'LS'=>'LSO',
    'LR'=>'LBR',
    'LY'=>'LBY',
    'LI'=>'LIE',
    'LT'=>'LTU',
    'LU'=>'LUX',
    'MK'=>'MKD',
    'MG'=>'MDG',
    'MW'=>'MWI',
    'MY'=>'MYS',
    'MV'=>'MDV',
    'ML'=>'MLI',
    'MT'=>'MLT',
    'MH'=>'MHL',
    'MQ'=>'MTQ',
    'MR'=>'MRT',
    'MU'=>'MUS',
    'YT'=>'MYT',
    'MX'=>'MEX',
    'FM'=>'FSM',
    'MD'=>'MDA',
    'MC'=>'MCO',
    'MN'=>'MNG',
    'ME'=>'MNE',
    'MS'=>'MSR',
    'MA'=>'MAR',
    'MZ'=>'MOZ',
    'MM'=>'MMR',
    'NA'=>'NAM',
    'NR'=>'NRU',
    'NP'=>'NPL',
    'NL'=>'NLD',
    'AN'=>'ANT',
    'NC'=>'NCL',
    'NZ'=>'NZL',
    'NI'=>'NIC',
    'NE'=>'NER',
    'NG'=>'NGA',
    'NU'=>'NIU',
    'NF'=>'NFK',
    'MP'=>'MNP',
    'NO'=>'NOR',
    'OM'=>'OMN',
    'PK'=>'PAK',
    'PW'=>'PLW',
    'PS'=>'PSE',
    'PA'=>'PAN',
    'PG'=>'PNG',
    'PY'=>'PRY',
    'PE'=>'PER',
    'PH'=>'PHL',
    'PN'=>'PCN',
    'PL'=>'POL',
    'PT'=>'PRT',
    'PR'=>'PRI',
    'QA'=>'QAT',
    'RE'=>'REU',
    'RO'=>'ROU',
    'RU'=>'RUS',
    'RW'=>'RWA',
    'BL'=>'BLM',
    'SH'=>'SHN',
    'KN'=>'KNA',
    'LC'=>'LCA',
    'MF'=>'MAF',
    'PM'=>'SPM',
    'VC'=>'VCT',
    'WS'=>'WSM',
    'SM'=>'SMR',
    'ST'=>'STP',
    'SA'=>'SAU',
    'SN'=>'SEN',
    'RS'=>'SRB',
    'SC'=>'SYC',
    'SL'=>'SLE',
    'SG'=>'SGP',
    'SK'=>'SVK',
    'SI'=>'SVN',
    'SB'=>'SLB',
    'SO'=>'SOM',
    'ZA'=>'ZAF',
    'GS'=>'SGS',
    'SS'=>'SSD',
    'ES'=>'ESP',
    'LK'=>'LKA',
    'SD'=>'SDN',
    'SR'=>'SUR',
    'SJ'=>'SJM',
    'SZ'=>'SWZ',
    'SE'=>'SWE',
    'CH'=>'CHE',
    'SY'=>'SYR',
    'TW'=>'TWN',
    'TJ'=>'TJK',
    'TZ'=>'TZA',
    'TH'=>'THA',
    'TL'=>'TLS',
    'TG'=>'TGO',
    'TK'=>'TKL',
    'TO'=>'TON',
    'TT'=>'TTO',
    'TN'=>'TUN',
    'TR'=>'TUR',
    'TM'=>'TKM',
    'TC'=>'TCA',
    'TV'=>'TUV',
    'UG'=>'UGA',
    'UA'=>'UKR',
    'AE'=>'ARE',
    'GB'=>'GBR',
    'US'=>'USA',
    'UM'=>'UMI',
    'UY'=>'URY',
    'UZ'=>'UZB',
    'VU'=>'VUT',
    'VE'=>'VEN',
    'VN'=>'VNM',
    'VI'=>'VIR',
    'WF'=>'WLF',
    'EH'=>'ESH',
    'YE'=>'YEM',
    'ZM'=>'ZMB',
    'ZW'=>'ZWE'
};

public class PostalCodeAreaTriggerHandlerException extends Exception {}

 /**
 * Sets Territorial Exclusivity on Leads from related Postal Code Area
 *
 * @see https://interaktiv.jira.com/browse/SOBCRM-1061
 * @author Igor Savchenko <igor@die-interaktiven.de>
 */  
	
private voId setLeadsTerritorialExclusivity() {
    Lead[] leadsToUpdate = new Lead[]{};
    Lead[] openLeads = getAllNeededLeads();
    PostalCodeArea__c[] pcasToIterate = Trigger.isAfter && Trigger.isDelete ? (PostalCodeArea__c[])Trigger.old : (PostalCodeArea__c[])Trigger.new;

    for (PostalCodeArea__c pca: pcasToIterate) {
        if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUndelete)) {
            leadsToUpdate.addAll(getLeadsToUpdate(openLeads, pca.Name, pca.TerritorialExclusivity__c, pca.Country__c));
        }
        if (Trigger.isAfter && Trigger.isUpdate) {
            if (Trigger.oldMap.get(pca.Id).get('Name') != pca.Name) {
                leadsToUpdate.addAll(getLeadsToUpdate(openLeads, (String)Trigger.oldMap.get(pca.Id).get('Name'), false, pca.Country__c));
                leadsToUpdate.addAll(getLeadsToUpdate(openLeads, pca.Name, pca.TerritorialExclusivity__c, pca.Country__c));
            }
            if (Trigger.oldMap.get(pca.Id).get('TerritorialExclusivity__c') != pca.TerritorialExclusivity__c) {
                leadsToUpdate.addAll(getLeadsToUpdate(openLeads, pca.Name, pca.TerritorialExclusivity__c, pca.Country__c));
            }
        }
        if (Trigger.isAfter && Trigger.isDelete) {
            leadsToUpdate.addAll(getLeadsToUpdate(openLeads, (String)Trigger.oldMap.get(pca.Id).get('Name'), false, pca.Country__c));
        }
    }

    update leadsToUpdate;
}

private Lead[] getAllNeededLeads() {
    String[] allNeededPostalCodes = new String[]{};
    String[] allNeededCountryCodes = new String[]{};
    if (Trigger.isAfter && (Trigger.isDelete || Trigger.isUpdate)) {
        for (PostalCodeArea__c pca: (List<PostalCodeArea__c>)Trigger.old) {
            allNeededPostalCodes.add(pca.Name);
            allNeededCountryCodes.add(pca.Country__c);
        }
    }
    if (!Trigger.isDelete) {
        for (PostalCodeArea__c pca: (List<PostalCodeArea__c>)Trigger.new) {
            allNeededPostalCodes.add(pca.Name);
            allNeededCountryCodes.add(pca.Country__c);
        }
    }

    List<Lead> openLeads = new List<Lead>();

    for(Lead l : [SELECT CountryCode, PostalCode, TerritorialExclusivity__c FROM Lead WHERE (Status = 'Open' AND SystemModstamp  = LAST_N_DAYS:120) AND PostalCode IN :allNeededPostalCodes AND CountryCode IN :allNeededCountryCodes]){
        openLeads.add(l);
    }
    return openLeads;
}

private Lead[] getLeadsToUpdate(Lead[] leads, String postalCode, Boolean territoryExclusivity, String countryCode) {
    Lead[] leadsToUpdate = new Lead[]{};
    for (Lead lead: (Lead[])filterSObjects(filterSObjects(filterSObjects(leads, 'PostalCode', postalCode), 'TerritorialExclusivity__c', !territoryExclusivity), 'CountryCode', countryCode)) {
        lead.TerritorialExclusivity__c = territoryExclusivity;
        leadsToUpdate.add(lead);
    }
    return leadsToUpdate;
}

private sObject[] filterSObjects(sObject[] sObjects, String field, String value) {
    sObject[] filteredSObjects = new sObject[]{};
    for (sObject o: sObjects) {
        if (o.get(field) == value) {
            filteredSObjects.add(o);
        }
    }
    return filteredSObjects;
}

private sObject[] filterSObjects(sObject[] sObjects, String field, Boolean value) {
    sObject[] filteredSObjects = new sObject[]{};
    for (sObject o: sObjects) {
        if (o.get(field) == value) {
            filteredSObjects.add(o);
        }
    }
    return filteredSObjects;
}


}