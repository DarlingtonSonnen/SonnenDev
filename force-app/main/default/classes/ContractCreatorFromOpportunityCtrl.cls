/**
 * ContractCreatorFromOpportunityCtrl
 *
 * Controller for Lightning Component "ContractCreatorFromOpportunity"
 *
 * v1.0     2018-04-11  Polina Tsuban-Drobot        Initial (SOBCRM-1163)
 * v1.1     2018-04-26  Polina Tsuban-Drobot        Implemented contract creation, error handling, dynamic labels (SOBCRM-1163)
 * v1.2     2018-05-10  Alexey Yamaev               Dynamic fields for Order Input Definition Values supported (SOBCRM-1183)
 * v1.3     2018-05-14  Alexey Yamaev               Implemented ability to change Order Input Definition Values Visibility (SOBCRM-1191)
 * v1.3.1   2018-10-12  Marko Schmalenbach          Added debugging
 * v1.4.0   2018-11-19  Marko Schmalenbach          Added Order Input Definition Value ordering by
 *                                                  OrderInputDefinition__r.ContractCreatorOrder__c DESC NULLS LAST (SOBCRM-1281)
 * v1.5.0   2018-11-21  Marko Schmalenbach          Implemented saveValues() to be update the Order Input Definition Values
 *                                                  without creating a Contract (SOBCRM-1290)
 * v1.6.0   2019-01-14  Marko Schmalenbach          - Implemented Contract Change (SOBCRM-1310)
 *                                                  - Removed checkbox values IsEnergyTariffClassified__c, IsInstallerSpezified__c, IsPVSizeSpezified__c, IsInstallationDocumented__c (SOBCRM-1310)
 * v1.6.1   2019-02-18  Marko Schmalenbach          Switched from dedicated field for Change Reason on Opportunity to existing Order Input Definition Value (SOBCRM-1310)
 *
 * @see ContractCreatorFromOpportunityCtrlTest
 */
public class ContractCreatorFromOpportunityCtrl {

    private static final String DEBUG_HEADER = 'ContractCreatorFromOpportunityCtrl.';

    @AuraEnabled public Opportunity opp {get;set;}
    @AuraEnabled public Contract newContract {get;set;}
    @AuraEnabled public Map<String, Map<String, String>> mapLabels {get; private set;}

    @AuraEnabled public LookupSearchResult lookupSearchResultPreviousContractProposal {get;set;}

    @AuraEnabled public List<OrderInputDefinitionValueWrapper> orderInpDefVal {get;set;}
    @AuraEnabled public Boolean contractCreated {get;set;}
    @AuraEnabled public Boolean isContractChange = false;

    @AuraEnabled public final String NOT_VISIBLE = 'Not Visible';
    @AuraEnabled public final String EDITABLE = 'Editable';

    private static final String WON_STAGE = 'Ordered';
    private static final String ERROR_OPP_NOT_FOUND = 'Opportunity with Id = {0} not found.';
    private static final String ERROR_IN_CONTRACT_CREATION = 'An error occurred on Contract creation: ';
    private static final String ERROR_IN_VALUES_LOADING = 'An error occurred on loading Order Order Input Definition Values.';
    private static final String CHATTER_TITLE = 'Contract created';
    private static final String CHATTER_BODY = '<p>The contract {0} was successfully created by {1} {2}.</p>';
    private static final String CONTRACT_OBJECT_NAME = 'Contract';

    @TestVisible
    private static final String CONTRACT_CHANGE_REASON = 'ContractChange';
    @TestVisible
    private static final String CONTRACT_CHANGE_REASON_OID_ID = 'cProviderChangeReason';

    @AuraEnabled public final String contractChangeReason {
        get {
            return CONTRACT_CHANGE_REASON;
        }
    }


    @AuraEnabled public final String contractChangeOidReasonId {
        get {
            return CONTRACT_CHANGE_REASON_OID_ID;
        }
    }

    private static final String STRING_TYPE = 'STRING';
    private static final String DOUBLE_TYPE = 'DOUBLE';
    private static final String INTEGER_TYPE = 'INTEGER';
    private static final String BOOLEAN_TYPE = 'BOOLEAN';
    private static final String PICKLIST_TYPE = 'PICKLIST';
    private static final String MULTIPICKLIST_TYPE = 'MULTIPICKLIST';
    private static final String PERCENT_TYPE = 'PERCENT';
    private static final String DATE_TYPE = 'DATE';
    private static final String DATETIME_TYPE = 'DATETIME';
    private static final String CURRENCY_TYPE = 'CURRENCY';
    private final static Integer MAX_RESULTS = 5;

    @AuraEnabled
    public static ContractCreatorFromOpportunityCtrl initComponent(Id oppId) {

        ContractCreatorFromOpportunityCtrl ctrl = new ContractCreatorFromOpportunityCtrl();
        ctrl.opp = ctrl.retrieveOpp(oppId);
        ctrl.orderInpDefVal = ctrl.retrieveOrderInputDefinitionValues(oppId);
        ctrl.newContract = new Contract();

        ctrl.initializeFieldLabels();

        if (ctrl.isContractChange) {

            Contract oContract = getPreviousContractForChange(ctrl.opp.AccountId);

            if (oContract != null) {
                ctrl.lookupSearchResultPreviousContractProposal = createLookupSearchResultFromContract(oContract);
            }
        }

        return ctrl;
    }

    @AuraEnabled
    public static ContractCreatorFromOpportunityCtrl refreshComponent(String ctrlJSON) {
        ContractCreatorFromOpportunityCtrl ctrl = (ContractCreatorFromOpportunityCtrl)JSON.deserialize(ctrlJSON, ContractCreatorFromOpportunityCtrl.class);
        ctrl.opp = ctrl.retrieveOpp(ctrl.opp.Id);
        ctrl.orderInpDefVal = ctrl.retrieveOrderInputDefinitionValues(ctrl.opp.Id);
        return ctrl;
    }

    /**
     * Converts a Contract to a LookupSearchResult
     *
     * @param oContract
     *
     * @return
     */
    private static LookupSearchResult createLookupSearchResultFromContract(Contract oContract) {

        return new LookupSearchResult(
            oContract.Id,
            'Contract',
            'standard:contract',
            oContract.ContractNumber + ' ' + oContract.RecordType.Name + ' - ' + oContract.ContractingPartnerFirstname__c + ' ' + oContract.ContractingPartnerLastname__c + ' (' + oContract.Account.CustomerNo__c + ')',
            'Contract Start: ' + oContract.StartDate.format() + ' • Meter: ' + oContract.MeterId__c
        );
    }

    /**
     * Try to find a previous activated Contract of the customer
     * for a Contract change
     *
     * @param idAccount
     *
     * @return
     */
    private static Contract getPreviousContractForChange(Id idAccount) {

        List<Contract> listContracts = [
            SELECT
                Id,
                ContractNumber,
                RecordType.Name ,
                ContractingPartnerFirstname__c,
                ContractingPartnerLastname__c,
                StartDate,
                MeterId__c,
                Account.CustomerNo__c
            FROM
                Contract
            WHERE
                Status = 'Activated' AND
                AccountId = :idAccount AND
                (NOT RecordType.DeveloperName LIKE 'Community%')
        ];

        if (listContracts.size() != 1) {
            return null;
        }

        return listContracts.get(0);
    }

    /**
     * search Contract
     *
     * @param searchTerm
     * @param selectedIds
     *
     * @return
     */
    @AuraEnabled
    public static List<LookupSearchResult> search(String searchTerm, List<String> selectedIds) {

        // Prepare query parameters
        searchTerm += '*';

        // Execute search query
        List<List<SObject>> listSearchResults = [
            FIND
                :searchTerm
            IN ALL FIELDS RETURNING Contract (
                    Id,
                    ContractNumber,
                    RecordType.Name,
                    ContractingPartnerFirstname__c,
                    ContractingPartnerLastname__c,
                    StartDate,
                    MeterId__c,
                    Account.CustomerNo__c
                WHERE
                    Status = 'Activated' AND
                    (NOT RecordType.DeveloperName LIKE 'Community%')
            )
            LIMIT :MAX_RESULTS
        ];

        // Prepare results
        List<LookupSearchResult> listLookupSearchResult = new List<LookupSearchResult>();

        // Extract Contracts & convert them into LookupSearchResult
        List<Contract> listContracts = ((List<Contract>) listSearchResults[0]);

        for (Contract oContract : listContracts) {
            listLookupSearchResult.add(createLookupSearchResultFromContract(oContract));
        }

        return listLookupSearchResult;
    }

    /**
     * Save OrderInputDefinitionValues
     *
     * Values are only update if they were changed
     *
     * @param ctrlJSON
     *
     * @return
     */
    @AuraEnabled
    public static ContractCreatorFromOpportunityCtrl saveValues(String ctrlJSON) {

        final String DEBUG_HERE = DEBUG_HEADER + 'saveValues() - ';

        ContractCreatorFromOpportunityCtrl ctrl = (ContractCreatorFromOpportunityCtrl)JSON.deserialize(ctrlJSON, ContractCreatorFromOpportunityCtrl.class);
        validateValues(ctrl.orderInpDefVal);

        System.debug(DEBUG_HERE + 'Is Contract Change: ' + ctrl.isContractChange + ', new Contract: ' + ctrl.newContract);
        // return ctrl;

        List<OrderInputDefinitionValue__c> listOrderInputDefinitionValuesToUpdate = new List<OrderInputDefinitionValue__c>();
        List<OrderInputDefinitionValue__c> listOrderInputDefinitionValues = getOrderInputDefinitionValues(ctrl);
        Set<Id> lsetIds = new Set<Id>();

        for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listOrderInputDefinitionValues) {
            lsetIds.add(oOrderInputDefinitionValue.Id);
        }

        Map<Id, OrderInputDefinitionValue__c> mapCurrentOrderInputDefinitionValues = new Map<Id, OrderInputDefinitionValue__c>([
            SELECT Id, Value__c, OrderInputDefinition__r.Id__c
            FROM OrderInputDefinitionValue__c
            WHERE Id IN :lsetIds
        ]);

        for (OrderInputDefinitionValue__c oOrderInputDefinitionValue : listOrderInputDefinitionValues) {

            OrderInputDefinitionValue__c oOrderInputDefinitionValueCurrent = mapCurrentOrderInputDefinitionValues.get(oOrderInputDefinitionValue.Id);
            String sNewValue     = oOrderInputDefinitionValue.Value__c;
            String sCurrentValue = oOrderInputDefinitionValueCurrent.Value__c;

            sNewValue = String.isBlank(sNewValue) ? null : sNewValue;
            String sMessage = oOrderInputDefinitionValueCurrent.OrderInputDefinition__r.Id__c + ' - new: "' + sNewValue + '", old: "' + sCurrentValue + '"';

            if (sNewValue != sCurrentValue) {
                System.debug(DEBUG_HERE + ' CHANGED ' + sMessage);
                listOrderInputDefinitionValuesToUpdate.add(oOrderInputDefinitionValue);
            }
            else {
                System.debug(DEBUG_HERE + ' UNCHANGED ' + sMessage);
            }
        }

        if (!listOrderInputDefinitionValuesToUpdate.isEmpty()) {
            update listOrderInputDefinitionValuesToUpdate;
            ctrl.orderInpDefVal = ctrl.retrieveOrderInputDefinitionValues(ctrl.opp.Id);
        }

        return ctrl;
    }

    /**
     * Create a Contract
     *
     * @param ctrlJSON
     *
     * @return
     */
    @AuraEnabled
    public static ContractCreatorFromOpportunityCtrl createContract(String ctrlJSON) {

        ContractCreatorFromOpportunityCtrl ctrl = saveValues(ctrlJSON);

        // Why should Opportunity be updated?
        //update ctrl.opp;

        Id contractId = ctrl.safelyCreateContract(ctrl.newContract);

        if (contractId != null) {

            ctrl.opp.StageName = WON_STAGE;
            update ctrl.opp;

            ctrl.createChatterPost(contractId);
        }

        return ctrl;
    }

    private Opportunity retrieveOpp(Id oppId) {
        List<Opportunity> opps = [
            SELECT  Id,
                    AccountId,
                    ContractDataApproved__c,
                    IsClosed
            FROM Opportunity
            WHERE Id = :oppId
        ];

        if (opps.isEmpty()) {
            throw new AuraHandledException(String.format(ERROR_OPP_NOT_FOUND, new List<String>{oppId}));
        }

        return opps[0];
    }

    private List<OrderInputDefinitionValueWrapper> retrieveOrderInputDefinitionValues(Id oppId) {

        List<OrderInputDefinitionValue__c> orderInputDefinitionValues = [
            SELECT
                Id,
                Value__c,
                OriginalValue__c,
                OrderInputDefinitionLabel__c,
                OrderInputDefinitionTargetField__c,
                OrderInputDefinition__r.Visibility__c,
                OrderInputDefinitionFieldId__c
            FROM
                OrderInputDefinitionValue__c
            WHERE
                Opportunity__c = :oppId AND
                (OrderInputDefinition__r.Visibility__c != :NOT_VISIBLE OR OrderInputDefinitionFieldId__c = :CONTRACT_CHANGE_REASON_OID_ID)
            ORDER BY
                OrderInputDefinition__r.ContractCreatorOrder__c DESC NULLS LAST,
                OrderInputDefinitionLabel__c ASC
        ];

        List<OrderInputDefinitionValueWrapper> oidValuesWrapperList = new List<OrderInputDefinitionValueWrapper>();
        Map<String, Schema.SObjectField> contractMap = Schema.SObjectType.Contract.fields.getMap();
        Schema.DisplayType fieldType;
        String targetField;
        OrderInputDefinitionValueWrapper oidValueWrapper;
        Schema.SObjectField field;

        for (OrderInputDefinitionValue__c oidValue : orderInputDefinitionValues) {

            if (oidValue.OrderInputDefinitionFieldId__c == CONTRACT_CHANGE_REASON_OID_ID) {

                this.isContractChange = (oidValue.Value__c == CONTRACT_CHANGE_REASON);

                // Skip value if not visible
                if (oidValue.OrderInputDefinition__r.Visibility__c == NOT_VISIBLE) {
                    continue;
                }
            }

            oidValueWrapper = new OrderInputDefinitionValueWrapper();
            oidValueWrapper.item = oidValue;
            targetField = oidValue.OrderInputDefinitionTargetField__c;

            if (String.isNotEmpty(targetField) && targetField.split('\\.').size() == 2) {
                field = contractMap.get(targetField.split('\\.')[1]);

                if (field != null) {

                    fieldType = field.getDescribe().getType();
                    oidValueWrapper.type = fieldType.name();

                    try {
                        if (fieldType.name() == BOOLEAN_TYPE) {
                            oidValueWrapper.objValue = new BooleanType(oidValue.Value__c);
                        } else if (fieldType.name() == DOUBLE_TYPE || fieldType.name() == CURRENCY_TYPE || fieldType.name() == PERCENT_TYPE) {
                            oidValueWrapper.objValue = new DoubleType(oidValue.Value__c);
                        } else if (fieldType.name() == PICKLIST_TYPE || fieldType.name() == MULTIPICKLIST_TYPE) {
                            oidValueWrapper.objValue = new StringType(oidValue.Value__c);
                            oidValueWrapper.options = getPicklistValues(CONTRACT_OBJECT_NAME, targetField.split('\\.')[1]);
                        } else if (fieldType.name() == DATE_TYPE) {
                            oidValueWrapper.objValue = new DateType(oidValue.Value__c);
                        } else {
                            oidValueWrapper.objValue = new StringType(oidValue.Value__c);
                        }
                        oidValuesWrapperList.add(oidValueWrapper);
                    } catch (TypeException te) {
                        throw new AuraHandledException(ERROR_IN_VALUES_LOADING + ' ' + te.getMessage());
                    }
                }
            }
        }
        return oidValuesWrapperList;
    }

    private static Map<String, String> getPicklistValues(String sObjectName, String picklistField) {
        Map<String, String> options = new Map<String, String>();
        Schema.SObjectType dsr = Schema.getGlobalDescribe().get(sObjectName);
        if (dsr != NULL) {
            Schema.DescribeFieldResult stagesFR = dsr.getDescribe().fields.getMap().get(picklistField.trim()).getDescribe();
            List<Schema.PicklistEntry> stagesPle = stagesFR.getPicklistValues();

            for (Schema.PicklistEntry s : stagesPle) {
                options.put(s.getValue(), s.getLabel());
            }
        }
        return options;
    }

    private void initializeFieldLabels() {

        this.mapLabels = new Map<String, Map<String, String>>();

        for (String sSObjectName : new List<String>{'Contract', 'Opportunity'}) {
            this.mapLabels.put(sSObjectName, this.getSObjectLabelMap(sSObjectName));
        }
    }

    /**
     * Get label map for an SObject
     *
     * @param objectName
     *
     * @return
     */
    private Map<String, String> getSObjectLabelMap(String objectName) {

        Map<String, String> mapFieldLabels = new Map<String, String>();
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();

        for (String sField : fieldMap.keySet()) {
            DescribeFieldResult oFieldDescribe = fieldMap.get(sField).getDescribe();
            mapFieldLabels.put(oFieldDescribe.getName(), oFieldDescribe.getLabel());
        }

        return mapFieldLabels;
    }

    private Id safelyCreateContract() {
        return this.safelyCreateContract(null);
    }

    private Id safelyCreateContract(Contract oContract) {

        Contract contract;

        try {
            contract = WebOrderContractCreator.createWebOrderContract(this.opp.Id);

            // For Contract Change
            if (oContract != null && oContract.ContractPrevious__c != null) {
                contract.ContractPrevious__c       = oContract.ContractPrevious__c;
                contract.MeterReadingValueStart__c = oContract.MeterReadingValueStart__c;
                contract.StartDate                 = oContract.StartDate;
                contract.SubscriptionReason__c     = contractChangeReason; // Usually already set by createWebOrderContract()
                update contract;
            }
        }
        catch (Exception e) {
            System.debug(ERROR_IN_CONTRACT_CREATION + ' ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException(ERROR_IN_CONTRACT_CREATION + ' ' + e.getMessage()); // when OrderInputDefinitionValues are invalid
        }

        // We create Contract in WebOrderContractCreator only in case we have
        // at least 1 Product with RecordType="eService" on Opportunity.
        // Otherwise we don't create anything.
        // In this case we show information message on the component
        this.contractCreated = contract != null;

        return this.contractCreated ? contract.Id : null;
    }

    private void createChatterPost(Id contractId) {
        String contractNumber = [SELECT ContractNumber FROM Contract WHERE Id = :contractId].ContractNumber;
        FeedItem post = new FeedItem();
        post.Title = CHATTER_TITLE;
        post.Body = String.format(CHATTER_BODY, new List<String>{contractNumber, UserInfo.getFirstName(), UserInfo.getLastName()});
        post.ParentId = this.opp.Id;
        post.IsRichText = true;
        insert post;
    }

    private static List<OrderInputDefinitionValue__c> getOrderInputDefinitionValues(ContractCreatorFromOpportunityCtrl ctrl) {
        List<OrderInputDefinitionValue__c> orderInputDefinitionValues = new List<OrderInputDefinitionValue__c>();
        for (OrderInputDefinitionValueWrapper wrapper : ctrl.orderInpDefVal) {
            orderInputDefinitionValues.add(wrapper.item);
        }
        return orderInputDefinitionValues;
    }

    private static void validateValues(List<OrderInputDefinitionValueWrapper> oidvWrapperList) {
        try {
            for (OrderInputDefinitionValueWrapper wrapper : oidvWrapperList) {
                if (wrapper.type == DOUBLE_TYPE || wrapper.type == CURRENCY_TYPE || wrapper.type == PERCENT_TYPE) {
                    new DoubleType(wrapper.item.Value__c);
                } else if (wrapper.type == DATE_TYPE) {
                    new DateType(wrapper.item.Value__c);
                } else if (wrapper.type == DATETIME_TYPE) {
                    new DateTimeType(wrapper.item.Value__c);
                }
            }
        }
        catch (TypeException te) {
            throw new AuraHandledException(ERROR_IN_CONTRACT_CREATION + ' ' + te.getMessage());
        }

    }

    public class OrderInputDefinitionValueWrapper {
        @AuraEnabled OrderInputDefinitionValue__c item {get;set;}
        @AuraEnabled String type {get;set;}
        @AuraEnabled ObjectType objValue {get;set;}
        @AuraEnabled Map<String, String> options {get;set;}
    }

    public virtual class ObjectType { }

    public class BooleanType extends ObjectType {
        @AuraEnabled public Boolean value {get;set;}
        public BooleanType(String value) {
            this.value = (value != null) ? Boolean.valueOf(value) : false;
        }
    }

    public class StringType extends ObjectType {
        @AuraEnabled public String value {get;set;}
        public StringType(String value) {
            this.value = value;
        }
    }

    public class DoubleType extends ObjectType {
        @AuraEnabled public Double value {get;set;}
        public DoubleType(String value) {
            this.value = (value != null) ? Double.valueOf(value) : 0;
        }
    }

    public class DateType extends ObjectType {
        @AuraEnabled public Date value {get;set;}
        public DateType(String value) {
            this.value = (value != null) ? Date.valueOf(value) : null;
        }
    }

    public class DateTimeType extends ObjectType {
        @AuraEnabled public DateTime value {get;set;}
        public DateTimeType(String value) {
            // Convert from Date type due to incorrect converting of DateTime from DateTime :(
            this.value = (value != null) ? Date.valueOf(value) : null;
        }
    }
}