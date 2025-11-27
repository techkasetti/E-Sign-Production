import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getThreatMetrics from '@salesforce/apex/SecurityDashboardController.getThreatMetrics';
import getActiveThreats from '@salesforce/apex/SecurityDashboardController.getActiveThreats';

export default class RealTimeSecurityDashboard extends LightningElement {
    @track averageRiskScore = 0;
    @track suspiciousActivities = 0;
    @track systemHealth = 'HEALTHY';
    @track activeThreats = [];

    wiredMetricsResult;
    wiredThreatsResult;

    @wire(getThreatMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            this.averageRiskScore = result.data.averageRiskScore;
            this.suspiciousActivities = result.data.suspiciousActivities;
            this.systemHealth = result.data.systemHealth;
        } else if (result.error) {
            console.error('Error fetching metrics:', result.error);
        }
    }

    @wire(getActiveThreats)
    wiredThreats(result) {
        this.wiredThreatsResult = result;
        if (result.data) {
            this.activeThreats = result.data.map(threat => ({
                ...threat,
                badgeVariant: threat.threatLevel === 'HIGH' ? 'slds-badge_warning' : 'slds-badge_error'
            }));
        } else if (result.error) {
            console.error('Error fetching threats:', result.error);
        }
    }

    get totalActiveThreats() {
        return this.activeThreats.length;
    }

    get systemHealthStyle() {
        return this.systemHealth === 'HEALTHY' ? 'color: green;' : 'color: red;';
    }

    handleRefresh() {
        refreshApex(this.wiredMetricsResult);
        refreshApex(this.wiredThreatsResult);
    }
}
