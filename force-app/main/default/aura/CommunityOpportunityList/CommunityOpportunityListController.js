/************************************************************
 Lightning Controller Details
 Name: CommunityOpportunityListController.js
 Type: Lightning Controller 
 Purpose: Controller for lightning component 
		  CommunityOpportunityList.cmp
 ***********************************************************/
({
    doInit : function(component, event, helper) {
        helper.getOpportunities(component);
        helper.getCommunityOrUserLocale(component);
        //helper.getCommunityOpportunityListLabels(component);
        helper.getOpportunityRejectReasonOptions(component, "InputSelectDynamic");
        //var opts = [
        //    { class: "optionClass", label: "Option1", value: "opt1"},
        //    { class: "optionClass", label: "Option2", value: "opt2" },
        //    { class: "optionClass", label: "Option3", value: "opt3" }
        //];
        //component.find("InputSelectDynamic").set("v.options", opts);
    },
    
    opportunityAcceptButtonClick: function(component, event, helper) {
        var clickedItemRecId = event.target.dataset.recid;
        var clickedItemIndex = event.target.dataset.index;
        console.log('Accepting Oppty ' + clickedItemRecId);
        
        //Calling the Apex Function
        var action = component.get("c.opportunityAccept");
        //Setting the Apex Parameter
        action.setParams({
            oppId : clickedItemRecId
        });
        
        //Setting the Callback
        action.setCallback(this,function(a){
            //get the response state
            var state = a.getState();
            
            //check if result is successfull
            if(state == "SUCCESS"){
                //var result = a.getReturnValue();
                //if(!$A.util.isEmpty(result) && !$A.util.isUndefined(result))
                    //component.set("v.lstOpportunity",result);
                
                var opps = component.get("v.lstOpportunity");
                opps.splice(clickedItemIndex, 1);
                component.set("v.lstOpportunity", opps);
            } else if(state == "ERROR"){
                alert('Error calling server side action CommunityOpportunityListController.opportunityAccept()');
            }
        });
        
        //adds the server-side action to the queue        
        $A.enqueueAction(action);
    },
    
    opportunityRejectButtonClick: function(component, event, helper) {
        var clickedItemRecId = event.target.dataset.recid;
        var clickedItemIndex = event.target.dataset.index;
        var clickedItemName = event.target.dataset.recname;
        console.log('Rejecting Oppty ' + clickedItemRecId + ' at index ' + clickedItemIndex);
                
        component.set("{!v.rejectingOppRecId}", clickedItemRecId);
        component.set("{!v.rejectingOppIndex}", clickedItemIndex);
        component.set("{!v.modalDialogTitle}", "Reject opportunity " + clickedItemRecId);
        helper.showPopupHelper(component, 'modaldialog', 'slds-fade-in-');
		helper.showPopupHelper(component,'backdrop','slds-backdrop--');
        return;
    },
    
    opportunityRejectConfirmedButtonClick: function(component, event, helper) {
        
        var clickedItemRecId = component.get("{!v.rejectingOppRecId}");
        var clickedItemIndex = component.get("{!v.rejectingOppIndex}");
        var rejectReason = component.find("InputSelectDynamic").get("v.value");
        
        //Calling the Apex Function
        var action = component.get("c.opportunityReject");
        //Setting the Apex Parameter
        action.setParams({
            oppId : clickedItemRecId,
            rejectReason: rejectReason
        });

        //Setting the Callback
        action.setCallback(this,function(a){
            //get the response state
            var state = a.getState();
            
            //check if result is successfull
            if(state == "SUCCESS"){
                //var result = a.getReturnValue();
                //if(!$A.util.isEmpty(result) && !$A.util.isUndefined(result))
                    //component.set("v.lstOpportunity",result);
                
                var opps = component.get("v.lstOpportunity");
                //opps[clickedItemIndex].stage = "notSold";
                opps.splice(clickedItemIndex, 1);
                component.set("v.lstOpportunity", opps);
                helper.hidePopupHelper(component, 'modaldialog', 'slds-fade-in-');
                helper.hidePopupHelper(component, 'backdrop', 'slds-backdrop--');
            } else if(state == "ERROR"){
                alert('Error calling server side action CommunityOpportunityListController.opportunityReject()');
            }
        });
        
        //adds the server-side action to the queue        
        $A.enqueueAction(action);
    },
    
    onShowPopupClick: function(component, event, helper) {
      helper.showPopupHelper(component, 'modaldialog', 'slds-fade-in-');
		helper.showPopupHelper(component,'backdrop','slds-backdrop--');
    },
    
    onHidePopupClick: function(component, event, helper) {
    	helper.hidePopupHelper(component, 'modaldialog', 'slds-fade-in-');
		helper.hidePopupHelper(component, 'backdrop', 'slds-backdrop--');
    }
})