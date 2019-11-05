/**
 * Created by a.romero on 11/09/2019.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import ACCOUNT_FIELD from '@salesforce/schema/Case.AccountId';
import getContracts from '@salesforce/apex/showAllContractsCtrl.getContracts';


const columns = [
    { label: 'Number', fieldName: 'ContractNumber', type:'string' },
    { label: 'Record Type', fieldName: 'ContractRecord', type: 'string' },
    { label: 'Status', fieldName: 'ContractStatus', type: 'string' },
];

const fields = ACCOUNT_FIELD;

export default class ShowAllContractsLwc extends LightningElement {
    @api recordId;
    @track record;
    @track dataContracts = [];
    @track columns = columns;
    @track noAccount;
    @track spinner = false;

    @wire(getRecord, { recordId: '$recordId', fields })
    wiredAccount({ error, data }) {
        if (data) {
            this.handleLoad(data);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.record = undefined;
        }
    }

    handleLoad(data){
        this.spinner = !this.spinner;
        this.record=data;
        if (this.record.fields.AccountId.value) {
            this.noAccount = false;
            getContracts({accountId:this.record.fields.AccountId.value})
            .then(result=>{

                //this.dataContracts=result;
                let dataC = [];
                result.forEach(element=>{

                     dataC.push({ContractNumber:element.ContractNumber, ContractRecord :element.RecordType.Name, ContractStatus: element.Status});
                     })

                     this.dataContracts=dataC;
                    this.spinner = !this.spinner;
                })
                 .catch(error=>{
                    
                     this.error=error;
                     //this.spinner = !this.spinner;
                 })
        } else{
            this.noAccount = true;
            this.spinner = !this.spinner;
        }
        
    }
}