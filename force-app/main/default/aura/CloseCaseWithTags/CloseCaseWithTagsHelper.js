({
    initCmp : function(component) {

        component.set("v.cssStyle", "<style>.cuf-scroller-outside {background: rgb(255, 255, 255) !important;}</style>");

        this.setSpinner(component, true);

        var action = component.get("c.initController");
        action.setParams({
            caseId: component.get("v.recordId")
        });
        action.setCallback(this, function(response) {

            if (component.isValid() && response.getState() === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.apexCtrl", result);
                component.set("v.oldStatus", component.get("v.apexCtrl.caseRecord.Status"));
            } else {
                var errors = response.getError();
                if (errors && errors[0] && errors[0].message) {
                    this.showMessage(component, "error", errors[0].message);
                }
            }

            this.setSpinner(component, false);
        });

        $A.enqueueAction(action);
    },

    refreshCmp : function(component) {

        this.setSpinner(component, true);

        var action = component.get("c.refreshController");
        action.setParams({
            ctrlJSON: JSON.stringify(component.get("v.apexCtrl"))
        });
        action.setCallback(this, function(response) {

            if (component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.apexCtrl", response.getReturnValue());
            } else {
                var errors = response.getError();
                if (errors && errors[0] && errors[0].message) {
                    this.showMessage(component, "error", errors[0].message);
                }
            }

            this.setSpinner(component, false);
        });

        $A.enqueueAction(action);
    },

    onStatusChange : function(component) {
        var selected = component.find("status").get("v.value");
        if (selected == component.get("v.apexCtrl.closedDoneStatusName") && !component.get("v.apexCtrl.hasKnowledgeArticlesRelated")) {
            component.set("v.apexCtrl.caseRecord.Status", component.get("v.oldStatus"));
            this.showMessage(component, "error", $A.get("$Label.c.CloseCaseWithTags_NoKnowledgeArticlesRelated"));
        } else {
            component.set("v.oldStatus", component.get("v.apexCtrl.caseRecord.Status"));
        }
    },

    saveData : function(component) {

        this.setSpinner(component, true);

        var action = component.get("c.saveCaseWithTags");
        action.setParams({
            ctrlJSON: JSON.stringify(component.get("v.apexCtrl"))
        });
        action.setCallback(this, function(response) {

            if (component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.apexCtrl", response.getReturnValue());
                this.showMessage(component, "success");
                $A.get('e.force:refreshView').fire();
            } else {
                var errors = response.getError();
                if (errors && errors[0] && errors[0].message) {
                    this.showMessage(component, "error", errors[0].message);
                }
            }

            this.setSpinner(component, false);
        });

        $A.enqueueAction(action);
    },

    showMessage : function(cmp, type, msg) {
        if (type == "success") {
            this.fireToast(cmp, $A.get("$Label.c.CloseCaseWithTags_SuccessMsgTitle"), $A.get("$Label.c.CloseCaseWithTags_SuccessMsgBody"), type);

        } else if (type == "error") {
            this.fireToast(cmp, $A.get("$Label.c.CloseCaseWithTags_ErrorMsgTitle"),  msg, type);
        }
    },

    fireToast : function(cmp, msgTitle, msgText, msgType) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title: msgTitle,
            message: msgText,
            type: msgType
        });
        toastEvent.fire();
    },

    setSpinner : function(cmp, activate) {
        var spinner = cmp.find("spinner");
        if (!activate) {
            $A.util.addClass(spinner, "slds-hide");
        } else {
            $A.util.removeClass(spinner, "slds-hide");
        }
    }
})