({

    sendEmail : function(component, emailType) {
		var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");

        var action = component.get("c.sendEmail");
        action.setParams({
            recordId : component.get("v.recordId"),
            emailType : emailType
        });

        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if (response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The email has been send successfully.",
                    "type": "success"
                });
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to send email.",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });

        $A.enqueueAction(action);
    }

})