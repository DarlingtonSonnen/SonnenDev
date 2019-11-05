/*
 * Created by a.romero on 06/08/2019.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

import getClosedStatus from '@salesforce/apex/closeCaseCtrl.getClosedStatus';
import isArticleRelated from '@salesforce/apex/closeCaseCtrl.isArticleRelated';

import CASE_OBJECT from '@salesforce/schema/Case';

import CASE_CATEGORY_FIELD from '@salesforce/schema/Case.Category__c';
import CASE_SUBCATEGORY_FIELD from '@salesforce/schema/Case.Subcategory__c';
import CASE_REPORTINGCATEGORY_FIELD from '@salesforce/schema/Case.ReportingCategory__c';
import CASE_REPORTINGSUBCATEGORY_FIELD from '@salesforce/schema/Case.ReportingSubcategory__c';
import CASE_RECORDTYPE_FIELD from '@salesforce/schema/Case.RecordTypeId';
import CASE_TYPE_FIELD from '@salesforce/schema/Case.Type';

const fields = [CASE_CATEGORY_FIELD,
    CASE_SUBCATEGORY_FIELD,
    CASE_RECORDTYPE_FIELD,
    CASE_REPORTINGCATEGORY_FIELD,
    CASE_REPORTINGSUBCATEGORY_FIELD,
    CASE_TYPE_FIELD
];

let i = 0;
export default class CloseCase extends LightningElement {

    @api recordId;
    @api objectApiName;

    @track technicalRecordTypeId;
    @track technicalRT;
    @track type;
    @track articleRelated;
    @track relatedArticle;
    @track value = '';
    @track chosenStatus;
    @track methodUsed;
    @track statusOptions = [];
    @track typeRequest = false;

    @track rCategoryInput;
    @track rSubcategoryInput;
    @track spinner = false;

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    objectInfo({ error, data }) {

        if (data) {
            const rtis = data.recordTypeInfos;
            this.technicalRecordTypeId = Object.keys(rtis).find(rti => rtis[rti].name === 'Technical Support Case');
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields})
    wiredRecord({ error, data }) {
        if (data) {
            this.error = undefined;
            this.checkRecordType(data);
            this.checkType(data);

        } else if(error){
            this.error = error;
        }
    }

    @wire(getClosedStatus)
    wiredStatusOptions({ error, data }) {
        if (data) {
            //create array with elements which has been retrieved controller
            //here value will be Id and label of combobox will be Name
            for(i=0; i<data.length; i++)  {
                this.statusOptions = [...this.statusOptions ,{value: data[i] , label: data[i]} ];
            }
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }

    // Function to check Record Type
    checkRecordType(data) {

        this.record = data;

        this.type = this.record.fields.Type.value;


        if (this.record.fields.RecordTypeId.value === this.technicalRecordTypeId) {

            this.technicalRT = true;
        } else {

            this.technicalRT = false;
        }
    }

    //function to check type
    checkType(data) {
        this.record = data;
        if (this.record.fields.Type.value === 'Request') {
            this.typeRequest = true;
        } else {
            this.typeRequest = false;
        }
    }


    handleChangeBox(event) {
        this.chosenStatus = event.detail.value;
    }

    handleSubmit(event) {
        event.preventDefault();
        const submitFields = event.detail.fields;
        let allEmpty = false;
        Array.from(this.template.querySelectorAll('.inputForm')).forEach(element => {

            if (!element.value) {
                allEmpty = true;
            }
        });

        isArticleRelated({ caseId: this.recordId })
        .then((result) => {
            this.relatedArticle=result;
            if (allEmpty === false) {
                if (this.relatedArticle === true || this.technicalRT === true || this.chosenStatus !== 'Closed - Done' || this.type ==='Problem') {
                    this.spinner = !this.spinner;
                    this.template.querySelector('lightning-record-edit-form').submit(submitFields);
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Case do not have attached Article',
                            message: event.detail.message,
                            variant: 'error',
                        }), 
                    );
                }
            }else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Required fields are missing',
                        message: event.detail.message,
                        variant: 'error',
                    }),
                );
            }
        }) 
        .catch((error) => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error retrieve relatedArticle in the case',
                    message: event.detail.message,
                    variant: 'error',
                }),
            );
        })

    }

    handleSuccess() {
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message: 'Case was closed successfully!',
            variant: 'success',
        });
        this.dispatchEvent(toastEvent);
        this.spinner = !this.spinner;
        this.dispatchEvent(new CustomEvent('recordChange'));
    }

    handleError(event){
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error closing the case',
                message: event.detail.message,
                variant: 'error',
            }),
        );
    }

    handleChange(event) {
        this.value = event.detail.value;
    }

}