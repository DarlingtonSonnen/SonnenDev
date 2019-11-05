({
	init : function(component, event, helper) {
		
		var frame = component.find('mapFrame'),
			url = component.get('v.visualforcePath') + '/apex/GoogleMapFrame?'
		;

		url += '&id=' + component.get('v.recordId');


		helper
			.buildMarker(component)
			.then(function(addOn) {
				url += addOn;

				return url;
			})
			.then(function(url) {
				
				component.set('v.iframeSource', url);

			})
		;

	},

})