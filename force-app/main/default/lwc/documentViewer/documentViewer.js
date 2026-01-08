import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentData from '@salesforce/apex/SignatureRequestController.getDocumentData';
import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';
import getAuditTrail from '@salesforce/apex/AuditTrailManager.getAuditTrail';
import getPdfDownloadUrl from '@salesforce/apex/AuditTrailManager.getPdfDownloadUrl';



export default class DocumentViewer extends LightningElement {
    @api recordId;
    @track documentData;
    @track isLoading = true;
    @track isAnalyzing = false;
    @track analysisResult;
    @track showSignatureModal = false;
    @track signerEmail = '';
    @track signerName = '';
    @track isSendingRequest = false;
    @track activeToggles = [];
    @track showAuditModal = false;
    @track auditTrailData;
    @track isAuditLoading = false;

    @wire(getDocumentData, { documentId: '$recordId' })
    wiredDoc({ data, error }) {
        if (data) {
            this.documentData = data.document;
        } else if (error) {
            this.showToast('Error', 'Failed to load document', 'error');
        }
        this.isLoading = false;
    }

    handleMenuSelect(event) {
        const val = event.detail.value;
        if (val === 'requestSignature') this.showSignatureModal = true;
        if (val === 'downloadPDF') this.handleDownloadPdf();
        if (val === 'auditTrail') this.handleViewAuditTrail();
    }

    handleToggleChange(event) {
        const name = event.target.name;
        if (event.target.checked && !this.activeToggles.includes(name)) {
            this.activeToggles.push(name);
        } else {
            this.activeToggles = this.activeToggles.filter(t => t !== name);
        }
    }

    handleSignerEmailChange(e) { this.signerEmail = e.detail.value; }
    handleSignerNameChange(e) { this.signerName = e.detail.value; }

    async handleSendSignatureRequest() {
        await initiateSignatureRequest({
            documentId: this.recordId,
            signerEmail: this.signerEmail,
            signerName: this.signerName,
            activeToggles: this.activeToggles
        });
        this.showToast('Success', 'Signature request sent', 'success');
        this.handleCloseSignatureModal();
    }

 async handleViewAuditTrail() {
    if (this.auditTrailData) {
        this.showAuditModal = true;
        return;
    }

    this.showAuditModal = true;
    this.isAuditLoading = true;

    try {
        this.auditTrailData = await getAuditTrail({ limitCount: 500 });
    } catch (e) {
        this.showToast('Error', 'Failed to load audit trail', 'error');
    } finally {
        this.isAuditLoading = false;
    }
}

    handleCloseSignatureModal() {
        this.showSignatureModal = false;
        this.signerEmail = '';
        this.signerName = '';
        this.activeToggles = [];
    }
handleRequestSignature() {
    this.handleMenuSelect({ detail: { value: 'requestSignature' } });
}

async handleDownloadPDF() {
    try {
        const url = await getPdfDownloadUrl({ documentId: this.recordId });

        // Open PDF in new tab (professional behavior)
        window.open(url, '_blank');
    } catch (error) {
        this.showToast(
            'Error',
            'Unable to download PDF',
            'error'
        );
    }
}

handleAuditTrail() {
    this.handleMenuSelect({ detail: { value: 'auditTrail' } });
}

    handleCloseAuditModal() {
        this.showAuditModal = false;
    }

    get isSendDisabled() {
        return !this.signerEmail || !this.signerName || this.isSendingRequest;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get auditColumns() {
        return [
            { label: 'Action', fieldName: 'Action__c' },
            { label: 'Details', fieldName: 'Details__c' },
            { label: 'User', fieldName: 'UserName' },
            { label: 'Timestamp', fieldName: 'Timestamp__c', type: 'date' }
        ];
    }
}
