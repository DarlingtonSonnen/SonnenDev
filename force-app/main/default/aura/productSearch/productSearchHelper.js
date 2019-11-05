/**
 * Created by m.muchow on 19.07.2018.
 */
({
    createProductList : function(component, event){
        var opList = [];
        var oldList = [];
        var action = component.get("c.getProductList");
        action.setParams({type : component.get('v.selectedType'), isActive : component.get('v.selectedIsActive'), recordId : component.get('v.recordId')});
        action.setCallback(this, function(list) {
            var state = list.getState();
            if(state === "SUCCESS") {
                var item = list.getReturnValue();
                item.forEach(function(element) {
                    opList.push({value: element.Id, label: element.Name});
                    oldList.push({Id: element.Id, Name: element.Name});
                });
                component.set("v.products", opList);
                component.set('v.oldProducts', oldList);
                if($A.util.isEmpty(opList)) {
                    component.set('v.productPlaceholder', 'No products available');
                    component.set('v.btnDisable', true);
                } else {
                    component.set('v.productPlaceholder', 'Select a product');
                    component.set('v.btnDisable', false);
                }
            }
        });
    $A.enqueueAction(action);
    },

    createTypeList : function(component, event){
        var opList = [];
        var action = component.get("c.getTypeList");
        action.setCallback(this, function(list) {
            var state = list.getState();
            if(state === "SUCCESS") {
                var item = list.getReturnValue();
                item.forEach(function(element) {
                    opList.push({value: element, label: element});
                });
                component.set("v.types", opList);
            }
        });
    $A.enqueueAction(action);
    },

    createActiveList : function(component, event) {
        var opList = [];
        opList.push({value: 'true', label: 'Yes'});
        opList.push({value: '', label: 'No'});
        component.set('v.isActive', opList);
    },

    createUpdateProductList : function(component, event){
        var opList = [];
        var action = component.get("c.getUpdatedProductList");
        var listString = JSON.stringify(component.get('v.oldProducts'));
        action.setParams({recordId : component.get('v.recordId'), productListString : listString});
        action.setCallback(this, function(list) {
            var state = list.getState();
            if(state === "SUCCESS") {
                var item = list.getReturnValue();
                item.forEach(function(element) {
                    opList.push({value: element.Id, label: element.Name});
                });
                component.set("v.products", opList);
            }
        });
        $A.enqueueAction(action);
    },

    createJunction : function(component, event, helper) {
        var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
        var action = component.get('c.createJunction');
        action.setParams({recordId : component.get('v.recordId'), productId : component.get('v.selectedProduct')});
        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                 helper.createUpdateProductList(component, event);
                 var toastEvent = $A.get("e.force:showToast");
                 toastEvent.setParams({
                     "title": "Success!",
                     "message": "The product has been attached successfully.",
                     "type": "success"
                 });
                 $A.get('e.force:refreshView').fire();
                 toastEvent.fire();
            } else {
                 var toastEvent = $A.get("e.force:showToast");
                 toastEvent.setParams({
                     "title": "Error!",
                     "message": "Failed to attach the product.",
                     "type": "error"
                 });
                 toastEvent.fire();
            }
        });
        $A.enqueueAction(action);
    }
})