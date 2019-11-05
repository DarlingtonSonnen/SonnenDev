/**
 * MeterInstallationTriggerHandler
 *
 * Changelog
 * ---------
 *
 * v1.0.0-2017-10-30
 * - Initial
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.1.0-2017-10-30
 */
public class MeterInstallationTriggerHandler extends TriggerHandler {

    private static Set<String> bypassedMethods = new Set<String>();

    private static final String DEBUG_HEADER = 'MeterInstallationTriggerHandler.';

    private Map<Id,MeterInstallation__c> mapMeterInstallationsBefore;
    private Map<Id,MeterInstallation__c> mapMeterInstallationsAfter;

    //---------------------------------------------------------------------
    // Static methods to bypass
    //---------------------------------------------------------------------
    public static void bypassMethod(String methodName) {
        bypassedMethods.add(methodName);
    }

    public static void clearBypassMethod(String methodName) {
        bypassedMethods.remove(methodName);
    }

    public static Boolean isBypassedMethod(String methodName) {
        return bypassedMethods.contains(methodName);
    }

    public static void clearAllBypassMethods() {
        bypassedMethods.clear();
    }

    /**
     * Constructor sets trigger values to make them accessable for other methods
     */
    public MeterInstallationTriggerHandler() {
        this.mapMeterInstallationsAfter  = (Map<Id,MeterInstallation__c>) Trigger.newMap;
        this.mapMeterInstallationsBefore = (Map<Id,MeterInstallation__c>) Trigger.oldMap;
    }

    //---------------------------------------------------------------------
    // Overridden methods
    //---------------------------------------------------------------------
    public override void afterUpdate() {
        this.syncToLumenaza();
    }

    public override void afterInsert() {
        this.syncToLumenaza();
    }

    /**
     * Sync to Lumenaza
     *
     * @since 2017-11-01
     */
    private void syncToLumenaza() {

        String DEBUG_HERE = DEBUG_HEADER + 'syncToLumenaza() - ';

        if (isBypassedMethod('syncToLumenaza')) {
            System.debug(DEBUG_HERE + 'is bypassed!');
            return;
        }

        Set<LumenazaObject> lumenazaObjectsToUpsert = new Set<LumenazaObject>();
        List<MeterInstallation__c> listMeterInstallations = (List<MeterInstallation__c>) Trigger.new;

        System.debug(DEBUG_HERE + 'listMeterInstallations: ' + JSON.serializePretty(listMeterInstallations));

        for (MeterInstallation__c meterInstallationAfter : listMeterInstallations) {
            if (meterInstallationAfter.LumenazaApiIsSyncable__c) {

                LumenazaMeterInstallation oLumenazaMeterInstallation = new LumenazaMeterInstallation(meterInstallationAfter);

                if (Trigger.isUpdate) {
                    oLumenazaMeterInstallation.setMeterInstallationBefore(this.mapMeterInstallationsBefore.get(meterInstallationAfter.Id));
                }
                
                lumenazaObjectsToUpsert.add(oLumenazaMeterInstallation);
            }
        }

        System.debug(DEBUG_HERE + 'lumenazaObjectsToUpsert: ' + lumenazaObjectsToUpsert.size());

        if (!lumenazaObjectsToUpsert.isEmpty()) {

            // Init upsert of MeterInstallations
            if (LumenazaApi.initUpsert(lumenazaObjectsToUpsert) == FALSE) {

                for (LumenazaObject lumenazaObject : lumenazaObjectsToUpsert) {

                    LumenazaMeterInstallation lumenazaMeterInstallation = (LumenazaMeterInstallation)lumenazaObject;

                    if (lumenazaMeterInstallation.hasError() == true) {
                        lumenazaMeterInstallation.getMeterInstallation().addError(lumenazaMeterInstallation.getError());
                    }
                }
            }
        }
    }
}