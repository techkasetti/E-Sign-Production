import { LightningElement, track, wire } from 'lwc';
import getSecurityDashboardData from '@salesforce/apex/SecurityDashboardController.getSecurityDashboardData';
import { refreshApex } from '@salesforce/apex';

export default class SecurityDashboard extends LightningElement {
    @track dashboardData;
    @track error;
    @track isLoading = true;
    wiredDashboardResult;

    @wire(getSecurityDashboardData)
    wiredData(result) {
        this.isLoading = true;
        this.wiredDashboardResult = result;
        if (result.data) {
            // Process data to add dynamic CSS classes for badges
            let processedThreats = result.data.activeHighRiskThreats.map(threat => {
                let riskClass = 'slds-badge_lightest'; // Default
                if (threat.Fraud_Risk_Level__c === 'CRITICAL') {
                    riskClass = 'slds-badge slds-badge_inverse';
                } else if (threat.Fraud_Risk_Level__c === 'HIGH') {
                    riskClass = 'slds-badge slds-badge_important';
                }
                return { ...threat, riskClass };
            });
            this.dashboardData = { ...result.data, activeHighRiskThreats: processedThreats };
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body ? result.error.body.message : result.error.message;
            this.dashboardData = undefined;
        }
        this.isLoading = false;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredDashboardResult).finally(() => {
            this.isLoading = false;
        });
    }

    get hasActiveThreats() {
        return this.dashboardData && this.dashboardData.activeHighRiskThreats && this.dashboardData.activeHighRiskThreats.length > 0;
    }

    get activeThreatCount() {
        return this.hasActiveThreats ? this.dashboardData.activeHighRiskThreats.length : 0;
    }
}
