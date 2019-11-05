/**
 * Created by m.muchow on 11.06.2019.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import handleStockItemManually from '@salesforce/apex/ConvertStockItemManually.handleStockItemManually';
import checkForComponentSerial from '@salesforce/apex/ConvertStockItemManually.checkForComponentSerial';

import STOCKITEM_OBJECT from '@salesforce/schema/StockItem__c';

import STOCKITEM_RECORDTYPEID_FIELD from '@salesforce/schema/StockItem__c.RecordTypeId';

import STOCKITEM_PAYLOAD_FIELD from '@salesforce/schema/StockItem__c.CommAssistPayLoad__c';

import STOCKITEM_SERIALNUMBER_FIELD from '@salesforce/schema/StockItem__c.SerialNumber__c';
import STOCKITEM_SALUTATION_FIELD from '@salesforce/schema/StockItem__c.INClientSalutation__c';
import STOCKITEM_FIRSTNAME_FIELD from '@salesforce/schema/StockItem__c.FirstName__c';
import STOCKITEM_LASTNAME_FIELD from '@salesforce/schema/StockItem__c.LastName__c';
import STOCKITEM_EMAIL_FIELD from '@salesforce/schema/StockItem__c.ClientEmail__c';
import STOCKITEM_PHONE_FIELD from '@salesforce/schema/StockItem__c.ClientPhoneNumber__c';
import STOCKITEM_STREET_FIELD from '@salesforce/schema/StockItem__c.ClientStreet__c';
import STOCKITEM_POSTAL_FIELD from '@salesforce/schema/StockItem__c.ClientZIPCode__c';
import STOCKITEM_CITY_FIELD from '@salesforce/schema/StockItem__c.ClientCity__c';
import STOCKITEM_COUNTRY_FIELD from '@salesforce/schema/StockItem__c.Country__c';

const fields = [STOCKITEM_PAYLOAD_FIELD,
                STOCKITEM_RECORDTYPEID_FIELD];

export default class ConvertStockItemV2 extends LightningElement {

    serialNumber = STOCKITEM_SERIALNUMBER_FIELD;
    salutation = STOCKITEM_SALUTATION_FIELD;
    firstName = STOCKITEM_FIRSTNAME_FIELD;
    lastName = STOCKITEM_LASTNAME_FIELD;
    email = STOCKITEM_EMAIL_FIELD;
    phone = STOCKITEM_PHONE_FIELD;
    street =STOCKITEM_STREET_FIELD;
    postal =STOCKITEM_POSTAL_FIELD;
    city = STOCKITEM_CITY_FIELD;
    country = STOCKITEM_COUNTRY_FIELD;

    @api recordId;
    @api objectApiName;;
    @track record;
    @track object;
    @track error;
    @track spinner = false;

    @track hasJSON;
    @track isChange;
    @track componentPresent;

    @track showModal = false;

    @track convertedRecordTypeId;

    // Switch already Converted
    @track converted;

    // Switches Group Radio Group
    @track radioCheckInst;
    @track radioCheckNew;
    @track radioCheckType;

    // Switches Group Combobox
    @track comboCheckSlaves;

    // Switches Singles Radio Group
    @track radioCheckSys;
    @track radioCheckSingle;
    @track radioCheckMaster;

    // switches Button
    @track nextBtnCheck;

    // Values Radio Group
    @track valueInst;
    @track valueSys;
    @track valueType;

    // Values Combobox for Input Field generation
    @track valueSlaves;

    // Values Combobox selected
    @track comboValues;

    // Switch Button
    @track convertBtn;
    @track nextBtn;

    // Slave Array
    @track inputSlaveValues = [];

    // Switch Slaves
    @track slaveCheck;

    // Switch Slave Change
    @track slaveChange;

    // Switch change of Old Serial
    @track changeOld;

    // Value of Old Serial
    @track oldSerial;
    @track oldSerialChange;
    @track oldSerialModal;

    // Value of Master Serial if Slave Change
    @track masterSerial;

    // Input Values
    @track salutationInput;
    @track firstNameInput;
    @track lastNameInput;
    @track emailInput;
    @track phoneInput;
    @track streetInput;
    @track postalInput;
    @track cityInput;
    @track countryInput;

    // Switch Submit
    @track submitCheck;

    @wire (getObjectInfo, { objectApiName: STOCKITEM_OBJECT})
        objectInfo({ error, data}) {
            if (data) {
                const rtis = data.recordTypeInfos;
                this.convertedRecordTypeId = Object.keys(rtis).find(rti => rtis[rti].name === 'Converted');
            }
        };

    @wire (getRecord, { recordId: '$recordId', fields })
        wiredRecord({error, data}) {
            if (data) {
                this.error = undefined;
                this.checkRecordType(data);
                this.preFillData(data);
            }
        };

    // Handler Radio Group newOrChangeRadioGroup
    handleRadioInst(event) {
        this.radioCheckInst = true;
        this.radioCheckSys = '';
        this.convertBtn = false;
        this.nextBtn = false;
        this.slaveCheck = false;
        this.valueSlaves = '';
        this.comboValues = null;
        this.valueType = null;
        this.valueSys = null;
        this.nextBtnCheck = false;
        this.template.querySelector('[data-id="cancelBtn"]').disabled = false;
        if (event.detail.value === 'new') {
            this.radioCheckNew = true;
            this.isChange = false;
            this.changeOld = false;
        } else if (event.detail.value === 'change') {
            this.radioCheckNew = false;
            this.isChange = true;
            this.changeOld = true;
        }
    };

    // Handler Radio Group singleOrCascadingRadioGroup
    handleRadioSys(event) {
        this.radioCheckSys = true;
        this.radioCheckType = '';
        this.convertBtn = false;
        this.nextBtn = false;
        this.slaveCheck = false;
        this.valueSlaves = '';
        this.comboValues = null;
        this.valueType = null;
        this.nextBtnCheck = false;
        if (event.detail.value === 'single') {
            this.radioCheckSingle = true;
            this.convertBtn = true;
        } else if (event.detail.value === 'cascading') {
            this.radioCheckSingle = false;
        }
    };

    // Handler Radio Group masterOrSlaveRadioGroup
    handleRadioType(event) {
        this.radioCheckType = true;
        this.convertBtn = false;
        this.nextBtn = false;
        this.slaveCheck = false;
        this.valueSlaves = '';
        this.comboValues = null;
        this.nextBtnCheck = false;
        if (this.hasJSON) {
            this.getMasterSerial();
        }
        if (event.detail.value === 'master' && this.isChange === false && this.radioCheckNew === true) {
            this.radioCheckMaster = true;
        } else if (event.detail.value === 'slave' && this.isChange === false && this.radioCheckNew === true) {
            this.radioCheckMaster = false;
        } else if (this.isChange === true) {
            this.radioCheckMaster = undefined;
            this.slaveChange = true;
            this.slaveCheck = true;
            this.convertBtn = true;
        }
    };

    // Handler Combobox amountOfSlaves
    handleComboSlaves(event, amountOfSlaves, valuesOfSlaves) {
        this.convertBtn = false;
        this.nextBtn = true;
        let values = [];
        let y;
        if (amountOfSlaves === null || amountOfSlaves === undefined) {
            y = parseInt(event.detail.value);
        } else {
            y = amountOfSlaves;
        }
        this.comboCheckSlaves = true;
        for (let x = 1; x <= y; x++) {
            let i = x-1;
            let value = '';
            if (valuesOfSlaves != null) {
                value = valuesOfSlaves[i];
            }
            values.push({ label: 'Serialnumber Slave '+x.toString(), id: x, value: value });
        }
        this.valueSlaves = values;
        this.comboValues = y.toString();
    };

    // Handler Slave Input Fields
    handleNextBtn() {
        let allEmpty = false;
        Array.from(this.template.querySelectorAll('.inputSlave')).forEach(element => {
            if (!element.value) {
                allEmpty = true;
            }
        });

        if(allEmpty === false) {
            let helperSlaveObject = {};
            let helperSlaveArray = [];
            let helperNodesObject = {};
            this.radioCheckType = false;
            Array.from(this.template.querySelectorAll('.inputSlave')).forEach(element => {
                let helperSlaveObject = {};
                helperSlaveObject.role = 'slave';
                helperSlaveObject.serial = parseInt(element.value);
                helperSlaveArray.push(helperSlaveObject);
            });
            helperNodesObject.nodes = helperSlaveArray;
            this.inputSlaveValues = helperNodesObject;
            this.nextBtn = false;
            this.convertBtn = true;
            this.slaveCheck = true;
        } else if (allEmpty === true) {
            this.nextBtnCheck = true;
        };
    };

    // Handle Submit
    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
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
    }

    // Handle Cancel
    handleCancelBtn() {
        this.resetAll();
    }

    // Options Radio Group newOrChangeRadioGroup
    get optionsInst() {
        return [
            { label: 'New Asset', value : 'new' },
            { label: 'Electric Unit Change', value : 'change' }
        ];
    };

    // Options Radio Group singleOrCascadingRadioGroup
    get optionsSys() {
        return [
            { label: 'Single System', value: 'single' },
            { label: 'Cascading System', value: 'cascading' }
        ];
    };

    // Options Radio Group masterOrSlaveRadioGroup
    get optionsType() {
        return [
            { label: 'Master', value: 'master' },
            { label: 'Slave', value: 'slave' }
        ];
    };

    // Options Combobox amountOfSlaves
    get optionsSlaves() {
        let options = [];
        for (let x = 1; x < 9; x++) {
            options.push({ label: x.toString(), value: x.toString() });
        }
        return options;
    };

    // Function to check Record Type
    checkRecordType(data) {
        this.record = data;
        if (this.record.fields.RecordTypeId.value === this.convertedRecordTypeId) {
            this.converted = true;
        } else {
            this.converted = false;
        }
    };

    // Function to pre fill data
    preFillData(data) {
        this.record = data;
        if (this.record.fields.CommAssistPayLoad__c.value) {
            this.hasJSON = true;
            this.radioCheckInst = true;
            this.radioCheckSys = true;
            this.template.querySelector('[data-id="cancelBtn"]').disabled = false;
            if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).IN_riverbox_changed === 'false') {
                this.isChange = false;
                this.radioCheckNew = true;
                this.valueInst = 'new';
                if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade === null) {
                    this.radioCheckSingle = true;
                    this.convertBtn = true;
                    this.valueSys= 'single';
                } else if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade != null) {
                    this.radioCheckSingle = false;
                    this.radioCheckType = true;
                    this.valueSys = 'cascading';
                    if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.role === 'master') {
                        this.radioCheckMaster = true;
                        this.convertBtn = true;
                        this.valueType = 'master';
                        this.calculateSlaves();
                    } else if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.role != 'master') {
                        this.radioCheckMaster = false;
                        this.valueType = 'slave';
                    }
                }
            } else if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).IN_riverbox_changed === 'true') {
                this.isChange = true;
                this.radioCheckNew = false;
                this.valueInst = 'change';
                this.changeOld = true;
                this.oldSerial = JSON.parse(this.record.fields.CommAssistPayLoad__c.value).IN_riverbox_old_serial;
                if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade === null) {
                    this.radioCheckSingle = true;
                    this.convertBtn = true;
                    this.valueSys= 'single';
                } else if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade != null) {
                    this.radioCheckSingle = false;
                    this.radioCheckType = true;
                    this.valueSys = 'cascading';
                    if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.role === 'master') {
                        this.radioCheckMaster = true;
                        this.convertBtn = true;
                        this.valueType = 'master';
                        this.calculateSlaves();
                    } else if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.role != 'master') {
                        this.slaveChange = true;
                        this.slaveCheck = true;
                        this.convertBtn = true;
                        this.valueType = 'slave';
                        this.getMasterSerial();
                    }
                }
            }
        }
    };

    // Function to get Amount and Serialnumber of Slaves from JSON
    calculateSlaves() {
        let slaveSerials = [];
        let nodes = JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.nodes;
        let amountOfSlaves = nodes.length;

        for (let i in nodes) {
            if (nodes.hasOwnProperty(i)) {
                let nodeObject = nodes[i];
                slaveSerials.push(nodeObject.serial);
            }
        }
       this.handleComboSlaves(null, amountOfSlaves, slaveSerials);
    };

    // Function to get Master Serial of Slave Change
    getMasterSerial() {
        if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade != null) {
            if (JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.role != 'master') {
                let nodes = JSON.parse(this.record.fields.CommAssistPayLoad__c.value).pro_cascade.nodes;
                const masterSerialNode = nodes.find(node => node.role === 'master');
                this.masterSerial = masterSerialNode.serial;
                }
        }
    };

    // Function to handle Apex Class
    handleSuccess() {
        if (this.changeOld) {
            if (this.oldSerialChange) {
                this.oldSerialModal = this.oldSerialChange;
            } else {
                this.oldSerialModal = this.oldSerial;
                this.oldSerialChange = this.oldSerial;
            }
            if (this.oldSerial === this.oldSerialChange) {
                this.oldSerialChange = '';
                this.oldSerialModal = this.oldSerial;
            }
        }
        if (!Object.entries(this.inputSlaveValues).length) {
            this.inputSlaveValues = '';
        }
        checkForComponentSerial({ oldSerial: this.oldSerialModal})
        .then (result => {
            this.componentPresent = result;
            if ((this.componentPresent === true && this.changeOld === true) || (this.componentPresent === false && this.changeOld != true)) {
                    handleStockItemManually({ stockItemId: this.recordId, isSingle: this.radioCheckSingle, slaveMap: this.inputSlaveValues, changedOldSerial: this.oldSerialChange})
                        .then (() => {
                            const toastEvent = new ShowToastEvent({
                                title: 'Success',
                                message: 'Stock Item was converted successfully!',
                                variant: 'success',
                            });
                            this.dispatchEvent(toastEvent);
                            this.spinner = !this.spinner;
                            this.dispatchEvent(new CustomEvent('recordChange'));
                        })
                        .catch((error) => {
                            const toastEvent = new ShowToastEvent({
                                title: 'Error',
                                message: 'Something went wrong!',
                                variant: 'error',
                            });
                            this.dispatchEvent(toastEvent);
                            this.spinner = !this.spinner;
                        })
                    } else if (this.componentPresent === false && this.changeOld === true) {
                        this.spinner = !this.spinner;
                        this.openModal();
                    }
        })
        .catch((error) => {
            const toastEvent = new ShowToastEvent({
                title: 'Error',
                message: 'Something went wrong!',
                variant: 'error',
            });
            this.dispatchEvent(toastEvent);
            this.spinner = !this.spinner;
        })
    };

    resetAll() {
        this.template.querySelector('[data-id="cancelBtn"]').disabled = true;
        Array.from(this.template.querySelectorAll('input[type="radio"]:checked'), input => input.checked = false );
        this.radioCheckInst = undefined;
        this.radioCheckNew = undefined;
        this.radioCheckType = undefined;
        this.comboCheckSlaves = undefined;
        this.radioCheckSys = undefined;
        this.radioCheckSingle = undefined;
        this.radioCheckMaster = undefined;
        this.nextBtnCheck = undefined;
        this.valueInst = undefined;
        this.valueSys = undefined;
        this.valueType = undefined;
        this.valueSlaves = undefined;
        this.comboValues = undefined;
        this.convertBtn = undefined;
        this.nextBtn = undefined;
        this.inputSlaveValues = [];
        this.slaveCheck = undefined;
        this.slaveChange = undefined;
        this.changeOld = undefined;
        this.oldSerial = undefined;
        this.masterSerial = undefined;
        this.salutationInput = undefined;
        this.firstNameInput = undefined;
        this.lastNameInput = undefined;
        this.emailInput = undefined;
        this.phoneInput = undefined;
        this.streetInput = undefined;
        this.postalInput = undefined;
        this.cityInput = undefined;
        this.countryInput = undefined;
        this.submitCheck = undefined;
    };

    openModal() {
        this.showModal = true;
    };

    closeModal() {
        this.showModal = false;
    };

    onBlurOldSerial() {
        this.oldSerialChange = this.template.querySelector('.inputFormOld').value;
    }
}