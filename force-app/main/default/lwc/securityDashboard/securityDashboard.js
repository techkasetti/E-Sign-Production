// File: securityDashboard.js
import { LightningElement, track, wire } from 'lwc';
import getDashboardData from '@salesforce/apex/SecurityDashboardController.getDashboardData';
import { refreshApex } from '@salesforce/apex';

const COLS = [
    { label: 'Signer Name', fieldName: 'SignerName__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text', initialWidth: 100 },
    {
        label: 'Fraud Risk', fieldName: 'Fraud_Risk_Level__c', type: 'text', initialWidth: 120,
        cellAttributes: { class: { fieldName: 'riskCellClass' } }
    },
    { label: 'Fraud Details', fieldName: 'Fraud_Analysis_Details__c', type: 'text', wrapText: true },
    {
        label: 'Timestamp', fieldName: 'CreatedDate', type: 'date',
        typeAttributes: {
            year: 'numeric', month: 'short', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit'
        }
    }
];

export default class SecurityDashboard extends LightningElement {
    @track dashboardData = {};
    @track processedEvents = [];
    @track columns = COLS;
    @track isLoading = true;
    @track error;
    wiredDashboardResult;

    @wire(getDashboardData)
    wiredData(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            this.dashboardData = result.data;
            // Process events to add custom styling for the 'CRITICAL' risk level
            this.processedEvents = result.data.recentCriticalEvents.map(event => {
                const riskCellClass = (event.Fraud_Risk_Level__c === 'CRITICAL')
                    ? 'slds-text-color_error slds-text-font_weight-bold'
                    : 'slds-text-color_default';
                return { ...event, riskCellClass };
            });
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.dashboardData = {};
            this.processedEvents = [];
        }
        this.isLoading = false;
    }

    get hasEvents() {
        return this.processedEvents && this.processedEvents.length > 0;
    }

    get errorText() {
        if (this.error) {
            // Safely extract error message
            return this.error.body?.message || 'An unknown error occurred.';
        }
        return '';
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredDashboardResult)
            .finally(() => {
                this.isLoading = false;
            });
    }
}
