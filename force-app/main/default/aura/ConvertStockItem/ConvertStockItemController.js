({
	doInit : function(component, event, helper) {
		//var siId = component.find("record").get(v.recordId);  
        var action = component.get("c.createAsset");
        action.setParams({stockItemId : component.get("v.recordId")});
        
        
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
		
	}, 
})