/**
 * Created by m.muchow on 12.03.2019.
 */

import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import LEAD_LATITUDE_FIELD from '@salesforce/schema/Lead.Latitude';
import LEAD_LONGITUDE_FIELD from '@salesforce/schema/Lead.Longitude';

const fields = [LEAD_LATITUDE_FIELD, LEAD_LONGITUDE_FIELD];

export default class Leadmap extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields })
    record;

    get mapMarkers() {
           const markers =
               [{
                   location: {
                      'Latitude': getFieldValue(this.record.data, LEAD_LATITUDE_FIELD),
                      'Longitude': getFieldValue(this.record.data, LEAD_LONGITUDE_FIELD)
                   }
               }];
        return markers;
    }
}