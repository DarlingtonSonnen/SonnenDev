/**
 * Created by m.muchow on 05.04.2019.
 */

import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ASSET_CAPACITY_FIELD from '@salesforce/schema/Asset.Capacity__c';

const fields = [
                ASSET_CAPACITY_FIELD
               ]

export default class BannerModernizeAssets extends LightningElement {

    @api recordId;
    @track record;
    @track bonus;

    @wire(getRecord, {recordId: '$recordId', fields })
    wiredRecord({ error, data }){
        let cap;
        if (data) {
            this.record = data;
            cap = this.record.fields.Capacity__c.value;
            if (cap <= 5.5) {
                this.bonus = '4.300';
            } else if (cap > 5.5 && cap <= 7.5) {
                this.bonus = '5.250';
            } else if (cap > 7.5 && cap <= 10.5) {
                this.bonus = '6.200';
            } else if (cap > 10.5 && cap <= 12.5) {
                this.bonus = '7.500';
            } else if (cap > 12.5 && cap <= 15) {
                this.bonus = '8.250';
            } else if (cap > 15) {
                this.bonus = '8.500';
            }
        }
    }
}