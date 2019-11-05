/**
 * Created by m.muchow on 29.01.2019.
 */
({
    createTemplateList : function(cmp, event) {
        let tempList = [];
        let recordId = cmp.get('v.recordId');
        let action = cmp.get('c.getEmailTemplateList');
        action.setParams({recordId: recordId});
        action.setCallback(this, function(list) {
            let state = list.getState();
            if(state === 'SUCCESS') {
                let item = list.getReturnValue();
                item.forEach(function(element) {
                    tempList.push({value: element.Id, label: element.DeveloperName, desc: element.Description, devName: element.DeveloperName, sub: element.Subject});
                });
                cmp.set('v.options', tempList);
            }
        });
        $A.enqueueAction(action);
    },

    onChangeOptions : function(cmp, event) {
        let selectedValue = event.getParam('value');
        let list = cmp.get('v.options');
        if (selectedValue) {
            cmp.set('v.selected', true);
        }
        cmp.set('v.tempDesc', list.find(tempId => tempId.value === selectedValue).desc);
        cmp.set('v.tempSub', list.find(tempId => tempId.value === selectedValue).sub);
        cmp.set('v.tempDevName', list.find(tempId => tempId.value === selectedValue).devName);
    },

    onChangeCustMetaMap : function(cmp, event) {
        let recordId = cmp.get('v.recordId');
        let action = cmp.get('c.getObjectQueryMap');
        action.setParams({recordId: recordId});
        action.setCallback(this, function(map) {
            let state = map.getState();
            if(state === 'SUCCESS') {
                cmp.set('v.metaMap', map.getReturnValue());
            }
        });
        $A.enqueueAction(action);
    },

    sendEmailHelper : function(cmp, event, helper) {
        let spinner = cmp.find("busySpinner");
        $A.util.toggleClass(spinner, "slds-hide");
        let recordId = cmp.get('v.recordId');
        let tempDevName = cmp.get('v.tempDevName');
        let action = cmp.get('c.sendEmail');
        action.setParams({recordId: recordId, template: tempDevName});
        action.setCallback(this, function(response) {
            $A.util.toggleClass(spinner, "slds-hide");
            if(response.getState() === 'SUCCESS') {
                this.clearHelper(cmp, event);
                let toastEvent = $A.get('e.force:showToast');
                toastEvent.setParams({
                    'title': 'Success',
                    'message': 'Email was sent successfully.',
                    'type': 'success'
                });
                toastEvent.fire();
            } else {
                let toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    'title': 'Error!',
                    'message': 'Failed to send email.',
                    'type': 'error'
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);
        $A.get('e.force:refreshView').fire();
    },

    clearHelper : function(cmp, event) {
        cmp.find('selectBox').set('v.value', null);
        cmp.set('v.selected', false);
    }
})