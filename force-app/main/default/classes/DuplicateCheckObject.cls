/* Author: Bartosz Jarmolinski

    UPDATES
    - 25/10/2018 - added language as variable
   	- 18/10/2018 - Added shipping address parameters to opportunity constructor

 */

public with sharing class DuplicateCheckObject {

	public Id recId;
	public String firstName;
	public String lastName;
	public String company;
	public String email;
	public String city;
	public String postCode;
	public String street;
	public String streetNum;
	public String addition;
	public String country;
	public String salutation;
	public String phone;
	public String countryCode;
    public String stateCode;
	public String language;

	public String shippingFirstName;
	public String shippingLastName;
	public String shippingCity;
	public String shippingPostCode;
	public String shippingStreet;
	public String shippingStreetNum;
	public String shippingAddition;
	public String shippingSalutation;
	public String shippingCountryCode;
    public String shippingStateCode;

	public DuplicateCheckObject(Opportunity o) {
		this.salutation = o.Salutation__c;
		this.recId = o.Id;
		this.firstName = o.FirstName__c;
		this.lastName = o.LastName__c;
		this.company = o.Company__c;
		this.email = o.Email__c;
		this.city = o.BillingCity__c;
		this.postCode = o.BillingPostalCode__c;
		this.street = o.BillingStreet__c;
		this.streetNum = o.BillingStreetNo__c;
		this.addition = o.BillingAdditional__c;
		this.country = o.Country__c;
		this.countryCode = o.BillingCountryIsoCode__c;
		this.phone = o.Phone__c;
        this.stateCode = o.BillingState__c;
		this.language = o.Language__c;

		this.shippingFirstName = o.ShippingFirstName__c;
		this.shippingLastName = o.ShippingLastName__c;
		this.shippingCity = o.ShippingCity__c;
		this.shippingPostCode = o.ShippingPostalCode__c;
		this.shippingStreet = o.ShippingStreet__c;
		this.shippingStreetNum = o.ShippingStreetNo__c;
		this.shippingAddition = o.ShippingAdditional__c;
		this.shippingCountryCode = o.shippingCountryIsoCode__c;
		this.shippingSalutation = o.Salutation__c;
        this.shippingStateCode = o.ShippingState__c;

	}

	public DuplicateCheckObject(Asset a) {
		this.salutation = a.INClientSalutation__c;
		this.recId = a.Id;
		this.firstName = a.INClientFirstName__c;
		this.lastName = a.INClientLastName__c;
		this.company = NULL;
		this.email = a.INClientEmail__c;
		this.city = a.INClientCity__c;
		this.postCode = a.INClientZIPCode__c;
		this.street = a.INClientStreet__c;
		this.streetNum = a.INClientAdditionToAddress__c;
		this.country = a.INClientCountry__c;
		this.countryCode = a.Country__c;
		this.phone = a.INClientPhoneNumber__c;
		this.language = a.INClientLanguage__c;
	}

	public DuplicateCheckObject getDuplicateCheckObject() {
		return this;
	}
}