// documentViewer.js

import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentData from '@salesforce/apex/SignatureRequestController.getDocumentData';
import analyzeDocumentById from '@salesforce/apex/DocumentAnalysisService.analyzeDocumentById';
import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';
import getAuditTrail from '@salesforce/apex/AuditTrailManager.getAuditTrail';

export default class DocumentViewer extends LightningElement {
    @api recordId;
    @track documentData;
    @track isLoading = true;

    // AI analysis state
    @track isAnalyzing = false;
    @track analysisResult = null;

    // Signature modal state
    @track showSignatureModal = false;
    @track signerEmail = '';
    @track signerName = '';
    @track isSendingRequest = false;
    
    // --- NEW: State for Fraud Toggles ---
    @track activeToggles = [];

    // Audit trail state
    @track showAuditModal = false;
    @track auditTrailData;
    @track isAuditLoading = false;

    @wire(getDocumentData, { documentId: '$recordId' })
    wiredDocument({ error, data }) {
        this.isLoading = true;
        if (data) {
            this.documentData = data.document;
            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', 'Failed to load document details.', 'error');
            this.isLoading = false;
        }
    }


    handleMenuSelect(event) {
        const selectedItemValue = event.detail.value;
        switch (selectedItemValue) {
            case 'requestSignature':
                this.showSignatureModal = true;
                break;
            case 'downloadPDF':
                this.handleDownloadPdf();
                break;
            case 'auditTrail':
                this.handleViewAuditTrail();
                break;
            default:
                break;
        }
    }

    // --- SIGNATURE MODAL LOGIC ---
    handleCloseSignatureModal() {
        this.showSignatureModal = false;
        this.signerEmail = '';
        this.signerName = '';
        this.activeToggles = []; // Reset toggles on close
        this.isSendingRequest = false;
    }
    
    // --- REPLACE WITH THIS NEW FUNCTION ---
handleToggleChange(event) {
    const toggleName = event.target.name;   // e.g., 'IP_ANOMALY'
    const isChecked = event.target.checked; // true or false

    // Add the rule to our list if the toggle is on
    if (isChecked) {
        // Add to the array only if it's not already there
        if (!this.activeToggles.includes(toggleName)) {
            this.activeToggles.push(toggleName);
        }
    } 
    // Remove the rule from our list if the toggle is off
    else {
        this.activeToggles = this.activeToggles.filter(rule => rule !== toggleName);
    }
}

    handleSignerEmailChange(event) {
        this.signerEmail = event.detail.value;
    }
    handleSignerNameChange(event) {
        this.signerName = event.detail.value;
    }

    async handleSendSignatureRequest() {
        if (!this.signerEmail ||  !this.signerName) {
            this.showToast('Error', 'Please provide both signer email and name.', 'error');
            return;
        }
        this.isSendingRequest = true;
        try {
            // --- MODIFIED: Pass the activeToggles to Apex ---
            await initiateSignatureRequest({
                documentId: this.recordId,
                signerEmail: this.signerEmail,
                signerName: this.signerName,
                activeToggles: this.activeToggles // Pass the array of selected toggle values
            });
            this.showToast('Success', 'Signature request sent successfully!', 'success');
            this.handleCloseSignatureModal();
        } catch (error) {
            const msg = (error?.body?.message) ? error.body.message : error.message;
            this.showToast('Error', 'Failed to send signature request: ' + msg, 'error');
        } finally {
            this.isSendingRequest = false;
        }
    }
    
    // --- OTHER METHODS (unchanged) ---
    // (handleAnalyzeDocument, handleDownloadPdf, handleViewAuditTrail, auditColumns, etc.)
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
    // ... Paste your other unchanged methods here ...
    get isSendDisabled() {
        return !this.signerEmail || !this.signerName || this.isSendingRequest;
    }
    
    async handleViewAuditTrail() {
        this.showAuditModal = true;
        this.isAuditLoading = true;
        this.auditTrailData = null;
        try {
            const data = await getAuditTrail({ recordId: this.recordId, limitCount: 50 });
            this.auditTrailData = data.map(item => ({...item, UserName: item.User__r ? item.User__r.Name : 'System'}));
        } catch (error) {
            this.showToast('Error', 'Failed to load audit trail.', 'error');
        } finally {
            this.isAuditLoading = false;
        }
    }

    handleCloseAuditModal() {
        this.showAuditModal = false;
    }

    get auditColumns() {
        return [
            { label: 'Action', fieldName: 'Action__c', wrapText: true },
            { label: 'Details', fieldName: 'Details__c', wrapText: true },
            { label: 'User', fieldName: 'UserName', type: 'text' },
            { label: 'Timestamp', fieldName: 'Timestamp__c', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }}
        ];
    }
}

