({
	showSuccessToast : function(component, event) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            message: component.get("v.resp"),
            duration: '5000',
            key:'info_alt',
            type:'success',
            mode: 'pester'
        });
        toastEvent.fire();
        $A.get("e.force:closeQuickAction").fire();
        $A.get("e.force:refreshView").fire();
	},
    
    showFailToast : function(component) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            message: component.get("v.resp"),
            duration: '5000',
            key: 'info_alt',
            type: 'error',
            mode:'pester'
        });
        toastEvent.fire();
        $A.get("e.force:closeQuickAction").fire();
        $A.get("e.force:refreshView").fire();
    }
})