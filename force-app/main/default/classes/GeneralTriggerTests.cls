@isTest
private class GeneralTriggerTests {

    private static final String DEBUG_HEADER = 'GeneralTriggerTests.';

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

    /**
     * Test OpportunityTriggerHandler::processVoucherCode()
     *
     * ! Deactivated with https://interaktiv.jira.com/browse/SOBCRM-1123
     * (MSB, 2017-12-15)
     *
     * Overview:
     * 1. Create a Bonus Campaign to which the Community Contract customers
     *    will be added later as Campaign Member
     * 2. Create Community Contracts (VoucherCode__c is an autonumber field!)
     * 3. Activate Contracts so that Bonus__c objects are generated by
     *    LumenazaContractTriggerHandler::saveVoucherCodeAsBonus()
     * 4. Create Opportunities with generated Voucher Codes of Contracts
     * 5. This should find the Bonus__c IDs for the Voucher Codes and add them
     *    to the Opportunities respectively
     * 6. Further the Status of the created CampaignMembers by saveVoucherCodeAsBonus()
     *    should be set to "Activated"
     *
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @see https://interaktiv.jira.com/browse/SOBCRM-546
     * @since 2016-10-17
     */
    /*
    @isTest static void testOpportunityProcessVoucherCode() {

        //----------------------------
        // Account + Contact
        //----------------------------
        Account oAccount = new Account(
                Name = 'ACME Corp.'
        );
        insert oAccount;

        List<Contact> listContacts = new List<Contact>();

        listContacts.add(new Contact(
                FirstName = 'Duffy',
                LastName = 'Duck',
                AccountId = oAccount.Id
        ));
        listContacts.add(new Contact(
                FirstName = 'Daisy',
                LastName = 'Duck',
                AccountId = oAccount.Id
        ));
        insert listContacts;

        //----------------------------
        // Campaign
        //----------------------------
        // Create a Campaign which represents the
        // Community Contract Campaign for Bonuses
        Id idRecordTypeBonusCampaign = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Campaign', 'Bonus');
        System.assert(idRecordTypeBonusCampaign != NULL, 'Could not RecordType for "Bonus" for object Campaign');

        Campaign oCampaign = new Campaign(
                Name = 'Bonus',
                IsActive = true,
                BonusType__c = 'oneshot',
                BonusAmount__c = 19.99,
                BonusUnit__c = 'Euro',
                RecordTypeId = idRecordTypeBonusCampaign
        );
        insert oCampaign;

        // Add CampaignMember statuses (this is not done in declarative way)
        List<CampaignMemberStatus> campaignMemberStatuses = new List<CampaignMemberStatus>();
        campaignMemberStatuses.add(new CampaignMemberStatus(
                CampaignId   = oCampaign.Id,
                HasResponded = FALSE,
                Label = 'Bonus created',
                SortOrder = 3
        ));
        campaignMemberStatuses.add(new CampaignMemberStatus(
                CampaignId   = oCampaign.Id,
                HasResponded = FALSE,
                Label = 'Bonus activated',
                SortOrder = 4
        ));
        insert campaignMemberStatuses;

        // Insert communityContractBonusCampaignId in GeneralSettings
        // (This is mandatory for ContractTrigger::saveVoucherCodeAsBonus()
        // to add a Campaign
        GeneralSettings__c settings = new GeneralSettings__c(
                Name = 'communityContractBonusCampaignId',
                Value__c = oCampaign.Id
        );
        insert settings;

        //----------------------------
        // Contract
        //----------------------------
        List<Contract> listContracts = new List<Contract>();

        // Voucher Code should automatically be generated by
        // ContractTrigger::saveVoucherCodeAsBonus()
        listContracts.add(new Contract(
                AccountId = oAccount.Id,
                Status = 'Draft',
                StartDate = System.today(),
                ContractingPartyEmail__c = 'duffy@duck.com',
                CustomerSignedId = listContacts.get(0).Id,
                Type__c = 'sonnenbatterieHome-DE',
                RecordTypeId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Contract', 'Community')
        ));
        listContracts.add(new Contract(
                AccountId = oAccount.Id,
                Status = 'Draft',
                StartDate = System.today(),
                ContractingPartyEmail__c = 'daisy@duck.com',
                CustomerSignedId = listContacts.get(1).Id,
                Type__c = 'sonnenbatterieHome-DE',
                RecordTypeId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Contract', 'Community')
        ));
        insert listContracts;

        for (Contract oContract : listContracts) {
            oContract.Status = 'Activated';
        }
        update listContracts; // this will created Bonus__c and CampaignMembers in LumenazaContractTriggerHandler::saveVoucherCodeAsBonus()

        Map<Id,Contract> mapContracts = new Map<Id,Contract>([SELECT Id, Status, VoucherCode__c FROM Contract WHERE Id IN :listContracts]);

        List<Bonus__c> listBonuses = [SELECT Id, Contract__c FROM Bonus__c];
        System.assertEquals(2, listBonuses.size(), 'Expected 2 Bonuses to be created');

        Test.startTest();

        //----------------------------
        // Opportunities
        //----------------------------
        List<Opportunity> listOpportunities = new List<Opportunity>();

        listOpportunities.add(new Opportunity(
                Name       = 'Opportunity 1',
                StageName  = 'Open',
                CloseDate  = Date.today(),
                VoucherCode__c = mapContracts.get(listContracts.get(0).Id).VoucherCode__c
        ));
        listOpportunities.add(new Opportunity(
                Name       = 'Opportunity 2',
                StageName  = 'Open',
                CloseDate  = Date.today(),
                VoucherCode__c = mapContracts.get(listContracts.get(1).Id).VoucherCode__c
        ));
        insert listOpportunities;

        Map<Id,Opportunity> mapOpportunitiesToCheck = new Map<Id,Opportunity>([SELECT Id, Bonus__c FROM Opportunity WHERE Id IN :listOpportunities]);

        System.assertNotEquals(NULL, mapOpportunitiesToCheck.get(listOpportunities.get(0).Id).Bonus__c);
        System.assertNotEquals(NULL, mapOpportunitiesToCheck.get(listOpportunities.get(1).Id).Bonus__c);

        // Check Status of CampaignMembers
        List<CampaignMember> listCreatedCampaignMembers = [SELECT Id, Status, ContactId FROM CampaignMember WHERE CampaignId = :oCampaign.Id AND ContactId IN :listContacts];

        System.assertEquals(listContracts.size(), listCreatedCampaignMembers.size(), 'Expected ' + listContracts.size() + ' CampaignMembers, each for one Contract');
        Integer activatedCampaignMembers = 0;

        System.debug('listCreatedCampaignMembers: '  + listCreatedCampaignMembers);

        for (CampaignMember oCampaignMember : listCreatedCampaignMembers) {
            if (oCampaignMember.Status == OpportunityTriggerHandler.CAMPAIGN_MEMBER_STATUS_ACTIVATED) {
                activatedCampaignMembers++;
            }
        }

        System.assertEquals(listCreatedCampaignMembers.size(), activatedCampaignMembers);

        Test.stopTest();
    }
    */

    /**
     * Test Save voucher Code as Bonus
     *
     * ! Deactivated with https://interaktiv.jira.com/browse/SOBCRM-1123
     * (MSB, 2017-12-15)
     */
    /*
    @isTest static void testContractTriggerSaveVoucherCodeAsBonus() {

		Account oAccount = new Account(
            Name = 'ACME Corp.'
        );
        insert oAccount;
        
        Contact oContact = new Contact(
            FirstName = 'Duffy',
            LastName = 'Duck',
            AccountId = oAccount.Id
        );
        insert oContact;
        
        Id idRecordTypeBonusCampaign = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Campaign', 'Bonus');
        System.assert(idRecordTypeBonusCampaign != NULL, 'Could not RecordType for "Bonus" for object Campaign');
        
        Campaign oCampaign = new Campaign(
            Name = 'Bonus',
            IsActive = true,
            BonusType__c = 'oneshot',
            BonusAmount__c = 19.99,
            BonusUnit__c = 'Euro',
            RecordTypeId = idRecordTypeBonusCampaign
        );
        insert oCampaign;

        // Add CampaignMember statuses (this is not done in declarative way)
        List<CampaignMemberStatus> campaignMemberStatuses = new List<CampaignMemberStatus>();
        campaignMemberStatuses.add(new CampaignMemberStatus(
                CampaignId   = oCampaign.Id,
                HasResponded = FALSE,
                Label = 'Bonus created',
                SortOrder = 3
        ));
        campaignMemberStatuses.add(new CampaignMemberStatus(
                CampaignId   = oCampaign.Id,
                HasResponded = FALSE,
                Label = 'Bonus activated',
                SortOrder = 4
        ));
        insert campaignMemberStatuses;

        List<Contract> lContracts = new List<Contract>();

        // Practically a user wouldn't have more than one community
        // Contract but you never know ...
        lContracts.add(new Contract(
            AccountId = oAccount.Id,
            Status = 'Draft',
            StartDate = System.today(),
            ContractingPartyEmail__c = 'daisy@duck.com',
            CustomerSignedId = oContact.Id,
            Type__c = 'sonnenbatterieHome-DE',
            RecordTypeId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Contract', 'Community')
        ));
        lContracts.add(new Contract(
            AccountId = oAccount.Id,
            Status = 'Draft',
            StartDate = System.today(),
            ContractingPartyEmail__c = 'daisy@duck.com',
            CustomerSignedId = oContact.Id,
            Type__c = 'sonnenbatterieHome-DE',
            TariffType__c = 'household',
            RecordTypeId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Contract', 'Energy')
        ));
        lContracts.add(new Contract(
            AccountId = oAccount.Id,
            Status = 'Draft',
            StartDate = System.today(),
            ContractingPartyEmail__c = 'daisy@duck.com',
            CustomerSignedId = oContact.Id,
            Type__c = 'sonnenbatterieHome-DE',
            RecordTypeId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Contract', 'Community')
        ));
        lContracts.add(new Contract(
            AccountId = oAccount.Id,
            Status = 'Draft',
            StartDate = System.today(),
            ContractingPartyEmail__c = 'daisy@duck.com',
            CustomerSignedId = oContact.Id,
            Type__c = 'sonnenbatterieHome-DE',
            RecordTypeId = SonnenbatterieConstants.getRecordTypeIdByObjectAndDeveloperName('Contract', 'Community')
        ));
        insert lContracts;
                
        Contract oContractToCheck;
        Map<Id,Contract> mContracts = new Map<Id,Contract>([SELECT Id, Status, VoucherCode__c FROM Contract WHERE Id IN :lContracts]);
        
        System.assert(mContracts.get(lContracts.get(0).Id).VoucherCode__c != NULL, 'Expect a VoucherCode due to RecordType "Community"');
        System.assert(mContracts.get(lContracts.get(1).Id).VoucherCode__c == NULL, 'Expect no VoucherCode due to RecordType "Energy"');
        System.assert(mContracts.get(lContracts.get(2).Id).VoucherCode__c != NULL, 'Expect a VoucherCode due to RecordType "Community"');
        System.assert(mContracts.get(lContracts.get(3).Id).VoucherCode__c != NULL, 'Expect a VoucherCode due to RecordType "Community"');
        
        Test.startTest();
        
        // Check Bonus creation on missing GeneralSetting for CampaignID
        oContractToCheck = mContracts.get(lContracts.get(0).Id);
       	oContractToCheck.Status = 'Activated';    
        update oContractToCheck;
        
        List<Bonus__c> lBonuses = [SELECT Id FROM Bonus__c];
        System.assert(lBonuses.isEmpty(), 'Expected no Bonuses to be created due to missing GeneralSetting for Campaign ID');
                        
        GeneralSettings__c settings = new GeneralSettings__c(
            Name = 'communityContractBonusCampaignId',
            Value__c = oCampaign.Id
        );
        insert settings;
        
        // Check Bonus creation on Energy Contract
        oContractToCheck = mContracts.get(lContracts.get(1).Id);
       	oContractToCheck.Status = 'Activated';    
        update oContractToCheck;
        
        lBonuses = [SELECT Id FROM Bonus__c];
        System.assert(lBonuses.isEmpty(), 'Expected no Bonuses to be created due to activation of an Energy Contract');
        
        // Check Bonus creation on two similar Contracts
        // This should create two Bonuses but only ONE CampaignMember
       	List<Contract> lContractsToUpdate = new List<Contract>();
        mContracts.get(lContracts.get(2).Id).Status = 'Activated';
        mContracts.get(lContracts.get(3).Id).Status = 'Activated';
        lContractsToUpdate.add(mContracts.get(lContracts.get(2).Id));
        lContractsToUpdate.add(mContracts.get(lContracts.get(3).Id));
        update lContractsToUpdate;
        
        lBonuses = [SELECT Id, Contract__c FROM Bonus__c];
        System.assertEquals(2, lBonuses.size(), 'Expected 2 Bonuses to be created');

		// Check on CampaignMember
		List<CampaignMember> lCampaignMember = [SELECT ContactId FROM CampaignMember WHERE ContactId = :oContact.ID AND CampaignId = :oCampaign.Id];
        System.assertEquals(1, lCampaignMember.size(), 'Expected 1 CampaignMember to be created');
        
        Test.stopTest();
    }
    */
}