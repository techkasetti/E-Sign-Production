import { LightningElement, wire, track } from 'lwc';
import getThreatMetrics from '@salesforce/apex/SecurityDashboardController.getThreatMetrics';
import getActiveThreats from '@salesforce/apex/SecurityDashboardController.getActiveThreats';
import { refreshApex } from '@salesforce/apex';

// Define the columns for the data table of active threats
const columns = [
    { label: 'Risk Level', fieldName: 'threatLevel', cellAttributes: { iconName: { fieldName: 'iconName' }, iconPosition: 'left', class: { fieldName: 'cellClass' } } },
    { label: 'Score', fieldName: 'riskScore', type: 'number', sortable: true, cellAttributes: { alignment: 'center' } },
    { label: 'Description', fieldName: 'description', type: 'text', wrapText: true },
    { label: 'Activity', fieldName: 'activity', type: 'text' },
    { label: 'User ID', fieldName: 'userId', type: 'text' },
    { label: 'Time', fieldName: 'formattedTimestamp', type: 'text', sortable: true }
];

export default class SecurityDashboard extends LightningElement {
    // Tracked properties to hold data and state
    @track metrics = {};
    @track activeThreats = [];
    @track columns = columns;
    @track error;
    
    // Properties to hold the provisioned data from @wire, needed for refreshApex
    wiredMetricsResult;
    wiredThreatsResult;

    // --- WIRE SERVICE FOR METRICS ---
    @wire(getThreatMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result; // Store the provisioned result
        if (result.data) {
            this.metrics = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            console.error('Error fetching threat metrics:', result.error);
            // Default metrics on error to prevent UI breaking
            this.metrics = {
                averageRiskScore: 0,
                suspiciousActivities: 0,
                activeHighRiskThreats: 0,
                systemHealth: 'ERROR'
            };
        }
    }

    // --- WIRE SERVICE FOR ACTIVE THREATS ---
    // This is the function that was previously crashing the component.
    @wire(getActiveThreats)
    wiredThreats(result) {
        this.wiredThreatsResult = result; // Store the provisioned result
        
        // *** CRITICAL FIX #1: DEFENSIVE NULL CHECK ***
        // We wrap the entire logic in an 'if (result.data)' block.
        // This ensures the code only runs when the Apex call successfully returns data.
        // It prevents the "Cannot read properties of undefined (reading 'length')" error.
        if (result.data) {
            // Map the data to add dynamic styling for the risk level
            this.activeThreats = result.data.map(threat => {
                let iconName = 'utility:info';
                let cellClass = 'slds-text-color_weak';

                if (threat.threatLevel === 'CRITICAL') {
                    iconName = 'utility:error';
                    cellClass = 'slds-text-color_error slds-text-font_bold';
                } else if (threat.threatLevel === 'HIGH') {
                    iconName = 'utility:warning';
                    cellClass = 'slds-text-color_warning slds-text-font_bold';
                } else if (threat.threatLevel === 'MEDIUM') {
                    iconName = 'utility:info_alt';
                }
                // Use spread syntax to copy original threat properties and add new ones
                return { ...threat, iconName: iconName, cellClass: cellClass };
            });
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            console.error('Error fetching active threats:', result.error);
            // *** CRITICAL FIX #2: RESETTING THE ARRAY ON ERROR ***
            // If an error occurs, we set activeThreats to an empty array.
            // This ensures the UI displays "No threats found" instead of crashing.
            this.activeThreats = [];
        }
    }

    // --- GETTERS FOR CLEANER TEMPLATE LOGIC ---

    // Getter to safely display the average risk score
    get averageRiskScore() {
        return this.metrics.averageRiskScore || 0;
    }

    // Getter to safely display the number of suspicious activities
    get suspiciousActivities() {
        return this.metrics.suspiciousActivities || 0;
    }

    // Getter to safely display the number of high-risk threats
    get activeHighRiskThreats() {
        return this.metrics.activeHighRiskThreats || 0;
    }

    // Getter to safely display the system health status
    get systemHealth() {
        return this.metrics.systemHealth || 'UNKNOWN';
    }
    // *** CORRECTION: This getter now returns the FULL class string ***
// Getter to determine the CSS class for the system health tile
get healthClass() {
    const baseClass = 'metric-value'; // The static class that applies to all
    const health = this.systemHealth;
    if (health === 'HEALTHY') {
        return `${baseClass} slds-theme_success`; // e.g., "metric-value slds-theme_success"
    }
    if (health === 'WARNING' || health === 'ERROR') {
        return `${baseClass} slds-theme_error`; // e.g., "metric-value slds-theme_error"
    }
    return baseClass; // Just return the base class by default
}


    // Getter to determine the CSS class for the system health tile
    get healthClass() {
        const health = this.systemHealth;
        if (health === 'HEALTHY') return 'slds-theme_success';
        if (health === 'WARNING' || health === 'ERROR') return 'slds-theme_error';
        return 'slds-theme_shade';
    }
    
    // Getter to check if there are any threats to display in the table
    // This is used for conditional rendering in the HTML template.
    get hasThreats() {
        // This will now work correctly because activeThreats is always an array.
        return this.activeThreats && this.activeThreats.length > 0;
    }

    // --- EVENT HANDLER FOR REFRESH BUTTON ---

    // This function will be called when a user clicks a refresh button in the HTML
    handleRefresh() {
        // Use refreshApex to re-fetch data from both wired methods
        refreshApex(this.wiredMetricsResult);
        refreshApex(this.wiredThreatsResult);
    }
}
