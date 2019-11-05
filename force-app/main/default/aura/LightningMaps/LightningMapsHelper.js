/**
 * @author Florian Gümbel <florian@die-interaktiven.de>
 */
({
	/**
	 * Create a serialized and base64 encoded Google Maps Icon Object.
	 * Requests the user supplied URL and tries to get the image dimensions.
	 * Adds anchor array if provided.
	 *
	 * @param      {Object}   component  The main component
	 * @return     {Promise}  The marker.
	 */
	buildMarker : function(component) {

		// make it chainable through promise chain
		var promise = new Promise(function(resolve, reject) {
			// get the attributes value
			var markerURL = component.get('v.markerImage');

			// check if user enabled 'useMarkerImage' checkbox
			// If not, stop an resolve an empty string.
			if(!component.get('v.useMarkerImage') || markerURL.length === 0) {
				return resolve('');
			}

			// create new Image object
			var image = new Image(markerURL);

			// set src
			image.src = markerURL;

			// add an onload event listener to exec function after image has load.
			// (Main reason why we're using promises!)
			image.addEventListener('load', function() {

				// the marker object thats being serialized
				var marker = {
					url: markerURL,
					size: [this.naturalWidth, this.naturalHeight],
					anchor: [component.get('v.markerImageAnchorX') || 0, component.get('v.markerImageAnchorY') || 0]
				};

				// resolve a b64 and stringified marker object
				return resolve('&marker=' + window.btoa(JSON.stringify(marker)));

			});

			// error event listener
			// should show a toast if an error occurs.
			image.addEventListener('error', function(){
				var errorToast = $A.get("e.force:showToast");
			    errorToast.setParams({
			        'title': 'Invalid URL!',
			        'message': 'The configured marker URL is invalid or the resource is not available!',
			        'type': 'error'
			    });

			    // fire event and resolve empty string
			    errorToast.fire();
			    resolve('');
			});
		});		

		return promise;
	}
})