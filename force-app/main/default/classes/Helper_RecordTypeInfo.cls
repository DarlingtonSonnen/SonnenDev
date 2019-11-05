/**
 * fetches all record types and buffers them into a singleton map 
 * with keys sObjectName and RecordType.DeveloperName, both case insensitive
 * 
 * @author Daniel Stange <daniel.stange@die-interaktiven.de>
 * @version 2016-04-08 daniel.stange@die-interaktiven.de    Initial release version
 * 
 */

public class Helper_RecordTypeInfo {
    
    private static Map<String, Map<String, ID>> rtCache;
    
    public static Id rtInfo(String s, String t) {
        if (rtCache == NULL) {
            getRecordTypes();
            System.debug('ran init');
            System.debug('recordtype list: ' + rtCache);
        }
        
        if (
            rtCache.get(s.toUpperCase()) != NULL 
            && rtCache.get(s.toUpperCase()).get(t.toUpperCase()) != NULL
        ) {
            return rtCache.get(s.toUpperCase()).get(t.toUpperCase());    
        }
        else return NULL;
        
    }
    
    public static Map<String, Map<String, Id>> rtInfo() {
        if (rtCache == NULL) {
            getRecordTypes();
            System.debug('ran init');
            System.debug('recordtype list: ' + rtCache);
        }
        
        return rtCache;
        
    }
    
    @testvisible private static void getRecordTypes() {
        
        rtCache = new Map<String, Map<String, ID>>();
        
        List<RecordType> rt = [SELECT ID, DeveloperName, sObjectType FROM RecordType WHERE isActive = true];
        
        for (RecordType r : rt) {
            
            if (rtCache.containsKey(r.sObjectType.toUpperCase()) ) {
                rtCache.get(r.sObjectType.toUpperCase()).put(r.DeveloperName.toUpperCase(), r.Id);
            }
            else {
                rtCache.put(r.sObjectType.toUpperCase(), new Map<String, Id>{r.DeveloperName.toUpperCase() => r.Id});
            } 
        } 
    }
}