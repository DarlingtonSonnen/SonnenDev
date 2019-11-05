/**
 * BankDataTriggerHandler
 *
 * @version 1.1.0 (2016-12-16)
 *
 * Changelog
 * ---------
 * v1.3.2   2019-08-21  Marko Schmalenbach          enrichBankInfo(): Added requesting of queueable limit
 * v1.3.1 (2018-06-14)
 * By Bartosz Jarmolinski
 * fixing enrichBankInfo method - fixed list passed to the queueable class - should be validated list instead of the whole trigger.new
 *
 * v1.3.0 (2018-02-28)
 * - @Author: Bartosz Jarmolinski
 * - added enrichBankInfo() - after insert method
 * - the method invokes a queueable class which calls external service for additional bank-related data
 *
 * v1.2.0 (DUR 2017-12-13, SOBCRM-1004)
 * - Account.CustomerNoDatev should be created immediately upon BankData creation
 *
 * v1.1.0 (MSB 2016-12-20, SOBCRM-754)
 * - Added onUpdate handling: Change related Contract's bank data accordingly
 * - Added onDelete handling: Raise and error if BankdDate is deleted which is
 *    related to any Conracts
 * - Fix: handleBeforeInsert() didn't consider inserting multiple BankDatas for one Account
 *
 * v1.0.0 (DUR 2016-12-16, SOBCRM-733)
 * - Initial: Before Insert Trigger Handler for BankData Community Contracts - populates SepaReference field for
 *   the new records. Although main change regarding 733 is in RESTContract class, SepaReference field is filled
 *   via trigger, due to complex logic, unachievable in the REST class - SepaRef = Account.CustomerNoDatev + ACC_BANKDATAs_COUNT
 *   E.g. for an Account with existing related two BankData records, the SepaRef would end with ...0003
 *
 */
public class BankDataTriggerHandler extends TriggerHandler {

    private final String DEBUG_HEADER = 'BankDataTriggerHandler';

    public static final Map<String,String> mapMappingBankDataContractFields = new Map<String,String>{
        'FirstName__c'     => 'BankDataFirstname__c',
        'LastName__c'      => 'BankDataLastname__c',
        'IBAN__c'          => 'BankDataIBAN__c',
        'SWIFT__c'         => 'BankDataSWIFT__c',
        'SepaDate__c'      => 'SEPADate__c',
        'SepaReference__c' => 'MandateReferenceNumber__c'
    };

    public override void beforeUpdate() {
        this.updateRelatedContracts();
    }

    public override void beforeDelete() {
        this.checkForRelatedContractsOnDeletion();
    }

    public override void beforeInsert() {
        this.handleBeforeInsert();
    }

    public override void afterInsert() {
        this.enrichBankInfo();
    }

    /**
     * Check for related Contracts on deletion and raise an
     * error if so
     *
     * @since 2016-12-16
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     */
    public void checkForRelatedContractsOnDeletion() {

        List<BankData__c> listBankData = (List<BankData__c>)Trigger.old;

        Map<Id,BankData__c> mapBankData = new Map<Id, BankData__c>();
        for (BankData__c oBankData : listBankData) {
            mapBankData.put(oBankData.Id, oBankData);
        }

        List<Contract> listContracts = new List<Contract>([SELECT Id, ContractNumber, BankData__c FROM Contract WHERE BankData__c IN :mapBankData.keySet()]);
        Map<Id,Set<String>> mapBankDataToContractNumbers = new Map<Id, Set<String>>();

        if (!listContracts.isEmpty()) {

            // Collect related Contracts for BankData
            for (Contract oContract : listContracts) {

                Id idBankData = oContract.BankData__c;

                if (mapBankDataToContractNumbers.get(idBankData) == NULL) {
                    mapBankDataToContractNumbers.put(idBankData, new Set<String>());
                }
                mapBankDataToContractNumbers.get(idBankData).add(oContract.ContractNumber);
            }

            if (!mapBankDataToContractNumbers.isEmpty()) {
                for (Id idBankData : mapBankDataToContractNumbers.keySet()) {

                    BankData__c oBankData = mapBankData.get(idBankData);
                    Set<String> lsetContractNumbers = mapBankDataToContractNumbers.get(idBankData);
                    Integer iCountContracts = lsetContractNumbers.size();

                    oBankData.addError('Bank Data ' + oBankData.Name + ' is related to ' + iCountContracts + ' Contract' + (iCountContracts > 1 ? 's' : '') + ' and therefore cannot be deleted! (Contract' + (iCountContracts > 1 ? 's' : '')+ ': ' + String.join(new List<String>(lsetContractNumbers), ', ') + ')');
                }
            }
        }
    }

    /**
     * Update related Contract's bank data fields according
     * to changed BankData values
     *
     * @since 2016-12-16
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     */
    public void updateRelatedContracts() {

        String sDebugHere = DEBUG_HEADER + '.updateRelatedContracts() - ';

        Map<Id,BankData__c> mapBankDataOld = (Map<Id,BankData__c>)Trigger.oldMap;
        Map<Id,BankData__c> mapBankDataNew = new Map<Id,BankData__c>();

        for (BankData__c oBankData : (List<BankData__c>)Trigger.new) {

            BankData__c oBankDataOld = mapBankDataOld.get(oBankData.Id);

            for (String sField : mapMappingBankDataContractFields.keySet()) {
                if (oBankData.get(sField) != oBankDataOld.get(sField)) {
                    mapBankDataNew.put(oBankData.Id, oBankData);
                    break;
                }
            }
        }

        // Find all Contracts with relevant BankData relations
        if (!mapBankDataNew.isEmpty()) {

            Set<Id> lsetChangedBankDataObjectIds = mapBankDataNew.keySet();
            System.debug(sDebugHere + 'Find Contracts with BankData relations to BankData objects ' + String.join(new List<Id>(lsetChangedBankDataObjectIds), ','));

            List<Contract> listContracts = (List<Contract>)Database.query('SELECT Id,BankData__c,' + String.join(mapMappingBankDataContractFields.values(), ',') + ' FROM Contract WHERE BankData__c IN :lsetChangedBankDataObjectIds');
            List<Contract> listContractsToUpdate = new List<Contract>();

            if (!listContracts.isEmpty()) {

                // Find Contracts which are to update:
                // Check each field and only update if necessary
                for (Contract oContract : listContracts) {

                    Boolean isToUpdate = FALSE;
                    BankData__c oBankData = mapBankDataNew.get(oContract.BankData__c);

                    for (String sBankDataField : mapMappingBankDataContractFields.keySet()) {

                        String sContractField = mapMappingBankDataContractFields.get(sBankDataField);

                        if (oBankData.get(sBankDataField) != oContract.get(sContractField)) {
                            oContract.put(sContractField, oBankData.get(sBankDataField));
                            System.debug(sDebugHere + '(' + (Trigger.isInsert ? 'INSERT' : (Trigger.isUpdate ? 'UPDATE' : 'Unknown trigger context')) + ') Set Contract field "' + sContractField + '" to "' + oBankData.get(sBankDataField) + '"');
                            isToUpdate = TRUE;
                        }
                    }

                    if (isToUpdate) {
                        listContractsToUpdate.add(oContract);
                    }
                }

                if (!listContractsToUpdate.isEmpty()) {
                    System.debug(sDebugHere + 'Make update on Contracts: ' + listContractsToUpdate);
                    update listContractsToUpdate;
                }
            }
        }
    }

    public void handleBeforeInsert() {

        String sDebugHere = DEBUG_HEADER + '.handleBeforeInsert() - ';

        List<BankData__c> triggerNew = (List<BankData__c>)trigger.new;

        Set<Id> bankDataAccountIds = new Set<Id>();
        for(BankData__c oBankData : triggerNew) {
            bankDataAccountIds.add(oBankData.Account__c);
        }

        Map<Id,Account> mapAccounts = new Map<Id,Account>([
            SELECT
                Id,
                CustomerNoDatev__c,
                (SELECT
                    Id, SepaReference__c, Account__r.CustomerNoDatev__c
                FROM
                    Bank_Data__r
                WHERE
                    SepaReference__c != NULL
                ORDER BY
                    SepaReference__c ASC)
            FROM
                Account
            WHERE
                Id IN :bankDataAccountIds
        ]);

        // DUR, 13.12.2017 - SOBCRM-1004
        List<Account> accountsWithoutDatev = new List<Account>();

        Map<Id,List<BankData__c>> mapAccountBankData = new Map<Id,List<BankData__c>>();

        for (Account oAccount : mapAccounts.values()) {

            mapAccountBankData.put(oAccount.Id, new List<BankData__c>());

            if (oAccount.Bank_Data__r != null && oAccount.Bank_Data__r.size() > 0) {
                mapAccountBankData.get(oAccount.Id).addAll(oAccount.Bank_Data__r);
            }

            // DUR, 13.12.2017 - SOBCRM-1004
            if (String.isBlank(oAccount.CustomerNoDatev__c))
                accountsWithoutDatev.add(oAccount);
        }

        // DUR, 13.12.2017 - SOBCRM-1004
        Integer iNextCustomerNo = AccountService.getNextDatevNumber();
        AccountService.updateAccountsCustomerDatevNumber(accountsWithoutDatev, iNextCustomerNo);

        for (BankData__c oBankData : triggerNew) {

            Id idAccount = oBankData.Account__c;

            if (mapAccounts.containsKey(idAccount)) {

                Integer iLastAccBankDataIndex = 1;
                Account oAccount = mapAccounts.get(idAccount);
                List<BankData__c> listAccountBankDatas = mapAccountBankData.get(idAccount);

                // If Account already has related BankDatas, get value of SepaReference from last BankData for the Account
                if (!listAccountBankDatas.isEmpty()) {

                    BankData__c oLastBankData = listAccountBankDatas.get(listAccountBankDatas.size() - 1);

                    String sLastBankDataSepaReference = oLastBankData.SepaReference__c.right(7);
                    iLastAccBankDataIndex = Integer.valueOf(sLastBankDataSepaReference) + 1;
                }

                oBankData.SepaReference__c = oAccount.CustomerNoDatev__c + String.valueOf(iLastAccBankDataIndex).leftPad(7, '0');

                // Add to list of Account's BankDatas!
                listAccountBankDatas.add(oBankData);

                System.debug(sDebugHere + 'New SEPA reference: ' + oBankData.SepaReference__c);
            }
        }
    }
    public void enrichBankInfo() {

        // find bank data settings in custom metadata types (CMDT)
        BankDataSetting__mdt bds = [SELECT Id, Countries__c, TriggerOn__c FROM BankDataSetting__mdt WHERE MasterLabel = 'TriggerSettings'];
        List<BankData__c> triggernew = (List<BankData__c>) Trigger.new;
        List<BankData__c> bdList = new List<BankData__c>();

        //if trigger is on in the CMDT, execute the rest of the logic
        if(bds.TriggerOn__c == true) {
            for(BankData__c bn : triggernew) {
                System.debug(bn);

                 //if IBAN isn't null and IBAN prefix corresponds to the countries allowed in the CMDT,
                 // add the BankData__c record to the list which will be passed as parameter to the queueable class
                if(bn.IBAN__c != null && bds.Countries__c.contains(bn.IBAN__c.left(2)) ) {
                    bdList.add(bn);
                }
            }

            if ((Limits.getLimitQueueableJobs() - Limits.getQueueableJobs()) > 0) {
                System.debug('Enqueue IBANChecker4');
                IBANChecker4 ic = new IBANChecker4(bdList);
                System.enqueueJob(ic);
            }
        }
    }
}