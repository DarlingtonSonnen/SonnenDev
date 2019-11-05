/**
 * ConstraintValidator
 *
 * Changelog
 * ---------
 *
 * v1.0.0-2018-02-16
 * - Initial
 *
 * @author  Marko Schmalenbach <marko@die-interaktiven.de>
 * @version 1.0.0-2018-02-16
 * @see RESTServiceOrder_Test
 * @see RESTServiceOrder
 */
public class ConstraintValidator {

    public static List<String> debugMessages = new List<String>();

    private final String DEBUG_HEADER = 'ConstraintValidator.';

    private Map<Id,OrderInputDefinitionConstraint> constraintsToOrderInputDefinitionValueId = new Map<Id,OrderInputDefinitionConstraint>();

    private Map<Id,ConstraintGroup__c> constraintGroupsByIds = new Map<Id,ConstraintGroup__c>();

    public ConstraintValidator() {
    }

    /**
     * Init Validator by a set of OrderInputDefinitionIds
     * to find constraints for
     *
     * @param orderInputDefinitionIds
     */
    public void init(Set<Id> orderInputDefinitionIds) {

        String DEBUG_HERE = DEBUG_HEADER + 'init() - ';

        /*
            Map<Id,Object> Id of OrderInputDefinition => Map (
                'constraints' => List<Constraint__c>(),
                'constraintGroups' => List<ConstraintValidatorGroup>()
            )
         */

        Map<Id,OrderInputDefinition__c> mapConstraintsToOrderInputDefinitionValueIdTmp = new Map<Id,OrderInputDefinition__c>([
            SELECT
                Id,
                Id__c,
                InputDomain__c,
                (
                    SELECT
                        Id,
                        Name,
                        ReferencedField__c,
                        Type__c,
                        Operator__c,
                        ValueToMatch__c
                    FROM
                        Constraints__r
                ),
                (
                    SELECT Id, Operator__c FROM ConstraintGroups__r
                )
            FROM
                OrderInputDefinition__c
            WHERE
                Id IN :orderInputDefinitionIds
        ]);

        Set<Id> lsetConstraintGroupIds = new Set<Id>();

        // Collect one more level: The linked Constraints for the found ConstraintGroups
        if (!mapConstraintsToOrderInputDefinitionValueIdTmp.isEmpty()) {

            for (OrderInputDefinition__c oOrderInputDefinition : mapConstraintsToOrderInputDefinitionValueIdTmp.values()) {

                // Add to constraint map
                OrderInputDefinitionConstraint oOrderInputDefinitionConstraint = new OrderInputDefinitionConstraint(oOrderInputDefinition);
                this.constraintsToOrderInputDefinitionValueId.put(oOrderInputDefinition.Id, oOrderInputDefinitionConstraint);

                if (!oOrderInputDefinition.Constraints__r.isEmpty()) {
                    oOrderInputDefinitionConstraint.addConstraints(oOrderInputDefinition.Constraints__r);
                }

                if (!oOrderInputDefinition.ConstraintGroups__r.isEmpty()) {
                    for (ConstraintGroup__c oConstraintGroup : oOrderInputDefinition.ConstraintGroups__r) {
                        oOrderInputDefinitionConstraint.addConstraintGroups(oOrderInputDefinition.ConstraintGroups__r);
                        lsetConstraintGroupIds.add(oConstraintGroup.Id);
                    }
                }
            }
        }

        Integer iMaxLevel = 1; // 0 means only Constraints will be taken into account no Constraints of ConstraintGroups

        // Resolve ConstraintGroups with maxLevel
        if (!lsetConstraintGroupIds.isEmpty() && iMaxLevel > 0) {

            this.initConstraintGroups(lsetConstraintGroupIds, iMaxLevel);

            for (OrderInputDefinitionConstraint oOrderInputDefinitionConstraint : this.constraintsToOrderInputDefinitionValueId.values()) {
                oOrderInputDefinitionConstraint.initNestedConstraintGroups(this.constraintGroupsByIds);
            }
        }
    }

    /**
     *
     *
     * @param orderInputDefinitionId
     * @param valueMap
     *
     * @return
     */
    public Boolean checkIfConstraintIsFulfilled(Id orderInputDefinitionId, Map<String,Object> valueMap) {

        String DEBUG_HERE = DEBUG_HEADER + 'checkIfConstraintIsFulfilled() - ';

        if (!this.constraintsToOrderInputDefinitionValueId.containsKey(orderInputDefinitionId)) {
            ConstraintValidator.debugMessages.add(DEBUG_HERE + 'No constraints found for OrderInputDefinition');
            return true;
        }

        ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Check constraints');

        return this.constraintsToOrderInputDefinitionValueId.get(orderInputDefinitionId).fulfilled(valueMap);
    }

    /**
     *
     *
     * @param constraintGroupIds
     * @param maxLevel
     */
    private void initConstraintGroups(Set<Id> constraintGroupIds, Integer maxLevel) {
        this.initConstraintGroups(constraintGroupIds, maxLevel, 1);
    }

    /**
     *
     *
     * @param constraintGroupIds
     * @param maxLevel
     * @param currentLevel
     */
    private void initConstraintGroups(Set<Id> constraintGroupIds, Integer maxLevel, Integer currentLevel) {

        Map<Id,ConstraintGroup__c> mapConstraintGroupsByIds = new Map<Id,ConstraintGroup__c>([
            SELECT
                Id,
                (
                    SELECT
                        Id,
                        Name,
                        ReferencedField__c,
                        Operator__c,
                        Type__c,
                        ValueToMatch__c,
                        ConstraintGroup__c
                    FROM
                        Constraints__r
                ),
                (
                    SELECT
                        Id,
                        Operator__c
                    FROM
                        ConstraintGroups__r
                )
            FROM
                ConstraintGroup__c
            WHERE
                Id IN :constraintGroupIds
        ]);

        if (!mapConstraintGroupsByIds.isEmpty()) {

            Set<Id> lsetMoreConstraintGroupIds = new Set<Id>();

            for (ConstraintGroup__c oConstraintGroup : mapConstraintGroupsByIds.values()) {

                // constraintGroup -> constraints
                if (!oConstraintGroup.ConstraintGroups__r.isEmpty()) {
                    for (ConstraintGroup__c oConstraintGroup2 : oConstraintGroup.ConstraintGroups__r) {
                        lsetMoreConstraintGroupIds.add(oConstraintGroup2.Id);
                    }
                }
            }

            currentLevel++;

            // Keep SOQL limit in mind!
            if (currentLevel <= maxLevel) {
                this.initConstraintGroups(constraintGroupIds, maxLevel, currentLevel);
            }

            this.constraintGroupsByIds.putAll(mapConstraintGroupsByIds);
        }
    }

    public static String forceEmptyStringOnNull(String value) {
        return value == null ? '' :  value;
    }

    /**
     * Resolve a path in a given String,Object map
     *
     * @param valueMap
     * @param path
     *
     * @return
     */
    public static Object resolvePath(Object mapOrList, String path) {

        List<String> listPathParts = path.split('\\.');
        String sPart = listPathParts.remove(0);

        if (sPart == '') {
            return mapOrList;
        }

        if (mapOrList instanceof List<Object> && sPart.isNumeric()) {

            List<Object> listObjects = (List<Object>)mapOrList;
            Integer iIndex = Integer.valueOf(sPart);

            if (iIndex > listObjects.size()-1) {
                return null;
            }

            return resolvePath(listObjects.get(Integer.valueOf(sPart)), String.join(listPathParts, '.'));
        }
        else if (mapOrList instanceof Map<String,Object>) {

            Map<String,Object> mapObjects = (Map<String,Object>)mapOrList;

            if (mapObjects.containsKey(sPart)) {
                return resolvePath(mapObjects.get(sPart), String.join(listPathParts, '.'));
            }
        }

        return null;
    }

    /**
     * ConstraintGroup
     */
    class ConstraintGroup {

        private final String DEBUG_HEADER_INNER = 'ConstraintGroup.';

        private Id id;
        private String operator;

        private List<Constraint> constraints = new List<Constraint>();
        private List<ConstraintGroup> constraintGroups = new List<ConstraintGroup>();

        public ConstraintGroup(ConstraintGroup__c constraintGroup) {
            this.id       = constraintGroup.Id;
            this.operator = constraintGroup.Operator__c;
        }

        public ConstraintGroup(String operator) {
            this.operator = operator;
        }

        public void addConstraints(List<Constraint__c> constraints) {

            for (Constraint__c oConstraint : constraints) {
                this.constraints.add(new Constraint(oConstraint));
            }
        }


        public void addConstraints(List<Constraint> constraints) {
            this.constraints.addAll(constraints);
        }

        /**
         *
         *
         * @param valueMap
         *
         * @return
         */
        public Boolean evaluate(Map<String,Object> valueMap) {

            String DEBUG_HERE = DEBUG_HEADER_INNER + 'evaluate() - ';

            Boolean bEvaluationResultAll = (this.operator == 'OR') ? false : true;

            if (!this.constraints.isEmpty()) {

                ConstraintValidator.debugMessages.add(DEBUG_HERE + this.constraints.size() + ' ' + this.operator + ' linked constraints:');

                for (Constraint oConstraint : this.constraints) {

                    Boolean bEvaluationResult = oConstraint.evaluate(valueMap);

                    if (this.operator == 'AND') {
                        bEvaluationResultAll = (bEvaluationResultAll && bEvaluationResult);
                    }
                    else if (this.operator == 'OR') {
                        bEvaluationResultAll = (bEvaluationResultAll || bEvaluationResult);
                    }
                }
            }
            else {
                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'No constraints');
            }

            // Check for constraint groups
            if (!this.constraintGroups.isEmpty()) {

                ConstraintValidator.debugMessages.add(DEBUG_HERE + this.constraintGroups.size() + ' ' + this.operator + ' linked constraint groups:');

                for (ConstraintGroup oConstraintGroup : this.constraintGroups) {

                    Boolean bEvaluationResult = oConstraintGroup.evaluate(valueMap);

                    if (this.operator == 'AND') {
                        bEvaluationResultAll = (bEvaluationResultAll && bEvaluationResult);
                    }
                    else if (this.operator == 'OR') {
                        bEvaluationResultAll = (bEvaluationResultAll || bEvaluationResult);
                    }
                }
            }
            else {
                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'No further constraint groups');
            }

            ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Evaluation result: ' + bEvaluationResultAll);

            return bEvaluationResultAll;
        }
    }

    /**
     * Constraint
     */
    class Constraint {

        private final String DEBUG_HEADER_INNER = 'Constraint.';

        private Id id;
        private String referencedField;
        private String operator;
        private String valueToMatch;
        private String type;

        public Constraint(Constraint__c constraint) {

            this.id              = constraint.Id;
            this.referencedField = forceEmptyStringOnNull(constraint.ReferencedField__c);
            this.operator        = forceEmptyStringOnNull(constraint.Operator__c);
            this.valueToMatch    = forceEmptyStringOnNull(constraint.ValueToMatch__c);
            this.type            = forceEmptyStringOnNull(constraint.Type__c);
        }

        public Boolean evaluate(Map<String,Object> valueMap) {

            String DEBUG_HERE = DEBUG_HEADER_INNER + 'evaluate() - ';

            Object oValue = resolvePath(valueMap, this.referencedField);

            Boolean bComparisonResult;

            // Special type to compare values
            if (this.type == 'Number') {
                bComparisonResult = this.compareDecimal(Decimal.valueOf(String.valueOf(oValue)), Decimal.valueOf(this.valueToMatch), this.operator);
            }
            else if (this.type == 'Boolean') {
                bComparisonResult = this.compareBoolean(Boolean.valueOf(String.valueOf(oValue)), Boolean.valueOf(this.valueToMatch), this.operator);
            }
            else {
                // String
                bComparisonResult = this.compareString(String.valueOf(oValue), String.valueOf(this.valueToMatch), this.operator);
            }

            ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Comparison: ' + this.referencedField + ' (value = ' + oValue + ') ' + this.operator + ' ' + this.valueToMatch + ' (' + this.type + '): ' + bComparisonResult);

            return bComparisonResult;
        }

        /**
         * Compare boolean values
         *
         * @param value1
         * @param value2
         * @param operator
         *
         * @return
         */
        private Boolean compareBoolean(Boolean value1, Boolean value2, String operator) {
            if (operator == '==') {
                return (value1 == value2);
            }
            return (value1 != value2);
        }

        /**
         * Compare string values
         *
         * @param value1
         * @param value2
         * @param operator
         *
         * @return
         */
        private Boolean compareString(String value1, String value2, String operator) {

            if (operator == '!=') {
                return (value1 != value2);
            }
            else if (operator == '<') {
                return (value1 < value2);
            }
            else if (operator == '<=') {
                return (value1 <= value2);
            }
            else if (operator == '>') {
                return (value1 > value2);
            }
            else if (operator == '>=') {
                return (value1 >= value2);
            }

            return (value1 == value2);
        }

        /**
         * Compare decimal values
         *
         * @param value1
         * @param value2
         * @param operator
         *
         * @return
         */
        private Boolean compareDecimal(Decimal value1, Decimal value2, String operator) {

            if (operator == '!=') {
                return (value1 != value2);
            }
            else if (operator == '<') {
                return (value1 < value2);
            }
            else if (operator == '<=') {
                return (value1 <= value2);
            }
            else if (operator == '>') {
                return (value1 > value2);
            }
            else if (operator == '>=') {
                return (value1 >= value2);
            }

            return (value1 == value2);
        }
    }

    /**
     * OrderInputDefinitionConstraint
     */
    class OrderInputDefinitionConstraint {

        public final List<String> VALID_LOGICAL_OPERATORS = new List<String>{'AND', 'OR'};

        private final String DEBUG_HEADER = 'OrderInputDefinitionConstraint.';

        private OrderInputDefinition__c orderInputDefinition;
        private List<Constraint> constraints = new List<Constraint>();
        private List<ConstraintGroup> constraintGroups = new List<ConstraintGroup>();

        public OrderInputDefinitionConstraint(OrderInputDefinition__c orderInputDefinition) {
            this.orderInputDefinition = orderInputDefinition;
        }

        public void addConstraints(List<Constraint__c> constraints) {

            for (Constraint__c oConstraint : constraints) {
                this.constraints.add(new Constraint(oConstraint));
            }
        }

        public void addConstraintGroups(List<ConstraintGroup__c> constraintGroups) {

            for (ConstraintGroup__c oConstraintGroup : constraintGroups) {
                this.constraintGroups.add(new ConstraintGroup(oConstraintGroup));
            }
        }

        /**
         * Alias for fulfilled without operator
         *
         * @param valueMap
         *
         * @return
         */
        public Boolean fulfilled(Map<String,Object> valueMap) {
            return this.fulfilled(valueMap, null);
        }

        /**
         * Check if constraints and constraint groups are
         * fulfilled by passing a valuemap which holds the
         * values for the constraint comparisons
         *
         * @param valueMap
         * @param operator
         *
         * @return
         */
        public Boolean fulfilled(Map<String,Object> valueMap, String operator) {

            String DEBUG_HERE = DEBUG_HEADER + 'fulfilled() - ';
            String sOperator = operator == null ? this.VALID_LOGICAL_OPERATORS.get(0) : operator;

            if (!this.VALID_LOGICAL_OPERATORS.contains(sOperator)) {
                throw new ContraintValidatorException('Invalid constraint validator');
            }

            ConstraintValidator.debugMessages.add(DEBUG_HERE + 'FIELD "' + orderInputDefinition.Id__c + '" WITH OPERATOR "' + sOperator + '"');

            Boolean bFulfilled = true;
            Boolean bUsed = false;

            // Check for constraints
            if (!this.constraints.isEmpty()) {

                // Create pseudo constraint group from constraints which are
                // situated directly under OrderInputDefinition
                ConstraintGroup oConstraintGroup = new ConstraintGroup('AND'); // AND is default
                oConstraintGroup.addConstraints(this.constraints);

                bFulfilled = oConstraintGroup.evaluate(valueMap);
                bUsed = true;
            }
            else {
                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'No constraints directly related OrderInputDefinition');
            }

            // Check for constraint groups
            if (!this.constraintGroups.isEmpty()) {

                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Evaluating ' + constraintGroups.size() + ' directly constraint groups related to OrderInputDefinition');

                for (ConstraintGroup oConstraintGroup : this.constraintGroups) {
                    bFulfilled = bFulfilled && oConstraintGroup.evaluate(valueMap);
                }
                bUsed = true;
            }
            else {
                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'No constraint groups directly related to OrderInputDefinition');
            }

            //ConstraintValidator.debugMessages.add(DEBUG_HERE + ' : ' + JSON.serializePretty(valueMap));

            if (bUsed) {
                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Fulfilled: ' + bFulfilled);
            }

            return bFulfilled;
        }

        /**
         * initNestedConstraintGroups
         *
         * @param constraintGroupsByIds
         */
        public void initNestedConstraintGroups(Map<Id,ConstraintGroup__c> constraintGroupsByIds) {

            String DEBUG_HERE = DEBUG_HEADER + 'initNestedConstraintGroups() - ';

            if (!this.constraintGroups.isEmpty()) {

                ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Init constraint groups for "' + this.orderInputDefinition.Id__c);

                for (ConstraintGroup oConstraintGroup : this.constraintGroups) {

                    if (constraintGroupsByIds.containsKey(oConstraintGroup.Id)) {

                        ConstraintGroup__c oConstraintGroupWithConstraints = constraintGroupsByIds.get(oConstraintGroup.Id);

                        if (!oConstraintGroupWithConstraints.Constraints__r.isEmpty()) {
                            ConstraintValidator.debugMessages.add(DEBUG_HERE + 'Operator "' + oConstraintGroup.operator + '" with constraints: ' + oConstraintGroupWithConstraints.Constraints__r);
                            oConstraintGroup.addConstraints(oConstraintGroupWithConstraints.Constraints__r);
                        }
                    }
                    else {
                        ConstraintValidator.debugMessages.add(DEBUG_HERE + 'ConstraintGroup__c for ID  ' + oConstraintGroup.Id + ' not found :(');
                    }
                }
            }
        }
    }

    class ContraintValidatorException extends Exception {}
}