/**
 * Created by m.muchow on 19.07.2018.
 */
({
    doInit : function(component, event, helper) {
        helper.createTypeList(component, event);
        helper.createActiveList(component, event);
    },

    productList : function(component, event, helper) {
        helper.createProductList(component, event);
        component.set('v.filterSelected', true);
    },

    back : function(component, event, helper) {
        component.set('v.filterSelected', false);
    },

    productSelect : function(component, event, helper) {
        helper.createJunction(component, event, helper);
    },

    saveProductValue : function(component, event, helper) {
        var selectedValue = event.getParam('value');
        component.set('v.selectedProduct', selectedValue);
    },

    saveTypeValue : function(component, event, helper) {
        var selectedValue = event.getParam('value');
        component.set('v.selectedType', selectedValue);
      },

    saveIsActiveValue : function(component, event, helper) {
        var selectedValue = event.getParam('value');
        component.set('v.selectedIsActive', selectedValue);
    }
})