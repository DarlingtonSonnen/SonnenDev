/**
 * Awattar Base Object
 *
 * Changelog
 * ---------
 *
 * v1.1.2-2018-01-11 (marko@die-interaktiven.de)
 * - Added methods lock() and isLocked() to prevent redundant callouts
 *
 * v1.1.0-2017-10-09 (marko@die-interaktiven.de, SOBCRM-1034)
 * - Revision with initAction() method which makes actions more flexible.
 *   Removed initFuture() accordingly.
 * - New method prepareAction() mainly to check if upsert is needed but can
 *   also be overriden.
 *
 * v1.0.0-2017-08-10
 * - initial
 *
 * @author Marko Schmalenbach <marko@die-interaktiven.de>
 * @version v1.1.2-2018-01-11
 */
public abstract class AwattarObject {

    // Action statuses for prepareAction()
    public static final String ACTION_STATUS_ERROR = 'error';
    public static final String ACTION_STATUS_OK = 'ok';
    public static final String ACTION_STATUS_NOT_REQUIRED = 'not_required';

    // General action
    public static final String ACTION_UPSERT = 'upsert';
    
    protected Map<String,Object> awattarFields = new Map<String,Object>();

    protected Map<String,Map<String,String>> updateFields = new Map<String,Map<String,String>>();

    protected String error = '';

    public Id sObjectId;

    private static Map<String,Set<Id>> lockedObjectsPerCalloutType = new Map<String,Set<Id>>();

    //---------------------------------------------------------
    // Methods to implement
    //---------------------------------------------------------

    protected abstract void initAwattarFields();

    protected abstract void setAwattarFieldsFromObjectMap(Map<String,Object> mapFields);

    public abstract Boolean validate();

    public abstract Boolean needsSync();

    public abstract void initAction(String action);

    public abstract Boolean actionPersist();

    //---------------------------------------------------------
    // Virtual methods
    //---------------------------------------------------------
    /**
     * Return awattarFields
     */
    public virtual Map<String,Object> getAwattarFields() {
        return this.awattarFields;
    }

    /**
     * Check if a certain action
     */
    public virtual String prepareAction(String action) {

        if (action == ACTION_UPSERT) {
            if (this.needsSync() == TRUE) {
                return this.validate() ? ACTION_STATUS_OK : ACTION_STATUS_ERROR;
            }
            else {
                return ACTION_STATUS_NOT_REQUIRED;
            }
        }

        return ACTION_STATUS_OK;
    }

    /**
     * Return update fields
     */
    public virtual Map<String,Map<String,String>> getUpdateFields() {
        return this.updateFields;
    }

    //---------------------------------------------------------
    // Other methods
    //---------------------------------------------------------
    /**
     * Register object ID as locked for the given callout
     * type to prevent redundant callouts
     *
     * @since 2018-01-11
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
     * @since 2018-01-11
     */
    public void removeLock(String calloutType) {
        if (this.isLocked(calloutType)) {
            lockedObjectsPerCalloutType.get(calloutType).remove(this.sObjectId);
        }
    }

    /**
     * Check if object ID is locked for the given callout type
     *
     * @since 2018-01-11
     */
    public Boolean isLocked(String calloutType) {
        return (lockedObjectsPerCalloutType.containsKey(calloutType) && lockedObjectsPerCalloutType.get(calloutType).contains(this.sObjectId));
    }

    /**
     * Return last error
     */
    public String getError() {
        return this.error;
    }

    /**
     * Return if an error exists
     */
    public Boolean hasError() {
        return (this.error.length() > 0);
    }

    /**
     * Set an error
     */
    protected void setError(String error) {
        this.error = error;
    }

    /**
     * Set aWATTar request fields
     *
     * This will get all fields of the given object starting by
     * Awattar_
     */
    protected void setAwattarFieldsFromObject(SObject objectToConvert) {

        // Handle fields Awattar_(.+)__c
        Pattern oAwattarPattern = Pattern.compile('^Awattar_(.+)__c');

        Map<String,Object> mapAwattarFields = new Map<String,Object>();

        Map<String,Schema.SObjectField> mapSchemaField = objectToConvert.getSobjectType().getDescribe().fields.getMap();

        for (Schema.SObjectField sObjectField : mapSchemaField.values()) {

            DescribeFieldResult oFieldDescribe = sObjectField.getDescribe();
            String sFieldName = oFieldDescribe.getName();

            Matcher matcher = oAwattarPattern.matcher(sFieldName);

            if (matcher.matches()) {

                Object oValue = objectToConvert.get(sFieldName);

                // Format date as it's expected in german locale
                if (oValue != NULL && String.valueOf(oFieldDescribe.getType()) == 'DATE') {
                    Date dDate = Date.valueOf(oValue);
                    oValue = (Object)DateTime.newInstance(dDate.year(), dDate.month(), dDate.day()).format('dd.MM.YYYY');
                }

                mapAwattarFields.put(matcher.group(1), oValue);
            }
        }

        this.setAwattarFieldsFromObjectMap(mapAwattarFields);
    }

    /**
     * Get information for error cases
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-741
     */
    public Case prepareErrorCase() {

        Map<String,String> mapReturn = new Map<String,String>();

        Id idRecordType = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Case', 'eServices');

        Case oCase = new Case(
            RecordTypeId   = idRecordType,
            Status         = 'Open',
            Priority       = 'Normal',
            Type           = 'Problem'
        );

        return oCase;
    }

    /**
     * Custom Exception
     */
    public class AwattarObjectException extends Exception {}
}