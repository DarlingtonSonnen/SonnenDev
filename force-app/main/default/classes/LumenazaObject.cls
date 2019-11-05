/**
 * Lumenaza Base Object
 *
 * Changelog
 * ---------
 *
 * v1.7.0-2018-07-05 (SOBCRM-1228)
 * - Remove Stage on cases - 'Sync Lumenaza Error'
 *
 * v1.6.0-2018-04-13 (marko@die-interaktiven.de, SOBCRM-1175)
 * - Implemented "suppressComplexDebugMessages"
 *
 * v1.5.0-2018-04-10 (marko@die-interaktiven.de)
 * - Revised with lumenazaFields as Map<String,Object>
 *
 * v1.4.0 (MSB 2017-12-05)
 * - Added methods lock() and isLocked() to prevent redundant callouts
 *
 * v1.3.0 (MSB 2016-12-16)
 * - getLumenazaFields() is now virtual to be able to overwrite it in extending classes
 *
 * v1.2.0 (MSB 2016-12-14)
 * - setLumenazaFieldsFromObject(): Type - changed everything with "contract" to "object"
 * - Added virtual methods hasCustomUpsert(), customUpsert(), processObjectsForUpsert() and
 *   getUpdateFields() in the course of the implementation of the Lumenaza Contract Change
 *   mechanism (SOBCRM-669)
 *
 * v1.1.0
 * - setLumenazaFieldsFromObject(): If a Lumenaza API field name is very long
 *   than so that the matching formula field would be longer than 40 characters
 *   one can set an alias in the lumenazaFields
 *
 * v1.0.0
 * - Initial
 *
 * @version 1.6.0-2018-04-13
 */
public abstract class LumenazaObject {

    public static Boolean suppressComplexDebugMessages = false;

	protected Map<String,Object> lumenazaFields = new Map<String,Object>();

    protected Map<String,Map<String,String>> updateFields = new Map<String,Map<String,String>>();

    protected String error = '';

    public Id sObjectId;

    private static Map<String,Set<Id>> lockedObjectsPerCalloutType = new Map<String,Set<Id>>();

    public abstract Boolean validate();

    protected abstract void initLumenazaFields();

    public abstract Boolean needsUpdate();

    public abstract void initFutureUpsert();

    public abstract Boolean persist();

    protected void setError(String error) {
        this.error = error;
    }

    public String getError() {
    	return this.error;
    }

    public Boolean hasError() {
        return (this.error.length() > 0);
    }

    public virtual Map<String,Object> getLumenazaFields() {
        return this.lumenazaFields;
    }

    /**
     * Register object ID as locked for the given callout
     * type to prevent redundant callouts
     *
     * @since 2017-12-05
     */
    public void lock(String calloutType) {

        if (!lockedObjectsPerCalloutType.containsKey(calloutType)) {
            lockedObjectsPerCalloutType.put(calloutType, new Set<Id>());
        }
        lockedObjectsPerCalloutType.get(calloutType).add(this.sObjectId);
    }

    /**
     * Check if object ID is locked
     *
     * @since 2017-12-05
     */
    public void removeLock(String calloutType) {
        if (this.isLocked(calloutType)) {
            lockedObjectsPerCalloutType.get(calloutType).remove(this.sObjectId);
        }
    }

    /**
     * Check if object ID is locked for the given callout type
     *
     * @since 2017-12-05
     */
    public Boolean isLocked(String calloutType) {
        return (lockedObjectsPerCalloutType.containsKey(calloutType) && lockedObjectsPerCalloutType.get(calloutType).contains(this.sObjectId));
    }

    protected void setLumenazaFieldsFromObject(SObject objectToConvert) {

        // Convert value into map
        Map<String,Object> objectFields = objectToConvert.getPopulatedFieldsAsMap();

        Pattern lumenazaPattern = Pattern.compile('^Lumenaza_(.+)__c');

        // Set fields Lumenaza_(.+)__c dynamically to this.lumenazaFields
        // (they must be defined in this.lumenazaFields)
        for (String fieldName : objectFields.keySet()) {

            Matcher matcher = lumenazaPattern.matcher(fieldName);

            if (matcher.matches() == true && this.lumenazaFields.containsKey(matcher.group(1))) {

                String fieldNameLumenazaField = matcher.group(1);

                // If a Lumenaza API field name is very long than so that the matching
                // formula field would be longer than 40 characters one can set an alias
                // in the lumenazaFields
                if (this.lumenazaFields.get(fieldNameLumenazaField) != null) {
                    String fieldNameLumenazaFieldNew = String.valueOf(this.lumenazaFields.get(fieldNameLumenazaField));
                    this.lumenazaFields.remove(fieldNameLumenazaField);
                    fieldNameLumenazaField = fieldNameLumenazaFieldNew;
                }

                this.lumenazaFields.put(fieldNameLumenazaField, objectFields.get(fieldName));
            }
        }

        if (!suppressComplexDebugMessages) {
            System.debug('LumenazaObject.setLumenazaFieldsFromObject() - Lumenaza fields: ' + JSON.serializePretty(this.lumenazaFields));
        }

    }
    /**
     * Should an upsert be handled by class itsself?
     */
    public virtual Boolean hasCustomUpsert() {
        return FALSE;
    }

    /**
     * Handle upsert by class itsself
     */
    public virtual Boolean customUpsert() {
        return TRUE;
    }

    public virtual Boolean processObjectsForUpsert() {
        return TRUE;
    }

    /**
     * Return update fields
     */
    public virtual Map<String,Map<String,String>> getUpdateFields() {
        return this.updateFields;
    }

    /**
     * Get information for error cases
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-741
     */
    public Case prepareErrorCase() {

        Map<String,String> mapReturn = new Map<String,String>();

        Id idRecordType = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Case', 'eServices');

        //1.7.0 - remove stage
        Case oCase = new Case(
            RecordTypeId   = idRecordType,
            Subcategory__c = 'E13, Sonstiges',
            Status         = 'Open',
            Priority       = 'Normal',
            Type           = 'Problem'
        );

        return oCase;
    }

    /**
     * Ensure max length of a string
     */
    protected String ensureMaxLength(String text, Integer maxLength) {
        return (text != NULL && text.length() > maxLength) ? text.substring(0, 5000) : text;
    }

    /**
     * Custom Exception
     */
	public class LumenazaObjectException extends Exception {}
}