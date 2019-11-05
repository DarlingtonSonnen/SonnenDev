/**
 * Trigger for Contract Standard object
 *
 * Changelog
 * ---------
 *
 * v1.1.0   2017-06-19  Kevin Kolditz               - Initial version
 *                                                  - SOBCRM-983 community bonus
 * v1.2.0   2017-06-19  Kevin Kolditz               Added exception handling
 * v1.3.0   2017-10-09  Marko Schmalenbach          - Added bypassing on method basis
 *                                                  - Added initEmailToCustomerAtAwattar() (SOBCRM-1034)
 * v1.4.0   2018-04-27  Marko Schmalenbach          - Moved everything from LumenazaContractTriggerHandler here
 *                                                  - Added createBonusOnBonusCode() and activateBonuses() (SOBCRM-1177)
 * v1.4.1   2018-05-09  Marko Schmalenbach          Fix in createBonusOnBonusCode(): Debug message onInsert raised NullPointerException
 * v1.4.2   2018-06-14  Marko Schmalenbach          Fix: Removed a left test snippet which raised a "Non-selective query against large object type" (SOBCRM-1220)
 * v1.4.3   2018-07-05  Marko Schmalenbach          Fix: Prevent empty SOQL in activateBonuses() when updating CampaignMember statuses (SOBCRM-1231)
 * v1.5.0   2018-07-12  Marko Schmalenbach          Create/relate an activated Contract to a Community Membership (SOBCRM-1232)
 * v1.5.1   2018-10-12  Marko Schmalenbach          Hotfix for generic SOQL on Campaign as the API version was to old to request fields
 *                                                  returned by DiaUtilities.returnAllFieldsAsString()
 * v1.6.0   2018-11-13  Marko Schmalenbach          Implemented Custom Setting "GeneralSettings__c" communityMembershipDebug for being able to debug and force the
 *                                                  creation of a missing Community Membership (not UnitTest covered currently)
 * @see     ContractTriggerHandlerTest
 */
public class ContractTriggerHandler extends TriggerHandler {

    private static Set<String> bypassedMethods = new Set<String>();

	private static final String DEBUG_HEADER = 'ContractTriggerHandler.';

    public static final String BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS = 'Sent';
    public static final String BONUS_CODE_CAMPAIGN_MEMBER_REDEEMED_STATUS = 'Responded';

    public static final String ACCOUNT_WITH_MULTIPLE_COMMUNITY_MEMBERSHIPS_CASE_SUBJECT = 'Account with multiple Community Memberships';

    private Map<Id, Contract> mapNewContracts;
    private Map<Id, Contract> mapOldContracts;
    private List<Contract> listNewContracts;
    private List<Contract> listOldContracts;

    private static Integer beforeUpdateIteration = 0;
    private static Integer beforeInsertIteration = 0;
    private static Integer afterUpdateIteration = 0;
    private static Integer afterInsertIteration = 0;

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
     * Constructor sets trigger values to make them accessible for other methods
     */
    public ContractTriggerHandler() {
        this.mapNewContracts = (Map<Id, Contract>) Trigger.newMap;
        this.mapOldContracts = (Map<Id, Contract>) Trigger.oldMap;
        this.listOldContracts = (List<Contract>) Trigger.old;
        this.listNewContracts = (List<Contract>) Trigger.new;
    }

    public override void beforeUpdate() {

        String DEBUG_HERE = DEBUG_HEADER + 'beforeUpdate() - ';
        System.debug(DEBUG_HERE + 'START (iteration ' + (++beforeUpdateIteration) + ')');

        this.sanitizeIbanNumber();
        this.setCustomerNumber();
        this.setBankDataFromRelatedBankData();

        System.debug(DEBUG_HERE + 'END (iteration ' + beforeUpdateIteration + ')');
    }

    public override void beforeInsert() {

        String DEBUG_HERE = DEBUG_HEADER + 'beforeInsert() - ';
        System.debug(DEBUG_HERE + 'START (iteration ' + (++beforeInsertIteration) + ')');

        this.sanitizeIbanNumber();
        this.setBankDataFromRelatedBankData();

        System.debug(DEBUG_HERE + 'END (iteration ' + beforeInsertIteration + ')');
    }

    public override void afterUpdate() {

        String DEBUG_HERE = DEBUG_HEADER + 'afterUpdate() - ';
        System.debug(DEBUG_HERE + 'START (iteration ' + (++afterUpdateIteration) + ')');

        // Create/relate Community Membership
        this.createRelateToCommunityMembership();

        // Activate bonuses which contract's delivery start date is confirmed
        this.activateBonuses();

   		// Create Bonus__c if BonusCode is found
    	this.createBonusOnBonusCode();

		// Sync to aWATTar (AT)
		this.synchronizeToAwattar();

        // Init email to customer
        this.initEmailToCustomerAtAwattar();

        // Sync to Lumenaza
        this.synchronizeToLumenaza();

        System.debug(DEBUG_HERE + 'END (iteration ' + afterUpdateIteration + ')');
    }

    public override void afterInsert() {

        String DEBUG_HERE = DEBUG_HEADER + 'afterInsert() - ';
        System.debug(DEBUG_HERE + 'START (iteration ' + (++afterInsertIteration) + ')');

        // Create Bonus__c if BonusCode is found
        this.createBonusOnBonusCode();

		// Snyc to aWATTar (AT)
		this.synchronizeToAwattar();

        // Sync to Lumenaza
        this.synchronizeToLumenaza();

        System.debug(DEBUG_HERE + 'END (iteration ' + afterInsertIteration + ')');
    }

    /**
     * Create/relate an activated Contract to a Community Membership
     *
     * - Create a new Community Membership if the related Account has none so far
     * - Relate the Contract to an existing Community Membership of the related Account. If an Account has
     *   more than one Membership an error case will be created with subject of constant
     *   ACCOUNT_WITH_MULTIPLE_COMMUNITY_MEMBERSHIPS_CASE_SUBJECT
     *
     * If there is more than one Contract created for an Account the first created Community Membership will
     * be reused and related to further Contracts in the same trigger context! (Though this will be a rare event 😉)
     *
     * @since 2018-07-12
     * @author Marko Schmalenbach
     * @see ContractTriggerHandlerTest.testCreateRelateCommunityMembership()
     * @see https://interaktiv.jira.com/browse/SOBCRM-1232
     */
    private void createRelateToCommunityMembership() {

        final String DEBUG_HERE = DEBUG_HEADER + 'createRelateToCommunityMembership() - ';

        System.debug(DEBUG_HERE + 'START');

        Savepoint eineSchritteSuruck = Database.setSavepoint();

        Boolean bForceCommunityMembershipCreationDespiteOfStatusChange = false;
        Boolean bForceRollback = false;

        GeneralSettings__c oSetting = GeneralSettings__c.getInstance('communityMembershipDebug');

        if (oSetting != null && oSetting.ValueBoolean__c && UserInfo.getUserEmail() == oSetting.Value__c) {

            System.debug(DEBUG_HERE +'Force creation of Community Membership despite of status change according to Custom Setting "GeneralSettings__c" with ID "communityMembershipDebug"');

            bForceCommunityMembershipCreationDespiteOfStatusChange = true;

            if (oSetting.Value2__c != 'forceCreate') {
                System.debug(DEBUG_HERE + 'Changes will be reverted afterwards (no "forceCreate" in Value2__c)');
                bForceRollback = true;
            }
        }

        Set<Id> lsetAccountIds = new Set<Id>();
        List<Contract> listContractsWithoutMembership = new List<Contract>();

        for (Contract oContract : (List<Contract>) Trigger.new) {

            Contract oOldContract = this.mapOldContracts.get(oContract.Id);

            // On Contract activation
            if (oContract.Status == 'Activated'
                && (oOldContract.Status != oContract.Status || bForceCommunityMembershipCreationDespiteOfStatusChange)
                && oContract.CommunityMembership__c == null
                && oContract.AccountId != null) {

                lsetAccountIds.add(oContract.AccountId);
                listContractsWithoutMembership.add(oContract);
                System.debug(DEBUG_HERE + 'Contract ' + oContract.ContractNumber + ' has no related Community Membership yet');
            }
        }

        // Get existing Memberships for current Contracts' Accounts
        Map<Id, Account> mapAccountToCommunityMemberships = new Map<Id, Account>([
            SELECT
                Id,
                Name,
                (SELECT Id, Account__c, Contact__c FROM Community_Memberships__r ORDER BY CreatedDate ASC)
            FROM Account
            WHERE Id IN :lsetAccountIds
        ]);

        Map<Id, CommunityMembership__c> mapContractIdToNewCommunityMembership = new Map<Id, CommunityMembership__c>();
        Map<Id, CommunityMembership__c> mapContractIdToCurrentlyCreatedCommunityMembership = new Map<Id, CommunityMembership__c>();
        Map<Id, CommunityMembership__c> mapAccountIdToNewCommunityMembership = new Map<Id, CommunityMembership__c>();
        Map<Id, Contract> mapContractsToUpdate = new Map<Id, Contract>();

        List<Case> listErrorCases = new List<Case>();

        for (Contract oContract : listContractsWithoutMembership) {

            System.debug(DEBUG_HERE + '------------------ NEXT CONTRACT ----------------------------');

            Account oAccount = mapAccountToCommunityMemberships.get(oContract.AccountId);

            // If Account of Contract could not be found ... explode💥
            if (oAccount == null) {
                System.debug(DEBUG_HERE + 'Account for Contract ' + oContract.Name + ' could not be found 😱 - skipping Contract');
                continue;
            }

            System.debug(DEBUG_HERE + 'Contract\'s Account "' + oAccount.Name + '": ' + JSON.serializePretty(oAccount));

            CommunityMembership__c oCommunityMembership;

            // Account has at least one existing Community Membership
            if (!oAccount.Community_Memberships__r.isEmpty()) {

                System.debug(DEBUG_HERE + 'Account ' + oAccount.Name + ' has at least one existing Community Membership');

                if (oAccount.Community_Memberships__r.size() > 1) {

                    System.debug(DEBUG_HERE + 'Account "' + oAccount.Name + '" has more than one Community Membership (' + oAccount.Community_Memberships__r.size() + ') which should NOT be the case (first one created will be related to Contract) - creating error Case');

                    listErrorCases.add(new Case(
                        Priority    = 'Low',
                        Type        = 'Problem',
                        AccountId   = oAccount.Id,
                        Subject     = ACCOUNT_WITH_MULTIPLE_COMMUNITY_MEMBERSHIPS_CASE_SUBJECT,
                        Description = 'Account "' + oAccount.Name + '" has ' + oAccount.Community_Memberships__r.size() + ' Community Memberships'
                    ));
                }

                // We take the first Community Membership created here
                oCommunityMembership = oAccount.Community_Memberships__r.get(0);

                // Relate Contract to existing Community Membership
                // (Notice that the oContract of the for loop is read-only
                // in an after trigger!)
                mapContractsToUpdate.put(oContract.Id, new Contract(
                    Id = oContract.Id,
                    CommunityMembership__c = oCommunityMembership.Id
                ));
            }
            // This one is only accessed if there are multiple Contracts for the same
            // Account handle in the same trigger transaction!
            else if (mapAccountIdToNewCommunityMembership.containsKey(oAccount.Id)) {

                mapContractIdToCurrentlyCreatedCommunityMembership.put(
                    oContract.Id,
                    mapAccountIdToNewCommunityMembership.get(oAccount.Id)
                );
            }
            // Create a new Community Membership and relate Contract to it
            else {

                Id idContact = oContract.CustomerSignedId;
                System.debug(DEBUG_HERE + 'Account has no Community Membership so far');

                if (idContact == null) {
                    oContract.CustomerSignedId.addError('Missing CustomerSignedId to create a Community Membership');
                    continue;
                }

                oCommunityMembership = new CommunityMembership__c(
                    Account__c = oAccount.Id,
                    Contact__c = idContact
                );

                System.debug(DEBUG_HERE + 'Added new Community Membership for insert: ' + JSON.serializePretty(oCommunityMembership.getPopulatedFieldsAsMap()));

                mapContractIdToNewCommunityMembership.put(oContract.Id, oCommunityMembership);

                // This one is only accessed if there are multiple Contracts for the same
                // Account handle in the same trigger transaction!
                mapAccountIdToNewCommunityMembership.put(oAccount.Id, oCommunityMembership);
            }
        } // end for (Contract oContract : listContractsWithoutMembership)

        // Insert new Community Memberships
        if (!mapContractIdToNewCommunityMembership.isEmpty()) {

            insert mapContractIdToNewCommunityMembership.values();

            for (Id idContract : mapContractIdToNewCommunityMembership.keySet()) {

                CommunityMembership__c oCommunityMembershipCreated = mapContractIdToNewCommunityMembership.get(idContract);

                // Relate Contract with created Community Membership
                mapContractsToUpdate.put(idContract, new Contract(
                    Id = idContract,
                    CommunityMembership__c = oCommunityMembershipCreated.Id
                ));
            }
        }

        // Contracts which must be related to Community Memberships which were just
        // created here. This would be the case if there are more than one Contract
        // inserted which belong to the same Account!
        if (!mapContractIdToCurrentlyCreatedCommunityMembership.isEmpty()) {

            System.debug(DEBUG_HERE + 'There are ' + mapContractIdToCurrentlyCreatedCommunityMembership.size() + ' Community ' +
                'Memberships created in this context which can also be related to other Contracts with the same Account');

            for (Id idContract : mapContractIdToCurrentlyCreatedCommunityMembership.keySet()) {

                CommunityMembership__c oCommunityMembership = mapContractIdToCurrentlyCreatedCommunityMembership.get(idContract);

                System.debug(DEBUG_HERE + 'Also relate Community Membership ' + oCommunityMembership.Id + ' to Contract ' + idContract);

                mapContractsToUpdate.put(idContract, new Contract(
                    Id = idContract,
                    CommunityMembership__c = oCommunityMembership.Id
                ));
            }
        }

        if (!mapContractsToUpdate.isEmpty()) {
            System.debug(DEBUG_HERE + 'Updating Contracts with Community Membership IDs: ' + JSON.serializePretty(mapContractsToUpdate.values()));
            update mapContractsToUpdate.values();
        }

        if (!listErrorCases.isEmpty()) {
            System.debug(DEBUG_HERE + 'Creating error case(s): ' + listErrorCases);
            insert listErrorCases;
        }

        if (bForceRollback) {
            System.debug(DEBUG_HERE + 'FORCE ROLLBACK!');
            Database.rollback(eineSchritteSuruck);
        }

        System.debug(DEBUG_HERE + 'END');
    }

	/**
	 * Initialize email to customer delivery at aWATTar
	 */
	private void initEmailToCustomerAtAwattar() {

		String DEBUG_HERE = DEBUG_HEADER + 'initEmailToCustomerAtAwattar() - ';

        if (isBypassedMethod('initEmailToCustomerAtAwattar')) {
            System.debug(DEBUG_HERE + 'is bypassed!');
            return;
        }

		System.debug(DEBUG_HERE + 'START');

        Set<AwattarObject> lsetAwattarObjectsForEmailDelivery = new Set<AwattarObject>();

        // Get contracts before
        Map<Id,Contract> mapContractsBefore = (Map<Id,Contract>) Trigger.oldMap;

		for (Contract oContract : (List<Contract>) Trigger.new) {

			// This can be evaluated because it's an after trigger event!
			if (!oContract.AwattarApiCustomerEmailReady__c) {
				System.debug(DEBUG_HERE + 'AwattarApiCustomerEmailReady__c is NOT TRUE - skipping');
				continue;
			}

            // Instantiate an AwattarContract by a Contract
            AwattarContract oAwattarContract = new AwattarContract(oContract);

            // Set old Contract on update
            if (Trigger.isUpdate) {
                Contract oContractBefore = mapContractsBefore.get(oContract.id);
                oAwattarContract.setContractBefore(oContractBefore);
            }

            // Instantiate an AwattarContract
            lsetAwattarObjectsForEmailDelivery.add(oAwattarContract);
		}

        if (!lsetAwattarObjectsForEmailDelivery.isEmpty()) {
            System.debug(DEBUG_HERE + 'initializing eamil to customer with ' + lsetAwattarObjectsForEmailDelivery.size() + ' contracts');
            AwattarApi.initObjectAction(lsetAwattarObjectsForEmailDelivery, AwattarContract.ACTION_EMAIL_TO_CUSTOMER);
        }

		System.debug(DEBUG_HERE + 'END');
	}

	/**
	 * Synchronize Contract to aWATTar
	 */
	private void synchronizeToAwattar() {

        String DEBUG_HERE = DEBUG_HEADER + 'synchronizeToAwattar() - ';

        if (isBypassedMethod('synchronizeToAwattar')) {
            System.debug(DEBUG_HERE + 'is bypassed!');
            return;
        }

		System.debug(DEBUG_HERE + 'START');

		Set<AwattarObject> lsetAwattarObjectsToUpsert = new Set<AwattarObject>();
		Map<String,Id> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Contract'}).get('Contract');

		// Get contracts before
		Map<Id,Contract> mapContractsBefore = (Map<Id,Contract>) Trigger.oldMap;

		for (Contract oContractAfter : (List<Contract>) Trigger.new) {

			// This can be evaluated because it's an after trigger event!
			if (!oContractAfter.IsValidForAwattarSync__c) {
				System.debug(DEBUG_HERE + 'IsValidForAwattarSync__c is NOT TRUE - skipping');
				continue;
			}

			// Instantiate an AwattarContract by a Contract
			AwattarContract oAwattarContract = new AwattarContract(oContractAfter);

			// Set old Contract on update
			if (Trigger.isUpdate) {
				Contract oContractBefore = mapContractsBefore.get(oContractAfter.id);
				oAwattarContract.setContractBefore(oContractBefore);
			}
			// Add AwattarContract to upsert list
			lsetAwattarObjectsToUpsert.add(oAwattarContract);
		}

		// If any AwattarContract validates to false everything is rolled
		// back otherwise Contracts will be upserted if API Sync is active
		if (!lsetAwattarObjectsToUpsert.isEmpty()) {

			// Try to init the Contract upsert and if any validation fails stop
			// the sync process by raising an validation error
			if (AwattarApi.initObjectAction(lsetAwattarObjectsToUpsert, AwattarObject.ACTION_UPSERT) == FALSE) {

				for (AwattarObject oAwattarObject : lsetAwattarObjectsToUpsert) {

					AwattarContract oAwattarContract = (AwattarContract)oAwattarObject;

					if (oAwattarContract.hasError() == true) {
						oAwattarContract.getContract().addError(oAwattarContract.getError());
					}
				}
			}
		}
		System.debug(DEBUG_HERE + 'END');
	}

    /**
     * Create Bonus__c if Bonus Code is found
     *
     * If a Bonus Code is found in certain fields which matches to
     * an existing ExtId of a Campaign then a Bonus__c will be created
     * and related to the Contract and the Campaign
     *
     * @see ContractTriggerHandlerTest
     * @see https://interaktiv.jira.com/browse/SOBCRM-1177
     */
    private void createBonusOnBonusCode() {

        String DEBUG_HERE = DEBUG_HEADER + 'createBonusOnBonusCode() - ';

		if (isBypassedMethod('createBonusOnBonusCode')) {
            System.debug(DEBUG_HERE + 'is bypassed');
			return;
		}

        Map<String,Schema.SObjectField> mapSchemaFieldsContract  = Schema.SObjectType.Contract.fields.getMap();

        Map<String,List<Contract>> mapBonusCodesToContracts = new Map<String,List<Contract>>();

        for (Contract oContractNew : this.listNewContracts) {

            Contract oContractOld = this.mapOldContracts != null ? this.mapOldContracts.get(oContractNew.Id) : null;

            // Iterate generically over each BonusCode field on the contract
            for (Schema.SObjectField oSchemaField : mapSchemaFieldsContract.values()) {

                if (Pattern.matches('BonusCode[0-9]*__c', String.valueOf(oSchemaField))) {

                    String sBonusFieldName = String.valueOf(oSchemaField);
                    String sBonusCode = (String)oContractNew.get(sBonusFieldName);

                    System.debug(DEBUG_HERE + 'Check bonus field "' + sBonusFieldName + '" (value "' + oContractNew.get(sBonusFieldName) + '") on changes');

                    // If insert or update and bonus field was filled
                    if (sBonusCode != null && (Trigger.isInsert || (Trigger.isUpdate && oContractOld.get(sBonusFieldName) == null))) {

                        if (Trigger.isInsert) {
                            System.debug(DEBUG_HERE + 'Bonus code field "' + sBonusFieldName + '": "' + sBonusCode + '"');
                        }
                        else {
                            System.debug(DEBUG_HERE + 'Bonus code field "' + sBonusFieldName + '" has changed from "' + oContractOld.get(sBonusFieldName) + '" to "' + sBonusCode + '"');
                        }

                        // Remember bonus code for contract
                        if (!mapBonusCodesToContracts.containsKey(sBonusCode)) {
                            mapBonusCodesToContracts.put(sBonusCode, new List<Contract>());
                        }
                        mapBonusCodesToContracts.get(sBonusCode).add(oContractNew);
                    }
                }
            }
        }

        // Get campaigns for found bonus codes in Campaign.ExtId__c
        if (!mapBonusCodesToContracts.isEmpty()) {

            System.debug(DEBUG_HERE + 'Found bonus codes: ' + mapBonusCodesToContracts.keySet());

            Set<String> lsetBonusCodes = mapBonusCodesToContracts.keySet().clone();
            List<Bonus__c> listBonusesToInsert = new List<Bonus__c>();
            List<CampaignMember> listCampaignMembersToInsert = new List<CampaignMember>();

            List<Campaign> listCampaigns = [
                SELECT
                    Id, BonusUnit__c, BonusApplyTo__c, BonusType__c, BonusNoOfMonths__c, BonusAmount__c, ExtId__c
                FROM Campaign
                WHERE RecordType.DeveloperName = 'Bonus' AND IsActive = true AND ExtId__c IN :lsetBonusCodes
            ];

            for (Campaign oCampaign : listCampaigns) {

                String sBonusCode = oCampaign.ExtId__c;

                lsetBonusCodes.remove(sBonusCode);

                System.debug(DEBUG_HERE + 'mapBonusCodesToContracts: ' + mapBonusCodesToContracts);
                // Get contracts to insert bonuses for
                List<Contract> listContractsForBonusCode = mapBonusCodesToContracts.get(sBonusCode);

                System.debug(DEBUG_HERE + 'Contracts for bonus code "' + sBonusCode + '": ' + listContractsForBonusCode);

                // Create bonus
                Bonus__c oBonusTemplate = new Bonus__c(
                    CampaignId__c = oCampaign.Id,
                    Unit__c       = oCampaign.BonusUnit__c,
                    ApplyTo__c    = oCampaign.BonusApplyTo__c,
                    RecordTypeId  = Helper_RecordTypeInfo.rtInfo('Bonus__c', 'Energy'),
                    BonusType__c  = oCampaign.BonusType__c,
                    NoOfMonths__c = oCampaign.BonusNoOfMonths__c,
                    Amount__c     = oCampaign.BonusAmount__c,
                    BonusCode__c  = oCampaign.ExtId__c
                );

                // Each contract gets the new bonus
                // ATTENTION: CURRENTLY A CONTRACT CAN HAVE THE SAME BONUS MULTIPLE TIMES!
                // This would be the case if the a bonus code was removed from the contract
                // and readded afterwards.
                for (Contract oContract : listContractsForBonusCode) {

                    // Add contract Id
                    Bonus__c oBonus = oBonusTemplate.clone();
                    oBonus.Contract__c = oContract.Id;

                    // Force an error on a bonus for a contract in the unit test
                    // to simulate any error on insertion
                    if (Test.isRunningTest() && oContract.ContractingPartyEmail__c == ContractTriggerHandlerTest.TEST_CONTRACT_MAIL_WITH_BONUS_ERROR) {
                        oBonus.Amount__c = null;
                    }

                    listBonusesToInsert.add(oBonus);
                }
            }

            // Handle campaigns not found by bonus code
            if (!lsetBonusCodes.isEmpty()) {

                for (String sBonusCodeLeft : lsetBonusCodes) {

                    List<Contract> listContractsForBonusCodeLeft = mapBonusCodesToContracts.get(sBonusCodeLeft);

                    for (Contract oContractLeft : listContractsForBonusCodeLeft) {
                        String sError = 'Campaign for bonus code "' + sBonusCodeLeft + '" could not be found by ExtId or it isn\'t active!';
                        System.debug(DEBUG_HERE + 'Error on Bonus__c.BonusCode__: ' + sError);
                        oContractLeft.BonusCode__c.addError('Campaign for bonus code "' + sBonusCodeLeft + '" could not be found by ExtId or it isn\'t active!');
                    }
                }
            }

            // Create bonuses
            if (!listBonusesToInsert.isEmpty()) {

                System.debug(DEBUG_HERE + 'Insert ' + listBonusesToInsert.size() + ' Bonus__c object(s) with bypassing possible ContractTriggerHandler call');
                TriggerHandler.bypass('ContractTriggerHandler', 'listBonusesToInsert');
                try {
                    insert listBonusesToInsert;
                }
                catch (Exception e) {
                    TriggerHandler.clearBypass('ContractTriggerHandler', 'listBonusesToInsert');
                    throw new ContractTriggerHandlerException(e);
                }
                TriggerHandler.clearBypass('ContractTriggerHandler', 'listBonusesToInsert');

                for (Bonus__c oBonusInserted : listBonusesToInsert) {

                    // Add a campaign membership for the contract signer
                    listCampaignMembersToInsert.add(new CampaignMember(
                        CampaignId  = oBonusInserted.CampaignId__c,
                        ContactId   = mapNewContracts.get(oBonusInserted.Contract__c).CustomerSignedId,
                        Status      = BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS
                    ));
                }
            }

            // Create campaign members
            // Some might fail if membership was already created before
            if (!listCampaignMembersToInsert.isEmpty()) {
                System.debug(DEBUG_HERE + 'Insert ' + listCampaignMembersToInsert.size() + ' campaign member(s) without respecting duplicates');
                Database.insert(listCampaignMembersToInsert, false); // Screw errors here :)
            }
        }

        System.debug(DEBUG_HERE + 'END');
	}

    /**
     * Activate bonuses which contract's delivery start date is confirmed
     *
     * @see LumenazaBonus
     * @see https://interaktiv.jira.com/browse/SOBCRM-1177
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @since 2018-04-26
     */
    private void activateBonuses() {

        if (!Trigger.isUpdate) {
            return;
        }

        String DEBUG_HERE = DEBUG_HEADER + 'activateBonuses() - ';

        if (isBypassedMethod('activateBonuses')) {
            System.debug(DEBUG_HERE + 'is bypassed');
            return;
        }

        Map<Id,Contract> mapContractsWithDeliveryStartChange = new Map<Id,Contract>();

        System.debug(DEBUG_HERE + 'START');

        System.debug(DEBUG_HERE + 'Processing ' + this.listNewContracts.size() + ' contract(s)');

        for (Contract oContractNew : this.listNewContracts) {

            Contract oContractOld = this.mapOldContracts != null ? this.mapOldContracts.get(oContractNew.Id) : null;

            if (oContractNew.Status == 'Activated' && oContractNew.ConfirmedDeliveryStart__c != oContractOld.ConfirmedDeliveryStart__c) {

                // filled -> empty
                if (oContractNew.ConfirmedDeliveryStart__c == null) {
                    oContractNew.ConfirmedDeliveryStart__c.addError('This field cannot be emptied after activation');
                    System.debug(DEBUG_HERE + 'Error on contract ' + oContractNew.Id + ': ConfirmedDeliveryStart__c cannot be emptied after activation from ' + oContractOld.ConfirmedDeliveryStart__c + ' to ' + oContractNew.ConfirmedDeliveryStart__c);
                    continue;
                }

                mapContractsWithDeliveryStartChange.put(oContractNew.Id, oContractNew);

                // Force an error in after trigger during test
                if (Test.isRunningTest() && oContractNew.ContractingPartyEmail__c == ContractTriggerHandlerTest.TEST_CONTRACT_MAIL_WITH_BONUS_ERROR) {
                    System.debug(DEBUG_HERE + 'Set test error for the contract with ContractingPartyEmail__c "' + ContractTriggerHandlerTest.TEST_CONTRACT_MAIL_WITH_BONUS_ERROR + '"');
                    oContractNew.addError('Test error');
                }
            }
            else {
                System.debug(DEBUG_HERE + 'Contract ' + oContractNew.Id + ' is not activated or has no change in ConfirmedDeliveryStart__c');
            }
        }

        if (!mapContractsWithDeliveryStartChange.isEmpty()) {

            System.debug(DEBUG_HERE + 'Found ' + mapContractsWithDeliveryStartChange.size() + ' contracts with changed ConfirmedDeliveryStart__c');

            Set<Id> lsetContractIds = mapContractsWithDeliveryStartChange.keySet();
            List<Bonus__c> listBonuses = (List<Bonus__c>)Database.query('SELECT ' + DiaUtilities.returnAllFieldsAsString('Bonus__c') + ', Contract__r.CustomerSignedId FROM Bonus__c WHERE Contract__c IN :lsetContractIds');
            List<Bonus__c> listBonusesToActivate = new List<Bonus__c>();

            for (Bonus__c oBonus : listBonuses) {

                Contract oContract = mapContractsWithDeliveryStartChange.get(oBonus.Contract__c);
                System.debug(DEBUG_HERE + 'Bonus for contract ' + oContract.Id);

                if (oBonus.Lumenaza_IsApiSynced__c) {

                    if (oBonus.StartDate__c != oContract.StartDate) {
                        System.debug(DEBUG_HERE + '    Bonus is already synced to Lumenaza - skipping');
                        // Bonus is already synced to Lumenaza
                        // Case here?
                    }
                    continue;
                }

                // Activate, rest is done by class "LumenazaBonus"
                oBonus.Active__c    = true;
                oBonus.StartDate__c = oBonus.ContractConfirmedDeliveryStart__c;

                System.debug(DEBUG_HERE + '    Bonus will be activated: ' + JSON.serializePretty(oBonus.getPopulatedFieldsAsMap()));

                listBonusesToActivate.add(oBonus);
            }

            if (!listBonusesToActivate.isEmpty()) {

                System.debug(DEBUG_HERE + 'Updating ' + listBonusesToActivate.size() + ' bonus(es) to activate');

                TriggerHandler.bypass('ContractTriggerHandler', 'listBonusesToActivate');
                try {
                    update listBonusesToActivate;
                }
                catch (Exception e) {
                    TriggerHandler.clearBypass('ContractTriggerHandler', 'listBonusesToActivate');
                }
                TriggerHandler.clearBypass('ContractTriggerHandler', 'listBonusesToActivate');


                // Now set status of campaign members by searching with ContactId - CampaignId__c pairs
                List<String> listCampaignContactQueryPairs = new List<String>();

                for (Bonus__c oBonus : listBonusesToActivate) {
                    if (oBonus.Contract__r.CustomerSignedId != null && oBonus.CampaignId__c != null) {
                        listCampaignContactQueryPairs.add(
                            '(ContactId=\'' + oBonus.Contract__r.CustomerSignedId + '\' AND CampaignId=\'' + oBonus.CampaignId__c + '\')'
                        );
                    }
                }

                // Only if there are valid ContactId-CampaignId pairs (SOBCRM-1231)
                // This should normally not be the case ;)
                if (!listCampaignContactQueryPairs.isEmpty()) {

                    String sSOQL =
                        'SELECT Id, Status ' +
                        'FROM CampaignMember ' +
                        'WHERE Status = :BONUS_CODE_CAMPAIGN_MEMBER_INITIAL_STATUS AND (' + String.join(listCampaignContactQueryPairs, ' OR ') + ')';

                    System.debug(DEBUG_HERE + 'Search for campaign members to update: ' + sSOQL);
                    List<CampaignMember> listCampaignMembers = (List<CampaignMember>)Database.query(sSOQL);

                    if (!listCampaignMembers.isEmpty()) {

                        System.debug(DEBUG_HERE + 'Found ' + listCampaignMembers.size() + ' campaign members to update to status "' + BONUS_CODE_CAMPAIGN_MEMBER_REDEEMED_STATUS + '"');

                        for (CampaignMember oCampaignMember : listCampaignMembers) {
                            oCampaignMember.Status = BONUS_CODE_CAMPAIGN_MEMBER_REDEEMED_STATUS;
                        }

                        update listCampaignMembers;
                    }
                    else {
                        System.debug(DEBUG_HERE + 'None found!');
                    }
                }
                else {
                    System.debug(DEBUG_HERE + 'listCampaignContactQueryPairs is empty - no CampaignMember status will be updated (SOBCRM-1231)');
                }
            }
        }

        System.debug(DEBUG_HERE + 'END');
    }

    /**
     * Sets bank data to Contract from related BankData record
     * if Contract.BankData__c has changed
     * If it was set to NULL concerning fields will be set to NULL
     *
     * @see GeneralTriggerTests.testBankDataChange()
     * @author Marko Schmalenbach <marko@die-interaktiven.de>
     * @since 2016-12-16
     */
    private void setBankDataFromRelatedBankData() {

        String DEBUG_HERE = DEBUG_HEADER + 'setBankDataFromRelatedBankData() - ';

        if (isBypassedMethod('setBankDataFromRelatedBankData')) {
            System.debug(DEBUG_HERE + 'is bypassed!');
            return;
        }

        Set<Id> lsetBankDataIds = new Set<Id>();
        Map<String,String> mapMappingBankDataContractFields = BankDataTriggerHandler.mapMappingBankDataContractFields;

        Map<Id,Contract> mapContractOld = (Map<Id,Contract>)Trigger.oldMap;
        Set<Id> lsetContractsWithBankDataToReset = new Set<Id>();

        for (Contract oContract : (List<Contract>)Trigger.new) {

            // UPDATE
            if (Trigger.isUpdate) {

                Contract oContractOld = mapContractOld.get(oContract.Id);

                // If BankData relation was deleted
                if (oContractOld.BankData__c != NULL && oContract.BankData__c == NULL) {
                    System.debug(DEBUG_HERE + 'BankData__c has changed to NULL for Contract ' + oContract.ContractNumber);
                    lsetContractsWithBankDataToReset.add(oContract.Id);
                }
                // Else if BankData is given and has changed
                else if (Contract.BankData__c != NULL && oContractOld.BankData__c != oContract.BankData__c) {
                    lsetBankDataIds.add(oContract.BankData__c);
                }
            }
            // INSERT
            else if (Trigger.isInsert && oContract.BankData__c != NULL) {
                lsetBankDataIds.add(oContract.BankData__c);
            }
        }

        Map<Id,BankData__c> mapBankData = new Map<Id,BankData__c>();

        // Set bank data from BankData__c
        if (!lsetBankDataIds.isEmpty()) {

            List<BankData__c> listBankDatas = (List<BankData__c>) Database.query('SELECT Id,' + String.join(new List<String>(mapMappingBankDataContractFields.keySet()), ',') + ' FROM BankData__c WHERE Id IN :lsetBankDataIds');

            for (BankData__c oBankData : listBankDatas) {
                mapBankData.put(oBankData.Id, oBankData);
            }
        }

        for (Contract oContract : (List<Contract>)Trigger.new) {

            BankData__c oBankData;

            if (oContract.BankData__c != NULL && mapBankData.get(oContract.BankData__c) != NULL) {
                oBankData = mapBankData.get(oContract.BankData__c);
            }

            for (String sBankDataField : mapMappingBankDataContractFields.keySet()) {

                String sContractField = mapMappingBankDataContractFields.get(sBankDataField);

                if (oBankData != NULL) {
                    oContract.put(sContractField, oBankData.get(sBankDataField));
                    System.debug(DEBUG_HERE + '(' + (Trigger.isInsert ? 'INSERT' : (Trigger.isUpdate ? 'UPDATE' : 'Unknown trigger context')) + ') Set Contract field "' + sContractField + '" to "' + oBankData.get(sBankDataField) + '"');
                }
                else if (lsetContractsWithBankDataToReset.contains(oContract.Id)) {
                    oContract.put(sContractField, NULL);
                    System.debug(DEBUG_HERE + '(UPDATE) Set Contract field "' + sContractField + '" to NULL');
                }
            }
        }
    }

    /**
     * Synchronize contract to Lumenaza
     */
    private void synchronizeToLumenaza() {

        String DEBUG_HERE = DEBUG_HEADER + 'synchronizeToLumenaza() - ';

        if (isBypassedMethod('synchronizeToLumenaza')) {
            System.debug(DEBUG_HERE + 'is bypassed!');
            return;
        }

        System.debug(DEBUG_HERE + 'START');

        Set<LumenazaObject> lumenazaContractsToUpsert = new Set<LumenazaObject>();

        // Get contracts before
        Map<Id,Contract> oldMap = (Map<Id,Contract>) Trigger.oldMap;

        Map<String,Id> mapRecordTypes = DiaUtilities.getRecordTypeMap(new List<String>{'Contract'}).get('Contract');

        Set<Id> lsetAccountIds = new Set<Id>();

        for (Contract contractAfter : (List<Contract>) Trigger.new) {

            // System.debug(DEBUG_HERE + 'Contract: ' + JSON.serializePretty(contractAfter.getPopulatedFieldsAsMap()));

            // This can be evaluated because it's after trigger event!
            if (!contractAfter.IsValidForLumenazaSync__c) {
                System.debug(DEBUG_HERE + 'Contract\'s IsValidForLumenazaSync__c is false - skip');
                continue;
            }

            // Instantiate a LumenazaContract by a Contract
            LumenazaContract lumenazaContract = new LumenazaContract(contractAfter);

            // Set old Contract on update
            if (Trigger.isUpdate) {
                Contract contractBefore = oldMap.get(contractAfter.id);
                lumenazaContract.setContractBefore(contractBefore);
            }
            // Add LumenazaContract to upsert list
            lumenazaContractsToUpsert.add(lumenazaContract);

            Id idAccount = contractAfter.AccountId;

            if (idAccount != NULL) {
                /*
                if (lsetAccountIds.contains(idAccount)) {
                    throw new Exception(
                        'Cannot create more than one Lumenaza Contract for the same Account at the same time as the first ' +
                        'Contract has to wait for the customer ID at Lumenaza! Otherwise the second Contract' +
                        'would fail with an "saas_customer_id not unique" error.'
                    );
                }
                else {
                    lsetAccountIds.add(idAccount);
                }
                */
                lsetAccountIds.add(idAccount);
            }
        }

        // If any LumenazaContract validates to false everything is rolled
        // back otherwise Contracts will be upserted if API Sync is active
        if (!lumenazaContractsToUpsert.isEmpty()) {

            Map<Id,List<String>> mapAccountIdToLumenazaCustomerId = LumenazaContract.checkOnMultipleContractsByAccountIds(lsetAccountIds);
            Set<Id> lsetAccountToInsertAContractFor = new Set<Id>();

            for (LumenazaObject lumenazaObject : lumenazaContractsToUpsert) {

                LumenazaContract lumenazaContract = (LumenazaContract)lumenazaObject;

                Id idAccount = lumenazaContract.getContract().AccountId;
                Integer iCountOfAccountLumenazaCustomerIds = mapAccountIdToLumenazaCustomerId.get(idAccount).size();

                if (iCountOfAccountLumenazaCustomerIds > 1) {
                    lumenazaContract.getContract().addError('Contract\'s Account has Contracts with multiple Lumenaza Customer IDs (' + String.join(mapAccountIdToLumenazaCustomerId.get(idAccount) , ', ') + ')!');
                }
                else if (iCountOfAccountLumenazaCustomerIds == 1) {

                    String sExistingLumenazaCustomerId = mapAccountIdToLumenazaCustomerId.get(idAccount).get(0);

                    // Set that this Contract's Account is an already existing
                    // Lumenaza Customer
                    lumenazaContract.setIsAccountLumenazaCustomer(TRUE, sExistingLumenazaCustomerId);
                }
                else {
                    // Contract's Account has no existing Lumenaza Contract
                    // and therefore no Lumenaza Customer ID
                    lumenazaContract.setIsAccountLumenazaCustomer(FALSE, NULL);
                }

                // Get upsert mode
                // (This MUST be called after setIsAccountLumenazaCustomer()! Otherwise
                // each Contract will query for itsself if their Account already is a
                // Lumenaza Customer!)
                String sUpsertMode = lumenazaContract.getUpsertMode();

                // Check if there are inserts of multiple Contracts for same Account
                // and raise an error if so
                if (sUpsertMode == 'insert' || sUpsertMode == 'insertForExistingCustomer') {
                    if (lsetAccountToInsertAContractFor.contains(idAccount)) {
                        lumenazaContract.getContract().addError(
                            'Cannot insert multiple Contracts for same Account at the same time! ' +
                                'This would raise an error at Lumenaza as this process is done asynchronously ' +
                                'and new Contracts for existing Customers have to be handled specially!'
                        );
                    }
                    else {
                        lsetAccountToInsertAContractFor.add(idAccount);
                    }
                }
            }

            // Try to init the Contract upsert and if any validation fails stop
            // the activation process by raising an validation error
            if (LumenazaApi.initUpsert(lumenazaContractsToUpsert) == FALSE) {

                for (LumenazaObject lumenazaObject : lumenazaContractsToUpsert) {

                    LumenazaContract lumenazaContract = (LumenazaContract)lumenazaObject;

                    if (lumenazaContract.hasError() == true) {
                        lumenazaContract.getContract().addError(lumenazaContract.getError());
                    }
                }
            }
        }

        System.debug(DEBUG_HERE + 'END');
    }

    private void sanitizeIbanNumber() {
        // IBAN to uppercase and without invalid characters
        for (Contract contract : (List<Contract>) Trigger.new) {
            if (contract.BankDataIBAN__c != NULL) {
                contract.BankDataIBAN__c = contract.BankDataIBAN__c.toUpperCase().replaceAll('[^A-Z0-9]', '');
            }
        }
    }

    /**
     * Collects all Account IDs of the triggers Contracts
     * for setting their CustomerNoDatev__c (independent of
     * the Contract's acitvation status!)
     *
     * @see https://interaktiv.jira.com/browse/SOBCRM-912
     */
    private void setCustomerNumber() {

        String DEBUG_HERE = DEBUG_HEADER + 'setCustomerNumber() - ';

        if (isBypassedMethod('setCustomerNumber')) {
            System.debug(DEBUG_HERE + 'is bypassed!');
            return;
        }

        List<Contract> listContracts = new List<Contract>();

        for (Contract oContract : (List<Contract>) Trigger.new) {
            listContracts.add(oContract);
        }

        setCustomerNumber(listContracts);
    }

    /**
     * Creates and set Account's CustomerNoDatev__c related
     * to the given Contracts
     */
    private void setCustomerNumber(List<Contract> contracts) {

        Set<Id> lsetAccounts = new Set<Id>();
        Integer iNextCustomerNo = AccountService.getNextDatevNumber();

        for (Contract oContract : contracts) {
            lsetAccounts.add(oContract.AccountId);
        }

        // Only set Datev No if not set yet
        Map<Id,Account> mapAccountsByIds = new Map<Id,Account>([
            SELECT  CustomerNoDatev__c
            FROM    Account
            WHERE   Id IN: lsetAccounts
            AND     CustomerNoDatev__c = NULL
            ORDER BY Id ASC
        ]);

        AccountService.updateAccountsCustomerDatevNumber(mapAccountsByIds.values(), iNextCustomerNo);

        // Set ContractingPartyDatevNo__c in Contract
        for (Contract oContract : (List<Contract>) Trigger.new) {
            if (mapAccountsByIds.containsKey(oContract.AccountId) ) {
                oContract.ContractingPartyDatevNo__c = mapAccountsByIds.get(oContract.AccountId).CustomerNoDatev__c;
            }
        }
    }

    class ContractTriggerHandlerException extends Exception {}
}