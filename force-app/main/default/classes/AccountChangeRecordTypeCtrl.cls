/**
 * AccountChangeRecordTypeCtrl
 *
 * Used as controller for lightning component that transforms Record Types:
 *     PersonAmbassador <-> Ambassador
 *     Private <-> BusinessAccount
 *     
 * @author Polina Drobot <polina.drobot@codeswat.com>
 * @version 1.0.0 - 2017-08-17
 */
public class AccountChangeRecordTypeCtrl {

    @testVisible
    private static String ACCOUNT = 'Account';

    @testVisible
    private static String RT_PERSON_AMBASSADOR = 'PersonAmbassador';
    @testVisible
    private static String RT_PRIVATE = 'Private';
    @testVisible
    private static String RT_AMBASSADOR = 'Ambassador';
    @testVisible
    private static String RT_BUSINESS_ACCOUNT = 'BusinessAccount';

    private static String CONTACTS_NUM_MSG = 'Cannot change the Record Type of Accont, because it should have 1 Contact.';
    private static String PARENT_EXISTS_MSG = 'Cannot change the Record Type of Accont, because it has filled Parent Account field.';
    private static String REPORT_TO_EXISTS_MSG = 'Cannot change the Record Type of Accont, because it\'s Contact has filled Reports To field.';
    private static String ANOTHER_RT = 'The functionality is not available for this Record Type.';
    
    private static Map<Id,Id> RT_MAPPING;

    static {
        formRTMapping();
    }

    @AuraEnabled
	public static void changeRTFromBusinessToPrivate(Id accId) {
        Account acc = retrieveAccount(accId);
        checkIfCanBeProcessed(acc);
        checkBusinessToPrivateConvertionConditions(acc);
        changeRT(acc);
        updateAcc(acc);
    }

    private static void formRTMapping() {
        List<RecordType> rtList = [
            SELECT Id, DeveloperName
            FROM RecordType 
            WHERE SobjectType = :ACCOUNT
                AND DeveloperName IN (:RT_PERSON_AMBASSADOR, :RT_PRIVATE, :RT_AMBASSADOR, :RT_BUSINESS_ACCOUNT)
        ];
        
        Map<String,Id> rtMap = new Map<String,Id>();
        for(RecordType rt : rtList) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }

        RT_MAPPING = new Map<Id,Id> {
            rtMap.get(RT_AMBASSADOR) => rtMap.get(RT_PERSON_AMBASSADOR),
            rtMap.get(RT_PERSON_AMBASSADOR) => rtMap.get(RT_AMBASSADOR),
            rtMap.get(RT_BUSINESS_ACCOUNT) => rtMap.get(RT_PRIVATE),
            rtMap.get(RT_PRIVATE) => rtMap.get(RT_BUSINESS_ACCOUNT)
        };
    }

    private static Account retrieveAccount(Id accId) {
        return [
            SELECT  Id, 
                    RecordTypeId,
                    RecordType.DeveloperName,
                    (SELECT Id, ReportsToId FROM Contacts),
                    ParentId
            FROM Account
            WHERE Id = :accId
        ];
    }
    
    private static void checkIfCanBeProcessed(Account acc) {
        
        if(!RT_MAPPING.keySet().contains(acc.RecordTypeId)) {
            throw new AuraHandledException(ANOTHER_RT);
        }
    }

    private static void checkBusinessToPrivateConvertionConditions(Account acc) {
        
        if(acc.RecordType.DeveloperName == RT_AMBASSADOR || acc.RecordType.DeveloperName == RT_BUSINESS_ACCOUNT) {

            if(acc.Contacts.size() != 1) {
                throw new AuraHandledException(CONTACTS_NUM_MSG);
            }

            if(acc.ParentId != null) {
                throw new AuraHandledException(PARENT_EXISTS_MSG);
            }
            
            if(acc.Contacts.size() == 1 && acc.Contacts[0].ReportsToId != null) {
                throw new AuraHandledException(REPORT_TO_EXISTS_MSG);
            }
        }
    }

    private static void changeRT(Account acc) {
        System.debug(acc.RecordTypeId + '  ->  ' + RT_MAPPING.get(acc.RecordTypeId));
        acc.RecordTypeId = RT_MAPPING.get(acc.RecordTypeId);
    }

    private static void updateAcc(Account acc) {
        try {
            update acc;
        } catch(Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }        
    }

}