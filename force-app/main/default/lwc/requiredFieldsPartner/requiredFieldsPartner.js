/**
 * Created by m.muchow on 22.03.2019.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LEAD_AWARENESS_SOURCE_FIELD  from '@salesforce/schema/Lead.AwarenessSource__c';
//import LEAD_NUMBER_OF_RESIDENTS_FIELD from '@salesforce/schema/Lead.NumberOfResidents__c';
//import LEAD_ENERGY_CONSUMPTION_FIELD from '@salesforce/schema/Lead.EnergyConsumption__c';
import LEAD_PHONE_FIELD from '@salesforce/schema/Lead.Phone';
import LEAD_MOBILE_PHONE_FIELD from '@salesforce/schema/Lead.MobilePhone';
import LEAD_SALUTATION_FIELD from '@salesforce/schema/Lead.Salutation';
import LEAD_NAME_FIELD from '@salesforce/schema/Lead.Name';
import LEAD_LAST_NAME_FIELD from '@salesforce/schema/Lead.LastName';
import LEAD_ADDRESS_FIELD from '@salesforce/schema/Lead.Address';
import LEAD_STREET_FIELD from '@salesforce/schema/Lead.Street';
import LEAD_POSTAL_CODE_FIELD from '@salesforce/schema/Lead.PostalCode';
import LEAD_CITY_FIELD from '@salesforce/schema/Lead.City';
import LEAD_COUNTRY_CODE_FIELD from '@salesforce/schema/Lead.CountryCode';
import LEAD_EMAIL_FIELD from '@salesforce/schema/Lead.Email';
//import LEAD_PRODUCT_INTEREST_FIELD from '@salesforce/schema/Lead.ProductInterest__c';
//import LEAD_PURCHASING_TIME_FRAME_FIELD from '@salesforce/schema/Lead.PurchasingTimeframe__c';
//import LEAD_IS_HOME_OWNER_FIELD from '@salesforce/schema/Lead.IsHomeOwner__c';
//import LEAD_HAS_PV_PLANT_FIELD from '@salesforce/schema/Lead.HasPvPlant__c';
//import LEAD_PV_PLANT_INSTALLATION_DATE_FIELD from '@salesforce/schema/Lead.PvPlantInstallationDate__c';
//import LEAD_POWER_PV_PLANT_FIELD from '@salesforce/schema/Lead.PowerPvPlant__c';
//import LEAD_MOTIVATION_FIELD from '@salesforce/schema/Lead.Motivation__c';
//import LEAD_OTHER_OFFERS_AVAILABLE_FIELD from '@salesforce/schema/Lead.OtherOffersAvailable__c';
//import LEAD_OTHER_OFFERS_DETAILS_FIELD from '@salesforce/schema/Lead.OtherOffersDetails__c';
import LEAD_COMPANY_FIELD from '@salesforce/schema/Lead.Company';

const fields = [LEAD_AWARENESS_SOURCE_FIELD,
                //LEAD_NUMBER_OF_RESIDENTS_FIELD,
                //LEAD_ENERGY_CONSUMPTION_FIELD,
                LEAD_PHONE_FIELD,
                LEAD_MOBILE_PHONE_FIELD,
                LEAD_SALUTATION_FIELD,
                LEAD_NAME_FIELD,
                LEAD_LAST_NAME_FIELD,
                LEAD_STREET_FIELD,
                LEAD_POSTAL_CODE_FIELD,
                LEAD_CITY_FIELD,
                LEAD_COUNTRY_CODE_FIELD,
                LEAD_EMAIL_FIELD,
                //LEAD_PRODUCT_INTEREST_FIELD,
                //LEAD_PURCHASING_TIME_FRAME_FIELD,
                //LEAD_IS_HOME_OWNER_FIELD,
                //LEAD_HAS_PV_PLANT_FIELD,
                //LEAD_PV_PLANT_INSTALLATION_DATE_FIELD,
                //LEAD_POWER_PV_PLANT_FIELD,
                //LEAD_MOTIVATION_FIELD,
                //LEAD_OTHER_OFFERS_AVAILABLE_FIELD,
                //LEAD_OTHER_OFFERS_DETAILS_FIELD
                LEAD_COMPANY_FIELD
               ]

export default class RequiredFieldsLwc extends LightningElement {

    awarenessSource = LEAD_AWARENESS_SOURCE_FIELD;
    //numberOfResidents = LEAD_NUMBER_OF_RESIDENTS_FIELD;
    //energyConsumption = LEAD_ENERGY_CONSUMPTION_FIELD;
    phone = LEAD_PHONE_FIELD;
    mobilePhone = LEAD_MOBILE_PHONE_FIELD;
    salutation = LEAD_SALUTATION_FIELD;
    name = LEAD_NAME_FIELD;
    lastName = LEAD_LAST_NAME_FIELD;
    address = LEAD_ADDRESS_FIELD;
    street = LEAD_STREET_FIELD;
    postalCode = LEAD_POSTAL_CODE_FIELD;
    city = LEAD_CITY_FIELD;
    countryCode = LEAD_COUNTRY_CODE_FIELD;
    email = LEAD_EMAIL_FIELD;
    //productInterest = LEAD_PRODUCT_INTEREST_FIELD;
    //purchasingTimeFrame = LEAD_PURCHASING_TIME_FRAME_FIELD;
    //isHomeOwner = LEAD_IS_HOME_OWNER_FIELD;
    //hasPvPlant = LEAD_HAS_PV_PLANT_FIELD;
    //pvPlantInstallationDate = LEAD_PV_PLANT_INSTALLATION_DATE_FIELD;
    //powerPvPlant = LEAD_POWER_PV_PLANT_FIELD;
    //motivation = LEAD_MOTIVATION_FIELD;
    //otherOffersAvailable = LEAD_OTHER_OFFERS_AVAILABLE_FIELD;
    //otherOffersDetails = LEAD_OTHER_OFFERS_DETAILS_FIELD;
    company = LEAD_COMPANY_FIELD;

    @api recordId;
    @api objectApiName;
    @track spinner = false;
    //@track hasPvPlantSwitch = false;
    //@track otherOffersAvailableSwitch = false;
    //@track init = 'init';

    @wire(getRecord, { recordId: '$recordId', fields })
    record;

/*
    renderedCallback() {
        this.hasPvPlantSwitchStart(this.init);
        this.otherOffersAvailableSwitchStart(this.init);
    }
*/
    handleSpinner() {
        this.spinner = !this.spinner;
    }

    handleSuccess() {
        this.spinner = !this.spinner;
        const toastEvent = new ShowToastEvent({
                        title: 'Success',
                        message: 'Lead was saved successfully!',
                        variant: 'success',});
        this.dispatchEvent(toastEvent);
    }

    handleError() {
        this.spinner = !this.spinner;
        const toastEvent = new ShowToastEvent({
                        title: 'Error',
                        message: 'Lead was not saved successfully!',
                        variant: 'error',});
        this.dispatchEvent(toastEvent);
    }

    get switchField() {
        const switchArray =
            {
                awarenessSource: getFieldValue(this.record.data, LEAD_AWARENESS_SOURCE_FIELD),
                //consumption: this.consumptionSwitch(),
                phone: this.phoneSwitch(),
                salutation: getFieldValue(this.record.data, LEAD_SALUTATION_FIELD),
                lastName: getFieldValue(this.record.data, LEAD_LAST_NAME_FIELD),
                address: this.addressSwitch(),
                street: getFieldValue(this.record.data, LEAD_STREET_FIELD),
                postalCode: getFieldValue(this.record.data, LEAD_POSTAL_CODE_FIELD),
                city: getFieldValue(this.record.data, LEAD_CITY_FIELD),
                countryCode: getFieldValue(this.record.data, LEAD_COUNTRY_CODE_FIELD),
                email: getFieldValue(this.record.data, LEAD_EMAIL_FIELD),
                //productInterest: getFieldValue(this.record.data, LEAD_PRODUCT_INTEREST_FIELD),
                //purchasingTimeFrame: getFieldValue(this.record.data, LEAD_PURCHASING_TIME_FRAME_FIELD),
                //isHomeOwner: getFieldValue(this.record.data, LEAD_IS_HOME_OWNER_FIELD),
                //hasPvPlant: this.hasPvPlantAllSwitch(),
                //pvPlantInstallationDate: this.hasPvPlantAllSwitch(),
                //powerPvPlant: this.hasPvPlantAllSwitch(),
                //motivation: getFieldValue(this.record.data, LEAD_MOTIVATION_FIELD),
                //otherOffersAvailable: this.otherOfferDetailsSwitch(),
                //otherOffersDetails: this.otherOfferDetailsSwitch()
                company: getFieldValue(this.record.data, LEAD_COMPANY_FIELD)
            };
        return switchArray;
    }
/*
    consumptionSwitch() {
        let conSwitch;
        if (!getFieldValue(this.record.data, LEAD_NUMBER_OF_RESIDENTS_FIELD) &&
           (!getFieldValue(this.record.data, LEAD_ENERGY_CONSUMPTION_FIELD) ||
            getFieldValue(this.record.data, LEAD_ENERGY_CONSUMPTION_FIELD) == 0)) {
                conSwitch = false;
        } else {
            conSwitch = true;
        }
        return conSwitch;
    }
*/
    phoneSwitch() {
        let phoSwitch;
        if (!getFieldValue(this.record.data, LEAD_PHONE_FIELD) &&
            !getFieldValue(this.record.data, LEAD_MOBILE_PHONE_FIELD)) {
                phoSwitch = false;
        } else {
            phoSwitch = true;
        }
        return phoSwitch;
    }

    addressSwitch() {
        let addSwitch;
        if (!getFieldValue(this.record.data, LEAD_COUNTRY_CODE_FIELD) ||
            !getFieldValue(this.record.data, LEAD_STREET_FIELD) ||
            !getFieldValue(this.record.data, LEAD_POSTAL_CODE_FIELD) ||
            !getFieldValue(this.record.data, LEAD_CITY_FIELD)) {
                addSwitch = false;
            } else {
                addSwitch = true;
            }
        return addSwitch;
    }
/*
    hasPvPlantAllSwitch() {
        let pvPlantSwitch;
        if ((getFieldValue(this.record.data, LEAD_HAS_PV_PLANT_FIELD) == 'Yes') &&
            (!getFieldValue(this.record.data, LEAD_PV_PLANT_INSTALLATION_DATE_FIELD) ||
            !getFieldValue(this.record.data, LEAD_POWER_PV_PLANT_FIELD))) {
                pvPlantSwitch = false;
            } else if ((getFieldValue(this.record.data, LEAD_HAS_PV_PLANT_FIELD) == 'Yes') &&
                        getFieldValue(this.record.data, LEAD_PV_PLANT_INSTALLATION_DATE_FIELD) &&
                        getFieldValue(this.record.data, LEAD_POWER_PV_PLANT_FIELD)) {
                pvPlantSwitch = true;
            } else if (getFieldValue(this.record.data, LEAD_HAS_PV_PLANT_FIELD)) {
                pvPlantSwitch = true;
            } else {
                pvPlantSwitch = false;
            }
        return pvPlantSwitch;
    }

    otherOfferDetailsSwitch() {
        let offerSwitch;
        if ((getFieldValue(this.record.data, LEAD_OTHER_OFFERS_AVAILABLE_FIELD) == 'Yes') &&
            !getFieldValue(this.record.data, LEAD_OTHER_OFFERS_DETAILS_FIELD)) {
                offerSwitch = false;
            } else if ((getFieldValue(this.record.data, LEAD_OTHER_OFFERS_AVAILABLE_FIELD) == 'Yes') &&
                        getFieldValue(this.record.data, LEAD_OTHER_OFFERS_DETAILS_FIELD)) {
                offerSwitch = true;
            } else if (getFieldValue(this.record.data, LEAD_OTHER_OFFERS_AVAILABLE_FIELD)) {
                offerSwitch = true;
            } else {
                offerSwitch = false;
            }
        return offerSwitch;
    }
*/
    get visibleSwitch() {
        let visSwitch;
             if (getFieldValue(this.record.data, LEAD_AWARENESS_SOURCE_FIELD) &&
                 getFieldValue(this.record.data, LEAD_SALUTATION_FIELD) &&
                 getFieldValue(this.record.data, LEAD_LAST_NAME_FIELD) &&
                 getFieldValue(this.record.data, LEAD_EMAIL_FIELD) &&
                 //getFieldValue(this.record.data, LEAD_PRODUCT_INTEREST_FIELD) &&
                 //getFieldValue(this.record.data, LEAD_PURCHASING_TIME_FRAME_FIELD) &&
                 //getFieldValue(this.record.data, LEAD_IS_HOME_OWNER_FIELD) &&
                 //getFieldValue(this.record.data, LEAD_HAS_PV_PLANT_FIELD) &&
                 //getFieldValue(this.record.data, LEAD_MOTIVATION_FIELD) &&
                 //getFieldValue(this.record.data, LEAD_OTHER_OFFERS_AVAILABLE_FIELD) &&
                 getFieldValue(this.record.data, LEAD_COMPANY_FIELD) &&
                 //this.consumptionSwitch() &&
                 this.phoneSwitch() &&
                 //this.hasPvPlantAllSwitch() && this.otherOfferDetailsSwitch() &&
                 this.addressSwitch()) {
                    visSwitch = true;
                 } else {
                    visSwitch = false;
                 }
        return visSwitch;
    }

/*
    hasPvPlantChange(event) {
        if (event.target.value == 'Yes') {
            this.init = '';
            this.hasPvPlantSwitchStart('change_Yes');
        } else {
            this.init = '';
            this.hasPvPlantSwitchStart('change_Else');
        }
    }

    hasPvPlantSwitchStart(event) {
        if (event == 'change_Yes') {
            this.hasPvPlantSwitch = true;
        } else if (event == 'change_Else') {
            this.hasPvPlantSwitch = false;
        } else if (event == 'init') {
            if (this.hasPvPlantAllSwitch) {
               this.hasPvPlantSwitch = true;
            }
        }
    }

    otherOffersAvailableChange(event) {
        if (event.target.value == 'Yes') {
            this.init = '';
            this.otherOffersAvailableSwitchStart('change_Yes');
        } else {
            this.init = '';
            this.otherOffersAvailableSwitchStart('change_Else');
        }
    }

    otherOffersAvailableSwitchStart(event) {
        if (event == 'change_Yes') {
            this.otherOffersAvailableSwitch = true;
        } else if (event == 'change_Else') {
            this.otherOffersAvailableSwitch = false;
        } else if (event == 'init') {
            if (this.otherOfferDetailsSwitch) {
               this.otherOffersAvailableSwitch = true;
            }
        }
    }
*/
}