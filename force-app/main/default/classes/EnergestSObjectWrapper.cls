/**
 * EnergestSObjectWrapper
 *
 * Abstract base class for SObjects to wrap
 *
 * v1.0.0   2019-03-04  Marko Schmalenbach          Initial
 * v1.0.1   2019-06-04  Marko Schmalenbach          New getDescribeFieldsForSObject(): Cache time consuming global field describes for SObjects
 *
 * @see https://interaktiv.jira.com/browse/SOBCRM-1321
 */
public abstract without sharing class EnergestSObjectWrapper {

    protected final EnergestEntityPod.EnergestPod pod;
    public final EnergestEntityPod parentEnergestEntityPod;

    public static final String DEBUG_HEADER = 'EnergestSObjectWrapper.';

    public String ENERGEST_POD_LOOKUP_FIELD;
    public String ENERGEST_POD_LOOKUP_FIELD_RELATION;

    public SObject oSObject;

    protected String CustomerName;
    protected String CustomerFirstName;
    protected String CustomerLastName;
    protected String CustomerEmail;
    protected String CustomerPhone;
    protected String CustomerMobile;

    protected String BillingStreet;
    protected String BillingStreetNo;
    protected String BillingStreetAndNo;
    protected String BillingPostalCode;
    protected String BillingCity;
    protected String BillingStateCode;
    protected String BillingCountryCode;

    protected String ShippingStreet;
    protected String ShippingStreetNo;
    protected String ShippingStreetAndNo;
    protected String ShippingPostalCode;
    protected String ShippingCity;
    protected String ShippingStateCode;
    protected String ShippingCountryCode;

    public static Map<String, Map<String, SObjectField>> mapDescribeFieldsBySObject = new Map<String, Map<String, SObjectField>>();

    public EnergestSObjectWrapper(EnergestEntityPod parentEnergestEntityPod) {

        this.pod = parentEnergestEntityPod.sourcePod;
        this.parentEnergestEntityPod = parentEnergestEntityPod;

        // Common recurring fields
        this.CustomerFirstName      = capitalizeEachWord(this.pod.CustomerName);
        this.CustomerLastName       = capitalizeEachWord(this.pod.CustomerSurname);
        this.CustomerName           = (this.CustomerFirstName + ' ' + this.CustomerLastName).trim();
        this.CustomerEmail          = (this.pod.AttorneyEmail != null ? this.pod.AttorneyEmail.toLowerCase() : null);
        this.CustomerPhone          = this.pod.AttorneyPhoneNumber;
        this.CustomerMobile         = this.pod.AttorneyMobileNumber;
        this.BillingStreet          = capitalizeEachWord(pod.LegalAddress);
        this.BillingStreetNo        = this.pod.LegalHouseNumber;
        this.BillingStreetAndNo     = (this.BillingStreet + ' ' + this.pod.LegalHouseNumber).trim();
        this.BillingPostalCode      = this.pod.LegalPostalCode;
        this.BillingCity            = capitalizeEachWord(pod.LegalMunicipality);
        this.BillingCountryCode     = 'IT';
        this.BillingStateCode       = this.pod.LegalDistrictCode;
        this.ShippingStreet         = capitalizeEachWord(pod.SupplyAddress);
        this.ShippingStreetNo       = this.pod.SupplyHouseNumber;
        this.ShippingStreetAndNo    = (this.ShippingStreet + ' ' + this.pod.SupplyHouseNumber).trim();
        this.ShippingPostalCode     = this.pod.SupplyPostalCode;
        this.ShippingCity           = capitalizeEachWord(pod.SupplyMunicipality);
        this.ShippingCountryCode    = 'IT';
        this.ShippingStateCode      = this.pod.SupplyDistrictCode;

        this.init();

        if (this.oSObject == null) {
            throw new EnergestSObjectWrapperException('oSObject has to be set after init()!');
        }
    }

    protected abstract Boolean hasChange();

    public abstract void reinitSObject(SObject oSObject);

    protected abstract void init();

    public abstract Map<String, Set<String>> getSObjectFields(Boolean inRelationToEnergestPod);

    public abstract EnergestEntityPod.DuplicateCheckPresentation getDuplicateCheckPresentation();

    /**
     * Get SObject checksum
     *
     * @return
     */
    public static String getChecksum(SObject oSObject) {

        //Map<String, Object> mapValues = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(oSObject));
        Map<String, Object> mapValues = oSObject.getPopulatedFieldsAsMap().clone();

        Map<String, SObjectField> mapDescribeFields = getDescribeFieldsForSObject(String.valueOf(oSObject.getSObjectType()));

        List<String> listPropertyNames = new List<String>();

        // Create ordered map
        // (https://releasenotes.docs.salesforce.com/en-us/summer15/release-notes/rn_apex_maps_and_sets_iteration_order.htm)
        for (String sPropertyName : mapValues.keySet()) {

            String sType = String.valueOf(mapDescribeFields.get(sPropertyName).getDescribe().getType());
            Object oValue = mapValues.get(sPropertyName);

            if (sType == 'REFERENCE' || sType == 'ID') {
                continue;
            }

            // Fix zero decimals by multiplying with 1
            if ((new Set<String>{'DOUBLE', 'LONG'}).contains(sType)) {
                //System.debug('oValue BEFORE: ' + oValue);
                oValue = Double.valueOf(String.valueOf(oValue)) * 1;
                mapValues.put(sPropertyName, oValue);
                //System.debug('oValue AFTER: ' + oValue);
            }

            listPropertyNames.add(sPropertyName);
        }

        listPropertyNames.sort();

        Map<String, Object> mapValuesOrdered = new Map<String, Object>();

        for (String sPropertyName : listPropertyNames) {
            // Only take values which not whitespace, not empty (''), and not null
            // because those wouldn't be returned from database!
            if (String.isNotBlank(String.valueOf(mapValues.get(sPropertyName)))) {
                mapValuesOrdered.put(sPropertyName, mapValues.get(sPropertyName));
            }
        }

        String sChecksumSource = JSON.serializePretty(mapValuesOrdered);
        String sChecksum = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(sChecksumSource)));

        //System.debug('String to build checksum for: ' + sChecksumSource);
        //System.debug('Checksum: ' + sChecksum);

        return sChecksum;
    }

    /**
     *
     *
     * @param prefix
     * @param lsetFields
     *
     * @return
     */
    protected Set<String> addRelationPrefixForSoqlFields(String prefix, Set<String> lsetFields) {

        Set<String> lsetNewFields = new Set<String>();

        for (String sField : lsetFields) {
            lsetNewFields.add(prefix + '.' + sField);
        }

        return lsetNewFields;
    }

    /**
     * getDescribeFieldsForSObject()
     *
     * @param SObjectName
     *
     * @return
     */
    public static Map<String, SObjectField> getDescribeFieldsForSObject(String SObjectName) {

        String DEBUG_HERE = DEBUG_HEADER + 'getDescribeFieldsForSObject() - ';

        if (!mapDescribeFieldsBySObject.containsKey(SObjectName)) {
            System.debug(DEBUG_HERE + 'Get describe for ' + SObjectName);
            mapDescribeFieldsBySObject.put(SObjectName, Schema.getGlobalDescribe().get(SObjectName).getDescribe().fields.getMap());
        }

        return mapDescribeFieldsBySObject.get(SObjectName);
    }

    /**
     * Sanitize given SObject
     *
     * @param SObjectToCheck
     *
     * @return
     */
    public static SObject sanitizeSObject(SObject SObjectToCheck) {

        String sSObjectType = String.valueOf(SObjectToCheck.getSObjectType());
        Map<String, SObjectField> mapDescribeFields = getDescribeFieldsForSObject(sSObjectType);

        for (String sFieldName : SObjectToCheck.getPopulatedFieldsAsMap().keySet()) {

            DescribeFieldResult oDescribeFieldResult = mapDescribeFields.get(sFieldName).getDescribe();
            Integer iMaxLength = oDescribeFieldResult.getLength();

            // Shorten field value to the max length of the field
            if (SObjectToCheck.get(sFieldName) != null && (new Set<String>{'STRING', 'TEXTAREA'}).contains(String.valueOf(oDescribeFieldResult.getType()))) {

                String sValue = (String)SObjectToCheck.get(sFieldName);
                sValue = sValue.replaceAll('[ ]{2,}', ' ').trim(); // whitespace handling
                sValue = sValue.length() > iMaxLength ? sValue.substring(0, iMaxLength) : sValue;

                SObjectToCheck.put(sFieldName, sValue);
            }
        }

        return SObjectToCheck;
    }

    /**
     * Capitalize each single word
     *
     * @param toCapitalize
     *
     * @return
     */
    public static String capitalizeEachWord(String toCapitalize) {

        if (toCapitalize != null) {

            toCapitalize = toCapitalize.toLowerCase();

            List<String> listParts = new List<String>();
            for (String sPart : toCapitalize.split('[ ]')) {
                listParts.add(sPart.capitalize());
            }
            toCapitalize = String.join(listParts, ' ');
        }

        return toCapitalize;
    }

    /**
     * Converts a Datetime to a Date
     *
     * @param datetimeToConvert
     *
     * @return
     */
    public static Date convertDatetimeToDate(Datetime datetimeToConvert) {

        return (datetimeToConvert != null) ?
                Date.newInstance(datetimeToConvert.year(), datetimeToConvert.month(), datetimeToConvert.day()) :
                null;
    }

    public class EnergestSObjectWrapperException extends Exception {}
}