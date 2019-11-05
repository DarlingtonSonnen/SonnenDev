/*
 *
 * @author Polina Drobot <polina.drobot@codeswat.com>
 * @version 1.0.0 - 2017-08-17
 *
 */

({
	init : function(component, event, helper) {

        var action = component.get("c.changeRTFromBusinessToPrivate");

  		component.set('v.result', "Changing Record Type....");

        action.setParams({accId : component.get("v.recordId")});
		
		action.setCallback(this, function(response) {
	        if (response.getState() === "SUCCESS") {
	    		component.set('v.result', "Record Type is successfully changed.");
	    		$A.get('e.force:refreshView').fire();

            } else if (response.getState() === "ERROR") {
	    		component.set('v.result', "Error occured.<br/>" + response.getError()[0].message);
	        }
	    });
		
		$A.enqueueAction(action);
    }
})