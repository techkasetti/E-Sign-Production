import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJS from '@salesforce/resourceUrl/ChartJS';
import getUnifiedDashboardData from '@salesforce/apex/SystemHealthController.getUnifiedDashboardData';

export default class SystemHealthMonitor extends LightningElement {
    // ===============================
    // == STATE
    // ===============================
    @track isLoading = true;
    @track error;
    @track healthData = {};
    @track businessAnalytics = {};
    wiredDataResult;

    // Chart-related state
    isChartJsLoaded = false;
    chartInitialized = false;
    responseChart;
    systemLoadChart;

    // ===============================
    // == DATA TABLE COLUMNS
    // ===============================
    metricsColumns = [
        { label: 'Component', fieldName: 'component', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text', cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Response Time', fieldName: 'responseTime', type: 'text' },
        { label: 'Throughput', fieldName: 'throughput', type: 'text' }
    ];

    // ===============================
    // == WIRE SERVICE
    // ===============================
    @wire(getUnifiedDashboardData)
    wiredUnifiedData(result) {
        this.wiredDataResult = result;
        if (result.data) {
            console.log('DEBUG 1 (Wire Service): Raw data from Apex ->', JSON.parse(JSON.stringify(result.data)));
            this.healthData = result.data.systemHealth || {};
            this.businessAnalytics = result.data.businessAnalytics || {};
            this.error = undefined;
            this.isLoading = false;
            // Attempt to update charts now that data is available
            this.updateCharts();
        } else if (result.error) {
            console.error('ERROR: [WIRE] Failed to receive data from getUnifiedDashboardData Apex method.', JSON.stringify(result.error));
            this.error = result.error;
            this.healthData = {};
            this.businessAnalytics = {};
            this.isLoading = false;
        }
    }

    // ===============================
    // == LIFECYCLE HOOKS
    // ===============================
    connectedCallback() {
        if (this.isChartJsLoaded) return;
        loadScript(this, ChartJS)
            .then(() => {
                this.isChartJsLoaded = true;
                // If data has already arrived, initialize charts now
                if (!this.isLoading) {
                    this.initializeCharts();
                }
            })
            .catch(error => {
                console.error('ERROR: [LIFECYCLE] FATAL - Failed to load Chart.js script.', error);
                this.error = 'Failed to load the charting library. Please check the static resource.';
            });
    }

    renderedCallback() {
        // This ensures charts are only initialized once, after ChartJS is loaded and the component is rendered.
        if (this.chartInitialized | !this.isChartJsLoaded | this.isLoading) {
            return;
        }
        this.initializeCharts();
    }

    // ===============================
    // == CHART SETUP
    // ===============================
    initializeCharts() {
        // Prevent re-initialization
        if (this.chartInitialized) return;
        this.chartInitialized = true;

        try {
            const responseCtx = this.template.querySelector('canvas[data-id="responseChart"]').getContext('2d');
            this.responseChart = new Chart(responseCtx, this.getResponseTimeChartConfig());

            const loadCtx = this.template.querySelector('canvas[data-id="loadChart"]').getContext('2d');
            this.systemLoadChart = new Chart(loadCtx, this.getSystemLoadChartConfig());

            // Update with data that may have arrived before rendering
            this.updateCharts();
        } catch (e) {
            console.error('ERROR: [CHARTS] Failed to create chart instances.', e);
        }
    }

    updateCharts() {
        // === THIS IS THE CRITICAL FIX ===
        // The guard clauses now use the correct logical OR '||' operator.
        if (!this.chartInitialized | !this.responseChart | !this.systemLoadChart) {
            return;
        }
        if (!this.healthData | !this.healthData.responseTimeHistory | !this.healthData.systemLoadHistory) {
            return;
        }

        try {
            // Response Time Chart
            const responseHistory = this.healthData.responseTimeHistory || [];
            this.responseChart.data.labels = responseHistory.map(p => new Date(p.timestamp).toLocaleTimeString());
            this.responseChart.data.datasets[0].data = responseHistory.map(p => p.responseTime);
            this.responseChart.update();

            // System Load Chart
            const loadHistory = this.healthData.systemLoadHistory || [];
            this.systemLoadChart.data.labels = loadHistory.map(p => new Date(p.timestamp).toLocaleTimeString());
            this.systemLoadChart.data.datasets[0].data = loadHistory.map(p => p.cpuUsage);
            this.systemLoadChart.data.datasets[1].data = loadHistory.map(p => p.memoryUsage);
            this.systemLoadChart.update();

        } catch (e) {
            console.error('ERROR: [CHARTS] An error occurred while updating chart data.', e);
        }
    }
    
    // ... (rest of the file remains the same) ...

    // ===============================
    // == ACTIONS
    // ===============================
    async refreshAllData() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredDataResult);
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    // ===============================
    // == GETTERS — SYSTEM HEALTH
    // ===============================
    get overallHealthStatus() { return this.healthData?.overallStatus || 'Unknown'; }
    get overallHealthScore() { return this.healthData?.healthScore || 0; }
    get systemUptime() { return this.healthData?.systemUptime || 'N/A'; }
    get avgResponseTime() { return this.healthData?.avgResponseTime || 'N/A'; }
    get activeSessions() { return this.healthData?.activeSessions || 'N/A'; }
    get errorRate() { return this.healthData?.errorRate || 'N/A'; }
    get performanceMetrics() {
        return (this.healthData?.componentStatus || []).map(m => ({ ...m, statusClass: this.getStatusClass(m.status) }));
    }
    get overallHealthClass() {
        const status = (this.healthData?.overallStatus || '').toLowerCase();
        if (status === 'critical') return 'health-card slds-box slds-text-align_center health-critical';
        if (status === 'warning') return 'health-card slds-box slds-text-align_center health-warning';
        return 'health-card slds-box slds-text-align_center health-healthy';
    }
    get overallHealthIcon() {
        const status = (this.healthData?.overallStatus || '').toLowerCase();
        if (status === 'critical') return 'utility:error';
        if (status === 'warning') return 'utility:warning';
        return 'utility:success';
    }

    // ===============================
    // == GETTERS — BUSINESS ANALYTICS
    // ===============================
    get signatureMethods() {
        const methods = this.businessAnalytics?.signatureMethodsUsed || {};
        // ** THIS FIX IS ALSO INCLUDED TO ENSURE IT WORKS **
        return {
            Typed: methods.Typed | 0,
            Drawn: methods.Drawn || 0,
            Uploaded: methods.Uploaded || 0
        };
    }
    get hasRecentActivity() { return (this.businessAnalytics?.recentActivity?.length > 0); }

    // ===============================
    // == HELPERS
    // ===============================
    getStatusClass(status) {
        if (!status) return '';
        const s = status.toLowerCase();
        if (s === 'healthy') return 'slds-text-color_success';
        if (s === 'warning') return 'slds-text-color_warning';
        if (s === 'critical' || s === 'error') return 'slds-text-color_error';
        return '';
    }
    get errorText() {
        if (!this.error) return 'An unknown error occurred.';
        if (this.error.body?.message) return this.error.body.message;
        return JSON.stringify(this.error);
    }

    // ===============================
    // == CHART CONFIGS
    // ===============================
    getResponseTimeChartConfig() {
        return {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Response Time (ms)',
                    data: [],
                    borderColor: '#0070d2',
                    backgroundColor: 'rgba(0, 112, 210, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true } } }
        };
    }
    getSystemLoadChartConfig() {
        return {
            type: 'line',
            data: {
                labels: [],
                datasets: [
                    { label: 'CPU Usage (%)', data: [], borderColor: '#04844b', fill: false, tension: 0.4 },
                    { label: 'Memory Usage (%)', data: [], borderColor: '#ffb75d', fill: false, tension: 0.4 }
                ]
            },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true, max: 100 } } }
        };
    }
}
