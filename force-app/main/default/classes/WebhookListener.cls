@RestResource(urlMapping='/stripe/webhooks/v1/*')
global class WebhookListener extends StripeWebhookListener {

	@HttpPost
	global static void doPost() {
		WebhookListener listener = new WebhookListener();
		listener.handlePost();
	}

	// SUPPORTED WEBHOOKS
	// These don't need to be implemented here if you're not going to support them

	// Handle the customer.updated webhook
	// Create a new Payment Method when a card changes, and update the license
	public override void handle_CustomerUpdated(StripeCustomer customer) {
		SonnenbatterieWebhookHandlers.processCustomer(customer, 'UPDATED');
	}
    
    public override void handle_CustomerCreated(StripeCustomer customer) {
        SonnenbatterieWebhookHandlers.processCustomer(customer, 'CREATED');
	}
	
	// Handle the charge.succeeded webhook
	// Create the payment record, if it's not already present
	/*public override void handle_ChargeSucceeded(StripeCharge charge) {
		handle_ChargeSucceeded(charge, true);
	}*/

	public override void handle_ChargeSucceeded(StripeCharge charge, Boolean allowDelayedProcessing) {
		SonnenbatterieWebhookHandlers.processCharge(charge, 'SUCCESS');
    }

	// Handle the charge.failed webhook
	// Create the 'failed' payment record, if it's not already present
	public override void handle_ChargeFailed(StripeCharge charge) {
        SonnenbatterieWebhookHandlers.processCharge(charge, 'FAILED');
	}

	// Handle the charge.refunded webhook
	// Update the payment record
	public override void handle_ChargeRefunded(StripeCharge charge) {
        SonnenbatterieWebhookHandlers.processCharge(charge, 'REFUNDED');
	}

	// Handle the invoice.created webhook
	/*
	public override void handle_InvoiceCreated(StripeInvoice invoice) {
		throw new StripeEvent.UnknownWebhookException('Not implemented');
	}
	
	// Handle the invoice.payment_succeeded webhook
	public override void handle_InvoicePaymentSucceeded(StripeInvoice invoice) {
		throw new StripeEvent.UnknownWebhookException('Not implemented');
	}
	
	// Handle the invoice.payment_failed webhook
	public override void handle_InvoicePaymentFailed(StripeInvoice invoice) {
		throw new StripeEvent.UnknownWebhookException('Not implemented');
	}

	// Handle the customer.subscription.deleted webhook
	public override void handle_CustomerSubscriptionDeleted(StripeSubscription subscription) {
		throw new StripeEvent.UnknownWebhookException('Not implemented');
	}*/
	
}