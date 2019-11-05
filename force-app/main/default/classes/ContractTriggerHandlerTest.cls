/**
 * Test class for contract trigger handler to test the contract trigger itselfs and all methods in its handler
 *
 * Changelog
 * ---------
 *
 * v1.1.0   2017-06-13  Kevin Kolditz               First version
 * v2.0.0   2018-04-27  Marko Schmalenbach          Total revision (SOBCRM-1177)
 * v2.1.0   2018-07-12  Marko Schmalenbach          Added testing of creating/relating an activated Contract to a
 *                                                  Community Membership (SOBCRM-1232)
 * v2.1.1   2018-10-12  Marko Schmalenbach          Hotfix for generic SOQL on Campaign as the API version was to old to request fields
 *                                                  returned by DiaUtilities.returnAllFieldsAsString()
 *
 * @see ContractTriggerHandler.cls
 */
@isTest
public class ContractTriggerHandlerTest {

    public static final String TEST_CONTRACT_MAIL_WITH_BONUS_ERROR = 'contract@bonuserror.ohmy';

    private static final String BONUS_CODE1 = 'CMP-12345';
    private static final String DEBUG_HEADER = 'ContractTriggerHandlerTest.';


	@testSetup
    static void setup() {

        Map<String,Map<String,Id>> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Contract', 'Campaign'});

        // Create some campaigns
        Campaign oCampaign = new Campaign(
            Name                 = 'Energy Bonus',
            IsActive             = true,
            RecordTypeId         = mapRecordTypes.get('Campaign').get('Bonus'),
            Status               = 'In Progress',
            BonusAmount__c       = 180,
            BonusUnit__c         = 'kWh',
            BonusApplyTo__c      = 'consumption',
            BonusContractType__c = 'Energy',
            BonusType__c         = 'oneshot',
            StartDate            = Date.today(),
            EndDate              = Date.today().addDays(30),
            ExtId__c             = BONUS_CODE1
        );
        insert oCampaign;

        // Create contract and corresponding objects
		List<Account> listAccounts = new List<Account>{
            new Account(Name = 'ACME Inc.'),
            new Account(Name = 'Bonus Corp.'),
            new Account(Name = 'Bogus Company'),
            new Account(Name = 'Disney Org')
        };
		insert listAccounts ;


        List<Contact> listContacts = new List<Contact>{
            new Contact(
                FirstName = 'Voidberg',
                LastName = 'Bogusman',
                AccountId = listAccounts.get(0).Id
            ),
            new Contact(
                FirstName = 'Good Will',
                LastName = 'Hunting',
                AccountId = listAccounts.get(1).Id
            ),
            new Contact(
                FirstName = 'Donald',
                LastName = 'Duck',
                AccountId = listAccounts.get(2).Id
            ),
            new Contact(
                FirstName = 'Mickey',
                LastName = 'Mouse',
                AccountId = listAccounts.get(3).Id
            )
        };
        insert listContacts;

		List<Contract> listContracts = new List<Contract>{
            new Contract(
                RecordTypeId = mapRecordTypes.get('Contract').get('sonnenStrom'),
                AccountId = listAccounts.get(0).Id,
                Status = 'Draft',
                ContractingPartySalutation__c = 'Herr',
                ContractingPartnerFirstname__c = listContacts.get(0).FirstName,
                ContractingPartnerLastname__c = listContacts.get(0).LastName,
                ContractingPartyAcademicTitle__c = 'Dr.',
                ContractingPartyAccountName__c = '',
                ContractingPartyEmail__c = 'test@die-interaktiven.de',
                ContractingPartyPhone__c = '007-123456',
                AnnualConsumption__c = '5000',
                BankDataFirstname__c = 'Voidy',
                BankDataLastname__c = 'Bogusman',
                BankDataIBAN__c = ' de49 7332_0073 0022.6660 45$',
                DeliveryStart__c = System.today().addMonths(1),
                BillingStreet__c = 'Voidstreet',
                BillingStreetNumber__c = '4a',
                BillingPostalCode__c = '12345',
                BillingCity__c = 'Boguscity',
                MeterId__c = '7147192',
                PreviousProvider__c = '9904383000003',
                SEPADate__c = System.today(),
                ShippingStreet__c = 'Locusweg',
                ShippingStreetNumber__c = '28',
                ShippingPostalCode__c = '54321',
                ShippingCity__c = 'Shipcity',
                TariffType__c = 'sonnenStrom',
                Type__c = 'start',
                MandateReferenceNumber__c = '123456545687',
                SubscriptionReason__c = 'New Site (E02)',
                AmountOfFreeEnergy__c = 5000,
                AnnualConsumptionTotal__c = 10000,
                CustomerSignedId = listContacts.get(0).Id,
                LumenazaContractId__c = 'C123456',
                LumenazaCustomerId__c = 'DE123456',
                LumenazaSkipApiCall__c = true
            )
        };

        Integer iConractIndex = 1;

        Contract oContract = listContracts.get(0).clone();
        oContract.AccountId                      = listAccounts.get(iConractIndex).Id;
        oContract.CustomerSignedId               = listContacts.get(iConractIndex).Id;
        oContract.LumenazaContractId__c          = 'C987654321';
        oContract.LumenazaCustomerId__c          = 'DE987654321';
        oContract.ContractingPartnerFirstname__c = listContacts.get(iConractIndex).FirstName;
        oContract.ContractingPartnerLastname__c  = listContacts.get(iConractIndex).LastName;
        listContracts.add(oContract);

        iConractIndex++;
        oContract = listContracts.get(0).clone();
        oContract.AccountId                      = listAccounts.get(iConractIndex).Id;
        oContract.CustomerSignedId               = listContacts.get(iConractIndex).Id;
        oContract.LumenazaContractId__c          = 'C1010101010';
        oContract.LumenazaCustomerId__c          = 'DE101010101';
        oContract.ContractingPartnerFirstname__c = listContacts.get(iConractIndex).FirstName;
        oContract.ContractingPartnerLastname__c  = listContacts.get(iConractIndex).LastName;
        listContracts.add(oContract);

        iConractIndex++;
        oContract = listContracts.get(0).clone();
        oContract.AccountId                      = listAccounts.get(iConractIndex).Id;
        oContract.CustomerSignedId               = listContacts.get(iConractIndex).Id;
        oContract.LumenazaContractId__c          = 'C92347238498';
        oContract.LumenazaCustomerId__c          = 'DE2349809232';
        oContract.ContractingPartnerFirstname__c = listContacts.get(iConractIndex).FirstName;
        oContract.ContractingPartnerLastname__c  = listContacts.get(iConractIndex).LastName;
        listContracts.add(oContract);

		insert listContracts;

        // Lumenaza Settings
        LumenazaSettings__c settings = new LumenazaSettings__c(
            Name = LumenazaApi.settingsName,
            ApiDoSync__c = true,
            ApiUseTest__c = true,
            ApiTestUrl__c = 'http://bogus.whitehouse.org',
            ApiTestUsername__c = 'bogus',
            ApiTestPassword__c = 'bogus',
            ApiTestAuthClient__c = 'bogus',
            ApiTestAuthSecret__c = 'bogus',
            ApiLiveUrl__c = 'http://bogus.whitehouse.org',
            ApiLiveUsername__c = 'bogus',
            ApiLivePassword__c = 'bogus',
            ApiLiveAuthClient__c = 'bogus',
            ApiLiveAuthSecret__c = 'bogus'
        );
        insert settings;
	}

	/**
	 * Tests the Bonus__c creation
	 */
	@isTest
    static void testBonusCreationOnBonusCode() {

        String DEBUG_HERE = DEBUG_HEADER + 'testBonusCreationOnBonusCode() - ';
        System.debug(DEBUG_HERE + 'START');

        Campaign oCampaign = (Campaign)Database.query('SELECT Id FROM Campaign WHERE ExtId__c = :BONUS_CODE1');
        List<Contract> listContracts = (List<Contract>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract');
        System.assert(listContracts.size() >= 4, 'Expected at least 4 contracts');

        listContracts.get(2).ContractingPartyEmail__c = TEST_CONTRACT_MAIL_WITH_BONUS_ERROR;
        update listContracts.get(2);

        listContracts.get(0).BonusCode__c = 'NOT-EXISTING-1234'; // Should raise an error as there is no campaign with this bonus code
        listContracts.get(1).BonusCode__c = BONUS_CODE1;         // Should create a properly bonus
        listContracts.get(2).BonusCode__c = BONUS_CODE1;         // Should raise an error as TEST_CONTRACT_MAIL_WITH_BONUS_ERROR is used
        listContracts.get(3).BonusCode__c = BONUS_CODE1;         // Should create a properly bonus but fail to create a campaign member for testing purposes

        // Now insert a campaign member which should later
        // not be inserted as duplicate
        insert new CampaignMember(
            CampaignId  = oCampaign.Id,
            ContactId   = listContracts.get(3).CustomerSignedId,
            Status      = ContractTriggerHandler.BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS
        );

        // Run trigger
        Test.startTest();

        List<Bonus__c> listBonuses;

        //-------------------------------
        // Exception 1
        //-------------------------------
        // First exception for missing Amount__c on the bonus object
        // for the contract with ContractingPartyEmail__c = TEST_CONTRACT_MAIL_WITH_BONUS_ERROR
        Boolean bHasException = false;
        try {
            System.debug(DEBUG_HERE + 'Update contracts to trigger 1st exception');
            update listContracts;
        }
        catch (Exception e) {
            bHasException = true;
            System.debug(DEBUG_HERE + 'Exception: ' +  e.getMessage() + ' (' + e.getStackTraceString() + ')');
        }
        System.assert(bHasException);

        // Expect no Bonus__c to be created
        listBonuses = [SELECT Id FROM Bonus__c];
        System.assertEquals(0, listBonuses.size(), 'Expected 0 Bonus__c objects to be created');

        // Set ContractingPartyEmail__c to null to avoid an exception on Bonus__c.Amount__c
        listContracts.get(2).ContractingPartyEmail__c = null;

        //-------------------------------
        // Exception 2
        //-------------------------------
        // Second exception for the bonus code which couldn't be found
        bHasException = false;
        try {
            System.debug(DEBUG_HERE + 'Update contracts to trigger 2nd exception');
            update listContracts;
        }
        catch (Exception e) {
            bHasException = true;
            System.debug(DEBUG_HERE + 'Exception: ' +  e.getMessage() + ' (' + e.getStackTraceString() + ')');
        }

        System.assert(bHasException);
        bHasException = false;

        // Expect no Bonus__c to be created
        listBonuses = [SELECT Id FROM Bonus__c];
        System.assertEquals(0, listBonuses.size(), 'Expected 0 Bonus__c objects to be created');

        // Remove bogus bonus code so the contract won't be handled
        // for a bonus creation
        listContracts.get(0).BonusCode__c = '';

        System.debug(DEBUG_HERE + 'Update contracts without bogus bonus');
        update listContracts;

        Test.stopTest();

        // Assertions

        //-------------------------------
        // Bonus__c
        //-------------------------------
        Integer iExpectedBonuses = 0;
        Set<Id> lsetExpectedContractsWithBonus = new Set<Id>{listContracts.get(1).Id, listContracts.get(2).Id, listContracts.get(3).Id};

        listBonuses = (List<Bonus__c>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Bonus__c') + ' FROM Bonus__c');
        System.assertEquals(lsetExpectedContractsWithBonus.size(), listBonuses.size());

        for (Bonus__c oBonus : listBonuses) {
            if (lsetExpectedContractsWithBonus.contains(oBonus.Contract__c)) {
                iExpectedBonuses++;
            }
        }
        System.assertEquals(lsetExpectedContractsWithBonus.size(), iExpectedBonuses, 'Expected the Bonus__c objects for ' + lsetExpectedContractsWithBonus.size() + ' contracts');

        //-------------------------------
        // CampaignMember
        //-------------------------------
        // Should be 3 campaign members and no error should be thrown
        // due to a duplicate member which was created above
        Integer iExpectedCampaignMembers = 0;
        Set<Id> lsetExpectedContactsWithCampaignMembership = new Set<Id>{listContracts.get(1).CustomerSignedId, listContracts.get(2).CustomerSignedId, listContracts.get(3).CustomerSignedId};

        List<CampaignMember> listCampaignMembers = (List<CampaignMember>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('CampaignMember') + ' FROM CampaignMember');
        System.assertEquals(lsetExpectedContactsWithCampaignMembership.size(), listCampaignMembers.size());

        for (CampaignMember oCampaignMember : listCampaignMembers) {
            if (lsetExpectedContactsWithCampaignMembership.contains(oCampaignMember.ContactId)) {
                iExpectedCampaignMembers++;
            }
        }
        System.assertEquals(lsetExpectedContactsWithCampaignMembership.size(), iExpectedCampaignMembers, 'Expected the CampaignMember objects for ' + lsetExpectedContactsWithCampaignMembership.size() + ' contract contracts');

        System.debug(DEBUG_HERE + 'END');
	}

    /**
     *
     */
    @isTest
    static void testBonusRedemptionByConfirmedDeliveryStart() {

        String DEBUG_HERE = DEBUG_HEADER + 'testBonusRedemptionByConfirmedDeliveryStart() - ';
        System.debug(DEBUG_HERE + 'START');

        List<Contract> listContracts = (List<Contract>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Contract') + ' FROM Contract');
        System.assert(listContracts.size() >= 4, 'Expected at least 4 contracts');

        // Create campaign memberships
        Id idCampaign = [SELECT Id FROM Campaign LIMIT 1].Id;
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>();

        for (Integer i = 0; i<4; i++) {

            listContracts.get(i).Status = 'Activated';
            listContracts.get(i).BonusCode__c = BONUS_CODE1;

            listCampaignMembers.add(new CampaignMember(
                CampaignId  = idCampaign,
                ContactId   = listContracts.get(i).CustomerSignedId,
                Status      = ContractTriggerHandler.BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS
            ));
        }
        insert listCampaignMembers;
        System.debug(DEBUG_HERE + 'Inserted campaign memberships: ' + listCampaignMembers);

        List<CampaignMember> listCampaignMembersCheck = [SELECT Status FROM CampaignMember];
        System.assertEquals(listCampaignMembers.size(), listCampaignMembersCheck.size());
        Integer iCorrectStatus = 0;

        for (CampaignMember oCampaignMember : listCampaignMembersCheck) {
            if (oCampaignMember.Status == ContractTriggerHandler.BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS) {
                iCorrectStatus++;
            }
        }
        System.assertEquals(listCampaignMembersCheck.size(), iCorrectStatus, 'Expected status "' + ContractTriggerHandler.BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS + '" on campaign memberships: ' + listCampaignMembersCheck);

        System.debug(DEBUG_HERE + 'Activate contracts and set bonus codes');

        ContractTriggerHandler.bypassMethod('synchronizeToLumenaza');
        ContractTriggerHandler.bypassMethod('synchronizeToAwattar');
        ContractTriggerHandler.bypassMethod('initEmailToCustomerAtAwattar');

        // Because there are - at the end - 3 Bonuses to push to Lumenaza
        // which result in a System.AsyncException: Maximum stack depth has been reached
        // we bypass LumenazaBonusTriggerHandler here
        TriggerHandler.bypass('LumenazaBonusTriggerHandler');

        update listContracts;

        List<Bonus__c> listBonuses = (List<Bonus__c>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Bonus__c') + ' FROM Bonus__c');
        System.assertEquals(4, listBonuses.size());

        Test.startTest();

        System.debug(DEBUG_HERE + 'Set ConfirmedDeliveryStart__c and perform Database.update with allOrNone = false');

        for (Integer i = 0; i<4; i++) {
            if (i == 2) {
                // * Error here will only be visible as VF_PAGE_MESSAGE|Test error !
                // see Database.update() beneath
                listContracts.get(2).ContractingPartyEmail__c = TEST_CONTRACT_MAIL_WITH_BONUS_ERROR;
            }
            listContracts.get(i).ConfirmedDeliveryStart__c = System.today();
        }

        // * With this there will be no exceptions in the log!
        Database.update(listContracts, false); // allOrNone false for partial updates!

        // To understand this:
        // At Database operations with partial success option (allOrNone = false) the
        // trigger could be called for maximum 3 times.
        // The good thing about this is that if the corresponding trigger handler would
        // insert or update objects this will be done for real only in the last iteration.
        // See http://cropredysfdc.com/2015/04/26/245/ for further explanation!

        Test.stopTest();

        listBonuses = (List<Bonus__c>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Bonus__c') + ', Contract__r.CustomerSignedId FROM Bonus__c WHERE IsSyncableToLumenaza__c = true');

        System.assertEquals(3, listBonuses.size(), 'Expected 3 bonuses synchronizable to Lumenaza as one contract failed to save in the afterUpdate method activateBonuses()');

        // Check if campaign members have the correct status
        List<String> listCampaignContactQueryPairs = new List<String>();

        // Now set status of campaign members by
        // searching with ContactId - CampaignId__c pairs
        for (Bonus__c oBonus : listBonuses) {
            if (oBonus.Contract__r.CustomerSignedId != null && oBonus.CampaignId__c != null) {
                listCampaignContactQueryPairs.add(
                    '(ContactId=\'' + oBonus.Contract__r.CustomerSignedId + '\' AND CampaignId=\'' + oBonus.CampaignId__c + '\')'
                );
            }
        }

        listCampaignMembers = (List<CampaignMember>)Database.query(
            'SELECT Id, Status FROM CampaignMember WHERE ' + String.join(listCampaignContactQueryPairs, ' OR ')
        );
        System.assertEquals(listBonuses.size(), listCampaignMembers.size(), 'Expect count of campaign members to match the count of the created bonuses');

        Integer iRedeemedCount = 0;
        for (CampaignMember oCampaignMember : listCampaignMembers) {
            if (oCampaignMember.Status == ContractTriggerHandler.BONUS_CODE_CAMPAIGN_MEMBER_REDEEMED_STATUS) {
                iRedeemedCount++;
            }
        }
        System.assertEquals(listCampaignMembers.size(), iRedeemedCount, 'Expect all campaign members to have status "' + ContractTriggerHandler.BONUS_CODE_CAMPAIGN_MEMBER_REDEEMED_STATUS+ '"');

        System.debug(DEBUG_HERE + 'END');
    }

    /**
     * Tests creation/relation of Community Membership to an activated Contract
     *
     * @since 2018-07-12
     * @author Marko Schmalenbach
     * @see ContractTriggerHandler.createRelateToCommunityMembership()
     * @see https://interaktiv.jira.com/browse/SOBCRM-1232
     */
    @isTest
    static void testCreateRelateCommunityMembership() {

        final String DEBUG_HERE = DEBUG_HEADER + 'testCreateRelateCommunityMembership() - ';

        System.debug(DEBUG_HERE + 'START');

        ContractTriggerHandler.bypassMethod('synchronizeToLumenaza');
        ContractTriggerHandler.bypassMethod('activateBonuses');
        ContractTriggerHandler.bypassMethod('createBonusOnBonusCode');
        ContractTriggerHandler.bypassMethod('initEmailToCustomerAtAwattar');
        ContractTriggerHandler.bypassMethod('synchronizeToAwattar');

        Id idRecordTypeIdPersonAccount = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Private'].Id;

        // Check Contracts from setup first
        List<Contract> listContracts = [SELECT Id, CommunityMembership__c FROM Contract];

        System.assert(!listContracts.isEmpty());

        // Activate existing Contracts
        for (Contract oContract : listContracts) {
            oContract.Status = 'Activated';
            System.assert(oContract.CommunityMembership__c == null);
        }
        update listContracts;

        System.debug(DEBUG_HERE + 'Test existing Contracts START');
        listContracts = [
            SELECT
                AccountId, RecordTypeId, TariffType__c, Type__c, Status, CustomerSignedId,
                CommunityMembership__r.Contact__c, CommunityMembership__r.Account__c,
                CommunityMembership__c
            FROM Contract
        ];

        for (Contract oContract : listContracts) {

            System.assert(oContract.CommunityMembership__c != null, 'Expected no Community Membership on non activated Contract');

            System.assertEquals(
                oContract.CommunityMembership__r.Contact__c,
                oContract.CustomerSignedId,
                'Expect Contact\'s CommunityMembership__c Contact ID to equal the CustomerSignedId'
            );

            System.assertEquals(
                oContract.CommunityMembership__r.Account__c,
                oContract.AccountId,
                'Expect Contact\'s CommunityMembership__c Account ID to equal the AccountId'
            );
        }
        System.debug(DEBUG_HERE + 'Test existing Contracts END');

        Test.startTest();

        // Add a second Community Membership to an existing Account
        // which normally shouldn't be the case
        // Another Contract for this Account is expected to be related
        // to the first Community Membership created
        Contract oContract = listContracts.get(0);

        CommunityMembership__c oCommunityMembership = new CommunityMembership__c(
            Account__c = oContract.CommunityMembership__r.Account__c,
            Contact__c = oContract.CommunityMembership__r.Contact__c
        );
        insert oCommunityMembership;

        // Create another Account which will get 2 Contracts at the same trigger transaction
        Account oNewAccount = new Account(
            FirstName = 'Walter',
            LastName = 'Wurstsalat',
            RecordTypeId = idRecordTypeIdPersonAccount
        );
        insert oNewAccount;

        oNewAccount = [SELECT PersonContactId FROM Account WHERE Id = :oNewAccount.Id];

        // Clear list
        listContracts = new List<Contract>();

        Contract oContractTemplate = new Contract(
            RecordTypeId     = oContract.RecordTypeId,
            TariffType__c    = oContract.TariffType__c,
            Type__c          = oContract.Type__c,
            Status           = 'Draft'
        );

        // 1. Add another Contract for an existing Account to check
        // - if it is related to the existing 1st Community Membership created
        // - and not to the second which shouldn't be there anyway
        Contract oSecondContractForExistingAccount = oContractTemplate.clone();
        oSecondContractForExistingAccount.AccountId        = oContract.AccountId;
        oSecondContractForExistingAccount.CustomerSignedId = oContract.CustomerSignedId;
        listContracts.add(oSecondContractForExistingAccount);

        // 2. Add two new Contracts for the new Account
        // There should be only one created Community Membership as the first created in the
        // transaction should be reused. This is a very rare event but it could occur.
        Contract oContract1ForNewAccount = oContractTemplate.clone();
        oContract1ForNewAccount.AccountId        = oNewAccount.Id;
        oContract1ForNewAccount.CustomerSignedId = oNewAccount.PersonContactId;
        listContracts.add(oContract1ForNewAccount);
        Contract oContract2ForNewAccount = oContractTemplate.clone();
        oContract2ForNewAccount.AccountId        = oNewAccount.Id;
        oContract2ForNewAccount.CustomerSignedId = oNewAccount.PersonContactId;
        listContracts.add(oContract2ForNewAccount);

        System.debug(DEBUG_HERE + 'Inserting 3 new Contracts');
        insert listContracts;

        for (Contract oContractToActivate : listContracts) {
            oContractToActivate.Status = 'Activated';
        }

        update listContracts;

        Map<Id, Contract> mapContracts = new Map<Id, Contract>([
            SELECT Id, CommunityMembership__c, CommunityMembership__r.Account__c, CommunityMembership__r.Contact__c
            FROM Contract
            WHERE Id IN :listContracts
        ]);

        // Case 1.
        oSecondContractForExistingAccount = mapContracts.get(oSecondContractForExistingAccount.Id);
        System.assertEquals(
            oSecondContractForExistingAccount.CommunityMembership__c,
            oContract.CommunityMembership__c,
            'Expect the second Contract of an existing Account to be related to the same first created Community Membership as the first Contract'
        );

        System.assert(
            ![
                SELECT Id
                FROM Case
                WHERE AccountId = :oContract.AccountId AND Subject = :ContractTriggerHandler.ACCOUNT_WITH_MULTIPLE_COMMUNITY_MEMBERSHIPS_CASE_SUBJECT
            ].isEmpty(),
            'Expected an error case created due to multiple Community Memberships related to the same Account'
        );

        // Case 2.
        oContract1ForNewAccount = mapContracts.get(oContract1ForNewAccount.Id);
        oContract2ForNewAccount = mapContracts.get(oContract2ForNewAccount.Id);
        System.assert(
            oContract1ForNewAccount.CommunityMembership__c == oContract2ForNewAccount.CommunityMembership__c,
            'Expect the same Community Membership for both new Contracts as they are handled in the same trigger transaction'
        );

        List<CommunityMembership__c> listCommunityMemberships = [
            SELECT Id
            FROM CommunityMembership__c
            WHERE Account__c = :oNewAccount.Id AND Contact__c = :oNewAccount.PersonContactId
        ];
        System.assert(
            listCommunityMemberships.size() == 1,
            'Expect only ONE created Community Membership for two new Contracts handled in the same trigger transaction'
        );

        Test.stopTest();

        System.debug(DEBUG_HERE + 'END');
    }
}