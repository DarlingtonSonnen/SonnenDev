({
	getOpportunities : function(component) {
		
        this.enqueueServerActionAndCallback(component, "c.getOpportunityRows", "v.lstOpportunity");
	},
    
    getCommunityOrUserLocale: function(component) {
        
        this.enqueueServerActionAndCallback(component, "c.getUserLocale", "v.userLocale");
    },
    
    getOpportunityRejectReasonOptions: function(component, dropdownId) {
        
        var action = component.get("c.getOpportunityRejectReasonOptions");
        
        //Setting the Callback
        action.setCallback(this,function(a){
            
            //get the response state
            var state = a.getState();
            
            //check if result is successfull
            if(state == "SUCCESS"){
                var result = a.getReturnValue();
                if(!$A.util.isEmpty(result) && !$A.util.isUndefined(result))
                    component.find("InputSelectDynamic").set("v.options", JSON.parse(result));
            } else if(state == "ERROR"){
                console.log('Error in calling server side action' + state);
            }
            
        });
        
        //adds the server-side action to the queue        
        $A.enqueueAction(action);
    },

    getCommunityOpportunityListLabels: function(component) {
        
        this.enqueueServerActionAndCallback(component, "c.getCommunityOpportunityListLabels", "v.labels");
    },
    
    showPopupHelper: function(component, componentId, className) {
        var modal = component.find(componentId);
        $A.util.removeClass(modal, className+'hide');
        $A.util.addClass(modal, className+'open');
    },
    
    hidePopupHelper: function(component, componentId, className){
        var modal = component.find(componentId);
        $A.util.addClass(modal, className+'hide');
        $A.util.removeClass(modal, className+'open');
        //component.set("v.body", "");
    },
    
    enqueueServerActionAndCallback: function(component, controllerActionName, componentAttributeName) {
        
        var action = component.get(controllerActionName);
        
        //Setting the Callback
        action.setCallback(this,function(a){
            
            //get the response state
            var state = a.getState();
            
            //check if result is successfull
            if(state == "SUCCESS"){
                var result = a.getReturnValue();
                if(!$A.util.isEmpty(result) && !$A.util.isUndefined(result))
                    component.set(componentAttributeName, result);
            } else if(state == "ERROR"){
                console.log('Error in calling server side action' + state);
            }
        });
        
        //adds the server-side action to the queue        
        $A.enqueueAction(action);
    }
})