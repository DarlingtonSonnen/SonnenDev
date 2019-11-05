({    
    training : function(component, event) {
        var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
       
        var action = component.get("c.concludeTraining");
        action.setParams({recordId : component.get("v.recordId")});

        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The training has been completed successfully.",
                    "type": "success"
                });
                $A.get('e.force:refreshView').fire();
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to complete the training.",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });
        	$A.enqueueAction(action);
        },
        
    generate : function(component, event) {
        var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
       
        var action = component.get("c.createCerts");
        action.setParams({recordId : component.get("v.recordId")});

        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The certificates have been created successfully.",
                    "type": "success"
                });
                $A.get('e.force:refreshView').fire();
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to create the certificates.",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });
        	$A.enqueueAction(action);    
    },

    attList : function(component, event) {
        var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
       
        var action = component.get("c.attendanceList");
        action.setParams({recordId : component.get("v.recordId")});

        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The attendance list was successfully created.",
                    "type": "success"
                });
                $A.get('e.force:refreshView').fire();
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to create the attendance list.",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });
        	$A.enqueueAction(action);    
    },
    
    sendMail : function(component, event) {
        var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
       
        var action = component.get("c.sendCerts");
        action.setParams({recordId : component.get("v.recordId")});

        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "Emails send successfully.",
                    "type": "success"
                });
                $A.get('e.force:refreshView').fire();
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to send emails.",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });
        	$A.enqueueAction(action);    
    },
    
    close:function(component,event,helper){    
		helper.closeModal(component,event);
    },
    
	cancelModal:function(component,event,helper) {
		var cmpTarget = component.find('Modalbox');
		var cmpBack = component.find('Modalbackdrop');
		$A.util.addClass(cmpTarget, 'slds-fade-in-open');
		$A.util.addClass(cmpBack, 'slds-backdrop--open'); 
	},
    
    cancel : function(component, event,helper) {
        var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
              
        var action = component.get("c.cancelTrain");
        action.setParams({recordId : component.get("v.recordId")});
        
        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "Training cancelled successfully.",
                    "type": "success"
                });
                $A.get('e.force:refreshView').fire();
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to cancel training",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });
        helper.closeModal(component,event);
        $A.enqueueAction(action);
    }
})