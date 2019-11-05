/**
 * BankDataTriggerHandlerTest
 * 
 * @author	dino.ursic@die-interaktiven.de
 * @desc	Test class for BankDataTriggerHandler
 * @version 1.1.0 (2017-12-20)
 * 
 * Changelog:
 * v1.1.0 (DUR, 2017-12-20)
 * - Marko's testBankDataChange() test method pulled in from GeneralTriggerTest to provide full coverage for the class
 * 
 * v1.0.0 (DUR, 2017-12-14)
 * - Initial version
 */ 
@isTest
public class BankDataTriggerHandlerTest {
    
    private static final String DEBUG_HEADER = 'BankDataTriggerHandlerTest.';

    /**
     * SOBCRM-1004
     * Verifies that BankData records added to Accounts without CustomerNoDatev will eventually still get
     * the required SepaReference created. BankData SepaReference is composed out of Account's CustomerNoDatev
     * appended with 7-figured (0-leading) index number of the BankData within a particular Account.
     */
    public static testMethod void testAddingBankDateToContractlessAccount() {
        
        // Reference account with the latest CustomerNoDatev
        Account refAcc = new Account(Name='ACME Ref GmbH', CustomerNoDatev__c='55555');
        insert refAcc;
        
        // Test account without CustomerNoDatev
        Account testAcc = new Account(Name='ACME Test GmbH');
        insert testAcc;
        
        BankData__c bd = new BankData__c();
        bd.Account__c = testAcc.Id;
        bd.FirstName__c = 'Max';
        bd.LastName__c = 'Mustermann';
        bd.IBAN__c = 'DE67 1111 1111 1111 1111';
        bd.SWIFT__c = 'SPKDE123';
        insert bd;
        
        bd = [SELECT Id, SepaReference__c, Account__r.CustomerNoDatev__c FROM BankData__c WHERE Account__c = :testAcc.Id];
        
        system.assert(bd != null);
        system.assert(String.isNotBlank(bd.SepaReference__c));
        system.assert(bd.SepaReference__c.startsWith(bd.Account__r.CustomerNoDatev__c));
    }
    
    /*+
     * Test change of BankData:
     * - Insert of Contract with BankData relation
     * - Update of related BankData on Contract
     * - Deletion of BankData with related Contracts
     * - Deletion of BankData reference on Contract
     *
     * @since 2016-12-16
     * @see https://interaktiv.jira.com/browse/SOBCRM-754
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     */
    @isTest static void testBankDataChange() {

        String sDebugHere = DEBUG_HEADER + '.testBankDataChange() - ';

        Account oAccount = new Account(
            Name = 'ACME Corp.',
            CustomerNoDatev__c = '10119'
        );
        insert oAccount;

        List<BankData__c> listBankDatas = new List<BankData__c>();

        listBankDatas.add(new BankData__c(
            Account__c       = oAccount.Id,
            FirstName__c     = 'Holger',
            LastName__c      = 'Wind',
            SWIFT__c         = 'TESTSWIFT1',
            IBAN__c          = 'DE6523400093201313900',
            SepaDate__c      = Date.today().addDays(-2)
        ));
        listBankDatas.add(new BankData__c(
            Account__c       = oAccount.Id,
            FirstName__c     = 'Hans',
            LastName__c      = 'Hobel',
            SWIFT__c         = 'TESTSWIFT4',
            IBAN__c          = 'DE6523400093201234565',
            SepaDate__c      = Date.today().addDays(-7)
        ));
        insert listBankDatas;

        Map<Id,BankData__c> mapBankDatas = new Map<Id,BankData__c>([
            SELECT
                Id,
                FirstName__c,
                LastName__c,
                SWIFT__c,
                IBAN__c,
                SepaDate__c,
                SepaReference__c
            FROM
                BankData__c
            WHERE
                Id IN :listBankDatas
        ]);

        // Take first BankData
        BankData__c oBankData = mapBankDatas.get(listBankDatas.get(0).Id);

        Contract oContract = new Contract(
            RecordTypeId              = [SELECT Id FROM RecordType WHERE IsActive = true AND SObjectType = 'Contract' AND DeveloperName = 'Energy'].Id,
            Type__c                   = 'sonnenbatterieHome-DE',
            TariffType__c             = 'household',
            AccountId                 = oAccount.Id,
            Status                    = 'Draft',
            BankDataFirstname__c      = 'Peter',
            BankDataLastname__c       = 'Lustig',
            BankDataSWIFT__c          = 'TESTSWIFT2',
            BankDataIBAN__c           = 'DE6523400093201313911',
            SEPADate__c               = Date.today(),
            BankData__c               = listBankDatas.get(0).Id
        );

        Map<String,String> mapMappingBankDataContractFields = BankDataTriggerHandler.mapMappingBankDataContractFields;
        System.assert(mapMappingBankDataContractFields != NULL);

        Test.startTest();

        insert oContract;

        Id idContract = oContract.Id;
        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = :idContract');

        // Field values should match
        for (String sBankDataField : mapMappingBankDataContractFields.keySet()) {
            String sContractField = mapMappingBankDataContractFields.get(sBankDataField);
            System.assert(oBankData.get(sBankDataField) == oContract.get(sContractField), 'BankData field value for ' + sBankDataField + ' and Contract field value for ' + sContractField + ' should match: ' + oBankData.get(sBankDataField) + ' <> ' + oContract.get(sContractField));
        }

        // Update BankData and expect update on Contract
        oBankData.FirstName__c = 'Dieter';
        oBankData.LastName__c  = 'Sonne';
        oBankData.SWIFT__c     = 'TESTSWIFT3';
        oBankData.IBAN__c      = 'DE6523400093201313901';
        oBankData.SepaDate__c  = Date.today().addDays(-10);
        update oBankData;

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = :idContract');

        // Field values should match
        for (String sBankDataField : mapMappingBankDataContractFields.keySet()) {
            String sContractField = mapMappingBankDataContractFields.get(sBankDataField);
            System.assert(oBankData.get(sBankDataField) == oContract.get(sContractField), 'BankData field value for ' + sBankDataField + ' and Contract field value for ' + sContractField + ' should match: ' + oBankData.get(sBankDataField) + ' <> ' + oContract.get(sContractField));
        }

        // Try to delete BankData must fail due to related Contract
        Boolean hadException = FALSE;

        try {
            delete oBankData;
        }
        catch (Exception e) {
            System.assert(e.getMessage().contains('cannot be deleted'));
            hadException = TRUE;
        }
        System.assert(hadException, 'Expected an exception');

        // Unlink BankData from Contract

        oContract.BankData__c = NULL;
        update oContract;

        oContract = (Contract)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract WHERE Id = :idContract');

        // Field values should match
        for (String sBankDataField : mapMappingBankDataContractFields.keySet()) {
            String sContractField = mapMappingBankDataContractFields.get(sBankDataField);
            System.assert(oContract.get(sContractField) == NULL, 'Contract field value for ' + sContractField + ' should be NULL');
        }

        Test.stopTest();
    }
}