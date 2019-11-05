/**
 * Created by m.muchow on 28.08.2019.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getUserPermission from '@salesforce/apex/EscalateCaseController.getUserPermission';

import Id from '@salesforce/user/Id';

import CASE_ESCALATE_FIELD from '@salesforce/schema/Case.IsEscalated';
import CASE_ESCALATE_HIDDEN_FIELD from '@salesforce/schema/Case.EscalatedHidden__c';
import CASE_INCIDENT_REPORTED_FIELD from '@salesforce/schema/Case.IncidentReportedBy__c';
import CASE_DAMAGE_LOSS_FIELD from '@salesforce/schema/Case.HighDamageLossExpected__c';
import CASE_EXPOSURE_MEASURES_FIELD from '@salesforce/schema/Case.ExposureMeasuresConsumerProtection__c';

const fields = [CASE_ESCALATE_FIELD,
                CASE_ESCALATE_HIDDEN_FIELD,
                CASE_INCIDENT_REPORTED_FIELD,
                CASE_DAMAGE_LOSS_FIELD,
                CASE_EXPOSURE_MEASURES_FIELD]

export default class EscalateCaseModal extends LightningElement {

    escalate = CASE_ESCALATE_FIELD;
    escalatedHidden = CASE_ESCALATE_HIDDEN_FIELD;
    incident = CASE_INCIDENT_REPORTED_FIELD;
    damage = CASE_DAMAGE_LOSS_FIELD;
    exposure = CASE_EXPOSURE_MEASURES_FIELD;

    currentUserId = Id;

    @api recordId;
    @api objectApiName;

    @track record;
    @track error;

    @track submitCheck;
    @track spinner = false;
    @track showEscalateModal = false;
    @track isEscalated = false;
    @track isTeamLead = false;
    @track openModalLabel = 'Escalate Case';
    @track escalateHeader = 'Escalate Case';
    @track hasPermission;
    @track isDeescalated = false;
    @track deescalateHelper = false;

    @wire (getRecord, { recordId: '$recordId', fields })
        wiredRecord({error, data}) {
            if (data) {
                this.error = undefined;
                this.handleLoad();
                this.checkEscalateStatus(data);
                this.checkDeescalateStatus(data);
            }
        };

    handleLoad() {
        getUserPermission({ userId: this.currentUserId })
            .then(result => {
                if (result === false) {
                    this.hasPermission = false;
                } else if (result === true) {
                    this.hasPermission = true;
                }
            })
            .catch(error => {
            })
    }

    checkEscalateStatus(data) {
        this.record = data;
        if (this.record.fields.EscalatedHidden__c.value === true) {
            this.isEscalated = true;
            this.openModalLabel = 'Show Escalation Values';
            this.escalateHeader = 'Escalated Case Values';
        }
    };

    checkDeescalateStatus(data) {
        this.record = data;
        if (this.record.fields.IncidentReportedBy__c.value && this.record.fields.HighDamageLossExpected__c.value && this.record.fields.ExposureMeasuresConsumerProtection__c.value) {
            if (this.record.fields.EscalatedHidden__c.value === false) {
                this.isDeescalated = true;
            }
        }
    };

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        console.log('fields '+JSON.stringify(fields));
        fields.IsEscalated = true;
        fields.EscalatedHidden__c = true;
        let allEmpty = false;
        Array.from(this.template.querySelectorAll('.inputForm')).forEach(element => {
            if (!element.value) {
                allEmpty = true;
            }
        });
        if (allEmpty === false) {
            this.spinner = !this.spinner;
            this.template.querySelector('lightning-record-edit-form').submit(fields);
            this.submitCheck = false;
        } else if (allEmpty === true) {
            this.submitCheck = true;
        }
    };

    handleDeescalate(event) {
        const resetFields = {"IsEscalated":false};
        this.spinner = !this.spinner;
        this.template.querySelector('lightning-record-edit-form').submit(resetFields);
        this.isEscalated = false;
    };

    handleSuccess() {
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message: 'Case was escalated/updated successfully!',
            variant: 'success',
        });
        this.dispatchEvent(toastEvent);
        this.spinner = !this.spinner;
        this.showEscalateModal = false;
        this.dispatchEvent(new CustomEvent('recordChange'));
    };

    handleError() {
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message: 'Something went wrong!',
            variant: 'error',
        });
        this.dispatchEvent(toastEvent);
        this.spinner = !this.spinner;
        this.showEscalateModal = false;
    };

    openEscalateModal() {
        this.showEscalateModal = true;
    };

    openDeescalateModal() {
        this.escalateHeader = 'Formerly Escalated Case Values'
        this.deescalateHelper = true;
        this.showEscalateModal = true;
    };

    closeEscalateModal() {
        this.showEscalateModal = false;
        this.deescalateHelper = false;
    };

}