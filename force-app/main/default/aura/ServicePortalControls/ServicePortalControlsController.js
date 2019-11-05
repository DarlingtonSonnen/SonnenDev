({

    doInit : function(component, event, helper) {
        if(event.getParams().changeType === "LOADED") {
            var spinner = component.find("busySpinner");
            $A.util.toggleClass(spinner, "slds-hide");

            var action = component.get("c.getCommunityUser");
            action.setParams({recordId : component.get("v.recordId")});

            action.setCallback(this, function(response) {
                $A.util.toggleClass(spinner, "slds-hide");
                if(response.getState() === "SUCCESS") {
                    var user = response.getReturnValue();
                    console.log(user);
                    if(user) {
                        component.set("v.user", user);
                    }
                }
            });

            $A.enqueueAction(action);
            
            var currentUserAction = component.get("c.getCurrentUser");
            currentUserAction.setCallback(this, function(response) {
                if(response.getState() === "SUCCESS") {
                    var currentUser = response.getReturnValue();
                    component.set("v.currentUser", currentUser);
                }
            });
            $A.enqueueAction(currentUserAction);
            
            var action = component.get("c.getAdminLoginServiceUrl");
        
            action.setCallback(this, function(response) {
                if(response.getState() === "SUCCESS") {
                    var url = response.getReturnValue();
                    component.set("v.hideAdminLogin", !url);
                    component.set("v.adminLoginUrl", url);
                }
            });
            
            $A.enqueueAction(action);
        }
    },

    sendPortalInvitation : function(component, event, helper) {
        helper.sendEmail(component, "invitation_serviceportal");
    },

    sendPasswordReset : function(component, event, helper) {
        helper.sendEmail(component, "resetpassword_serviceportal");
    },

    createUser : function(component, event, helper) {
		var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");

        var action = component.get("c.createCommunityUserService");
        action.setParams({
            recordId : component.get("v.recordId"),
            serviceUser : true
        });
        
        action.setCallback(this, function(response) {
            console.log(response);
            $A.util.toggleClass(spinner, "slds-hide");
            if(response.getState() === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.user", result.user);

                var toastEvent = $A.get("e.force:showToast");
                if(result.error) {
                    toastEvent.setParams({
                        "title": "Error!",
                        "message": "Failed to create User, Error: " + result.error,
                        "type": "error",
                        "mode": "sticky"	
                    });
                } else {
                    toastEvent.setParams({
                        "title": "Success!",
                        "message": "The portal user has been created successfully.",
                        "type": "success"
                    });
                }
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to create User",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });

        $A.enqueueAction(action);
    },

    navigateToUser : function(component, event, helper) {
        var user = component.get("v.user");
        var navToSObjEvt = $A.get("e.force:navigateToSObject");
        navToSObjEvt.setParams({
            recordId: user.Id,
            slideDevName: "detail"
        });
        navToSObjEvt.fire();
    },
    
    openPortalAdminPage : function(component, event, helper) {
        var user = component.get("v.user");
        var url = component.get("v.adminLoginUrl");
        
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": url + user.Id
        });
        urlEvent.fire();
    },
    
    togglePasswordInput : function(component, event, helper) {
        var isPasswordMode = component.get("v.isPasswordMode");
        component.set("v.isPasswordMode", !isPasswordMode);
        console.log(isPasswordMode);
    },
    
    setNewUserPassword : function(component, event, helper) {
		var spinner = component.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
        
        var user = component.get("v.user");
        var password = component.get("v.password");
        
        var action = component.get("c.setUserPassword");
        action.setParams({userId : user.Id, password : password});
        action.setCallback(this, function(response) {
            console.log(response);
            $A.util.toggleClass(spinner, "slds-hide");
            if(response.getState() === "SUCCESS") {
                var result = response.getReturnValue();
                var toastEvent = $A.get("e.force:showToast");
                if(result.error) {
                    toastEvent.setParams({
                        "title": "Error!",
                        "message": "Failed to set password, " + result.error,
                        "type": "error",
                        "mode": "sticky"	
                    });
                } else {
        			component.set("v.isPasswordMode", false);
                    toastEvent.setParams({
                        "title": "Success!",
                        "message": "The password has been changed successfully.",
                        "type": "success"
                    });
                }
                toastEvent.fire();
            } else {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Failed to update password",
                    "type": "error"
                });
                toastEvent.fire();
            }
        });
        
        $A.enqueueAction(action);
    }

})