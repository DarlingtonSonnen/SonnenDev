({
	doInit : function(component, event, helper) {
		var action = component.get("c.checkIbanLightning");
        action.setParams({bankDataId: component.get("v.recordId")});
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.resp", response.getReturnValue());
                if (response.getReturnValue().includes("Success")) {
                    helper.showSuccessToast(component, event);
                }
                else if (response.getReturnValue().includes("Error")) {
                    helper.showFailToast(component, event);
                }
            } else {
                helper.showFailToast(component, event);
            }
        });
        
        $A.enqueueAction(action);
	}
})