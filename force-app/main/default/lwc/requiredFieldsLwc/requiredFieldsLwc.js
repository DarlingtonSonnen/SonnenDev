/**
 * Created by m.muchow on 18.03.2019.
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import LEAD_RECORD_TYPE_NAME from '@salesforce/schema/Lead.RecordType.Name';
import LEAD_TARGET_COUNTRY_FIELD from '@salesforce/schema/Lead.TargetCountry__c';
import LEAD_COUNTRY_CODE_FIELD from '@salesforce/schema/Lead.CountryCode';
import LEAD_PRODUCT_INTEREST_FIELD from '@salesforce/schema/Lead.ProductInterest__c';
import LEAD_LEAD_SOURCE_FIELD from '@salesforce/schema/lead.LeadSource';

const fields = [LEAD_RECORD_TYPE_NAME,
                LEAD_TARGET_COUNTRY_FIELD,
                LEAD_COUNTRY_CODE_FIELD,
                LEAD_PRODUCT_INTEREST_FIELD,
                LEAD_LEAD_SOURCE_FIELD];

export default class RequiredFieldsLwc extends LightningElement {

    @api recordId;
    @api objectApiName;

    @track record;
    @track error;

    @track recordTypeNameCustomer = false;
    @track charger = false;
    @track leadPartner = false;
    @track targetCountryDACH;
    @track targetCountryIT;
    @track targetCountryES;
    @track targetCountryAU;
    @track countryCodeUS;

    @wire(getRecord, { recordId: '$recordId', fields })
    wiredRecord({ error, data}){
        if (data) {
            this.record = data;
            this.error = undefined;
            this.checkRecordTypeName(this.record.fields.RecordType.displayValue);
            this.checkTargetCountry(this.record.fields.TargetCountry__c.value);
            this.checkCountry(this.record.fields.CountryCode.value);
            this.checkCharger(this.record.fields.ProductInterest__c.value);
            this.checkLeadSource(this.record.fields.LeadSource.value);
        } else if (error) {
            this.error = error;
            this.record = undefined;
        }
    };

    checkRecordTypeName(fieldValue) {
        if (fieldValue == 'Customer') {
            this.recordTypeNameCustomer = true;
        } else if (fieldValue == 'Partner Acquisition') {
            this.recordTypeNameCustomer = false;
        } else {
            this.recordTypeNameCustomer = undefined;
        }
    }

    checkTargetCountry(fieldValue) {
        switch (fieldValue) {
            case 'DE':
            case 'AT':
            case 'CH':
                this.targetCountryDACH = true;
                this.targetCountryIT = false;
                this.targetCountryES = false;
                this.targetCountryAU = false;
            break;
            case 'IT':
                this.targetCountryIT = true;
                this.targetCountryDACH = false;
                this.targetCountryES = false;
                this.targetCountryAU = false;
            break;
            case 'ES':
                this.targetCountryES = true;
                this.targetCountryDACH = false;
                this.targetCountryIT = false;
                this.targetCountryAU = false;
            break;
            case 'AU':
                this.targetCountryAU = true;
                this.targetCountryDACH = false;
                this.targetCountryIT = false;
                this.targetCountryES = false;
            break;
            default:
                this.targetCountryDACH = false;
                this.targetCountryIT = false;
                this.targetCountryES = false;
                this.targetCountryAU = false;
        }
    }

    checkCountry(fieldValue) {
        if (fieldValue == 'US') {
            this.countryCodeUS = true;
        } else {
            this.countryCodeUS = false;
        }
    }

    checkCharger(fieldValue) {
        if (fieldValue == 'Charger') {
            this.charger = true;
        } else {
            this.charger = false;
        }
    }

    checkLeadSource(fieldValue) {
            if (fieldValue == 'Lead Partner') {
                this.leadPartner = true;
            } else {
                this.leadPartner = false;
            }
        }
}