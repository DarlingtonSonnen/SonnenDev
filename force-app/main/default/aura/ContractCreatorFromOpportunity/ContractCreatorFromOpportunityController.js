({
    initCmp: function(component, event, helper) {
        helper.initCmp(component);
    },

    refreshCmp: function(component, event, helper) {
        helper.refreshCmp(component);
    },

    createContractAction: function(component, event, helper) {
        helper.saveValues(component, 'createContract');
    },

    saveValuesAction: function(component, event, helper) {
        helper.saveValues(component);
    },

    /**
     * onLookupPreviousContractSearch
     *
     * Callback for Lookup component to trigger search for a previous Contract
     */
    onLookupPreviousContractSearch : function(component, event, helper) {
        const serverSearchAction = component.get('c.search');
        component.find('previousContract').search(serverSearchAction);
    },

    /**
     * onLookupPreviousContractSelection
     *
     * Callback for Lookup component on selection of a previous Contract
     */
    onLookupPreviousContractSelection: function(component, e, helper) {

        const selection = component.get('v.selection');
        const errors = component.get('v.errors');

        if (selection.length) {

            if (errors.length) {
                component.set('v.errors', []);
            }

            /*
            component.set('v.errors', [
                { message: 'You must make a selection before submitting!' }
            ]);
            */
        }
    },

    /**
     * Callback for picklist changes
     *
     * Currently used to switch the display of contract change fields
     */
    onChangePicklist : function(component, event, helper) {

        var controller = component.get('v.apexCtrl'),
        source = event.getSource(),
        value = source.get('v.value'),
        oidId = source.get('v.label'); // happy hack to get the OrderInputDefinition.Id__c :-P

        if (oidId == controller.contractChangeOidReasonId) {
            component.set("v.apexCtrl.isContractChange", value === controller.contractChangeReason);
        }
    }
})