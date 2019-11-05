/**
 * Created by m.muchow on 05.03.2019.
 */

import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendEmailNoAns from '@salesforce/apex/noAnswerController.sendEmailNoAns';
import sendEmailQualy from '@salesforce/apex/noAnswerController.sendEmailQualy';
import getNoAnswerValue from '@salesforce/apex/noAnswerController.getNoAnswerValue';
import getCustomMetadata from '@salesforce/apex/noAnswerController.getCustomMetadata';
import { refreshApex } from '@salesforce/apex';
import LEAD_TARGET_COUNTRY_FIELD from '@salesforce/schema/Lead.TargetCountry__c';
import LEAD_EMAIL_FIELD from '@salesforce/schema/Lead.Email';

const fields = [LEAD_TARGET_COUNTRY_FIELD,
                LEAD_EMAIL_FIELD];

export default class NoAnswerComponent extends LightningElement {

    targetCountry = LEAD_TARGET_COUNTRY_FIELD;
    email = LEAD_EMAIL_FIELD;

    @api recordId;
    @api objectApiName;
    @track record;
    @track error;
    @track visible = true;
    @track visibleNoAns = true;
    @track visibleQualy = true;
    @track visibleMeta = false;
    @track emailSwitch = false;
    @track spinner = false;
    @track buttonTitleNoAns;
    @track buttonTitleQualy;
    @track errorMeta;
    @track toastMessage;

    wiredLeadResult;

    @wire(getRecord, { recordId: '$recordId', fields })
        wiredRecord({ error, data}){
            if (data) {
                this.record = data;
                this.error = undefined;
                this.handleLoad();
                if (this.record.fields.Email.value) {
                    this.emailSwitch = true;
                } else {
                    this.emailSwitch = false;
                }
            } else if (error) {
                this.error = error;
                this.data = undefined;
                this.handleLoad();
                this.emailSwitch = false;
            }
    };

    renderedCallback() {
        this.handleLoad();
    }

    handleLoad() {
        getCustomMetadata({recordId: this.recordId})
        .then(result => {
            this.visibleMeta = true;
        })
        .catch(error => {
            this.visibleMeta = false;
            this.errorMeta = error;
        })
    }

    @wire(getNoAnswerValue, {recordId: '$recordId'})
    wiredLead(result) {
        this.wiredLeadResult = result;
        if (result.data) {
            switch (result.data) {
                case '1':
                case '1+q':
                    this.buttonTitleNoAns = 'Send First No Answer Email';
                    this.toastMessage = 'Email was successfully sent!';
                break;
                case '2':
                case '2+q':
                    this.buttonTitleNoAns = 'Log No Answer Call in Description';
                    this.toastMessage = 'No Answer Call was successfully logged!';
                break;
                case '3':
                case '3+q':
                    this.buttonTitleNoAns = 'Send Second No Answer Email';
                    this.toastMessage = 'Email was successfully sent!';
                break;
                case '4':
                case '4+q':
                    this.buttonTitleNoAns = 'Log No Answer Call in Description';
                    this.toastMessage = 'No Answer Call was successfully logged!';
                break;
                case '5':
                case '5+q':
                    this.buttonTitleNoAns = 'Send Third No Answer Email';
                    this.toastMessage = 'Email was successfully sent!';
                break;
                default:
                    this.visibleNoAns = false;
            };
            if (result.data == '6+q' || !(result.data.includes('+'))) {
                this.visibleQualy = true;
            } else {
               this.visibleQualy = false;
            }
        }
        if (this.visibleNoAns == false && this.visibleQualy == false) {
            this.visible = false;
        }
    };

    handleButtonClickNoAns() {
        this.spinner = !this.spinner;
        sendEmailNoAns({ recordId: this.recordId, helperValue: this.wiredLeadResult.data })
        .then(() => {
            const toastEvent = new ShowToastEvent({
                title: 'Success',
                message: this.toastMessage,
                variant: 'success',
            });
            this.dispatchEvent(toastEvent);
            this.spinner = !this.spinner;
            this.dispatchEvent(new CustomEvent('recordChange'));
            return refreshApex(this.wiredLeadResult);
        })
        .catch((error) => {
            const toastEvent = new ShowToastEvent({
                title: 'Error',
                message: 'Something went wrong!',
                variant: 'error',
            });
            this.dispatchEvent(toastEvent);
            this.spinner = !this.spinner;
            return refreshApex(this.wiredLeadResult);
        })
    };

    handleButtonClickQualy() {
        this.spinner = !this.spinner;
        sendEmailQualy({ recordId: this.recordId, helperValue: this.wiredLeadResult.data })
        .then(() => {
            const toastEvent = new ShowToastEvent({
                title: 'Success',
                message: 'Email was successfully sent!',
                variant: 'success',
            });
            this.dispatchEvent(toastEvent);
            this.spinner = !this.spinner;
            return refreshApex(this.wiredLeadResult);
        })
        .catch((error) => {
            const toastEvent = new ShowToastEvent({
                title: 'Error',
                message: 'Something went wrong!',
                variant: 'error',
            });
            this.dispatchEvent(toastEvent);
            this.spinner = !this.spinner;
            return refreshApex(this.wiredLeadResult);
        })
    };

    handleSpinner() {
        this.spinner = !this.spinner;
    };

    handleSuccessMeta() {
        this.spinner = !this.spinner;
        const toastEvent = new ShowToastEvent({
                        title: 'Success',
                        message: 'Target Country was saved successfully!',
                        variant: 'success',});
        this.dispatchEvent(toastEvent);
    }

    handleSuccessEmail() {
            this.spinner = !this.spinner;
            const toastEvent = new ShowToastEvent({
                            title: 'Success',
                            message: 'Email was saved successfully!',
                            variant: 'success',});
            this.dispatchEvent(toastEvent);
        }

    handleError() {
        this.spinner = !this.spinner;
        const toastEvent = new ShowToastEvent({
                        title: 'Error',
                        message: 'New Value was not saved successfully!',
                        variant: 'error',});
        this.dispatchEvent(toastEvent);
    }
}