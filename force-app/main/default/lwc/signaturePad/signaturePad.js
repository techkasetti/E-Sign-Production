import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSignatureRequest from '@salesforce/apex/SignatureRequestController.getSignatureRequest';
import submitSignature from '@salesforce/apex/SignatureRequestController.submitSignature';

export default class SignaturePad extends LightningElement {
    @api recordId;
    @track signatureRequest;
    @track documentContent;
    @track error;
    @track isLoading = true;
    @track isSignatureComplete = false;
    @track selectedSignatureMethod = 'type';
    @track typedSignature = '';
    @track uploadedSignatureUrl = '';
    @track agreementAccepted = false;
    isDrawing = false;
    canvasContext;
    drawnSignatureData = '';

    // --- NEW PROPERTY TO TRACK BEHAVIOR ---
    @track startTime;

    connectedCallback() {
        // Start the timer as soon as the component loads
        this.startTime = new Date();
    }

    @wire(getSignatureRequest, { requestId: '$recordId' })
    wiredRequest({ error, data }) {
        if (data) {
            this.signatureRequest = data;
            if (data.Status__c === 'Signed' ||data.Status__c === 'Completed') {
                this.isSignatureComplete = true;
            } else {
                this.documentContent = data.DocumentId__r.GeneratedClause__c;
            }
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.showToast('Error Loading Data', error.body.message, 'error');
            this.signatureRequest = undefined;
        }
        this.isLoading = false;
    }

    // --- SUBMIT ACTION (REVISED TO SEND DYNAMIC, REAL DATA) ---
    async handleSubmitSignature() {
        this.isLoading = true;
        let signatureData;
        let signatureMethod;

        switch (this.selectedSignatureMethod) {
            case 'type':
                signatureData = this.typedSignature;
                signatureMethod = 'Type';
                break;
            case 'draw':
                signatureData = this.drawnSignatureData;
                signatureMethod = 'Draw';
                break;
            case 'upload':
                signatureData = this.uploadedSignatureUrl;
                signatureMethod = 'Upload';
                break;
            default:
                this.showToast('Error', 'Invalid signature method selected', 'error');
                this.isLoading = false;
                return;
        }

        // *** DYNAMIC BEHAVIORAL DATA CAPTURE ***
        const endTime = new Date();
        const timeToSignSeconds = Math.round((endTime - this.startTime) / 1000);

        // This object now contains REAL data, not hardcoded values.
        const userContext = {
            timeToSign: timeToSignSeconds
            // In the future, you can add more metrics here, like mouse speed or click count.
        };
        const userContextJSON = JSON.stringify(userContext);
        // *** END OF DATA CAPTURE ***

        try {
            // Call Apex with all four parameters, including the new dynamic JSON
            const result = await submitSignature({
                requestId: this.recordId,
                signatureData: signatureData,
                signatureMethod: signatureMethod,
                userContextJSON: userContextJSON // Pass the real user behavior data
            });

            if (result) {
                this.isSignatureComplete = true;
                this.showToast('Success', 'Signature submitted successfully!', 'success');
            }
        } catch (error) {
            this.showToast('Submission Failed', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- All other methods (getters, handlers, etc.) remain unchanged ---
    renderedCallback() {
        if (this.isDrawSignature && !this.canvasContext) {
            this.initializeCanvas();
        }
    }

    get signatureMethodOptions() {
        return [
            { label: 'Type My Name', value: 'type' },
            { label: 'Draw Signature', value: 'draw' },
            { label: 'Upload Image', value: 'upload' },
        ];
    }

    get isTypedSignature() { return this.selectedSignatureMethod === 'type'; }
    get isDrawSignature() { return this.selectedSignatureMethod === 'draw'; }
    get isUploadSignature() { return this.selectedSignatureMethod === 'upload'; }

    get isSubmitDisabled() {
        if (!this.agreementAccepted) return true;
        if (this.isTypedSignature && !this.typedSignature) return true;
        if (this.isDrawSignature && !this.drawnSignatureData) return true;
        if (this.isUploadSignature && !this.uploadedSignatureUrl) return true;
        return false;
    }

    handleSignatureMethodChange(event) {
        this.selectedSignatureMethod = event.detail.value;
    }

    handleTypedSignatureChange(event) {
        this.typedSignature = event.target.value;
    }

    handleAgreementChange(event) {
        this.agreementAccepted = event.detail.checked;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.uploadedSignatureUrl = `/sfc/servlet.shepherd/document/download/${uploadedFiles[0].documentId}`;
            this.showToast('Success', 'Signature image uploaded.', 'success');
        }
    }

    initializeCanvas() {
        const canvas = this.template.querySelector('canvas.signature-canvas');
        this.canvasContext = canvas.getContext('2d');
        this.canvasContext.strokeStyle = "#000";
        this.canvasContext.lineWidth = 2;
    }

    handleMouseDown(event) {
        this.isDrawing = true;
        const coords = this.getCoordinates(event);
        this.canvasContext.beginPath();
        this.canvasContext.moveTo(coords.x, coords.y);
    }

    handleMouseMove(event) {
        if (!this.isDrawing) return;
        const coords = this.getCoordinates(event);
        this.canvasContext.lineTo(coords.x, coords.y);
        this.canvasContext.stroke();
    }

    handleMouseUp() {
        if (!this.isDrawing) return;
        this.isDrawing = false;
        this.drawnSignatureData = this.template.querySelector('canvas.signature-canvas').toDataURL();
    }
    
    handleTouchStart(event) {
        event.preventDefault();
        this.isDrawing = true;
        const coords = this.getCoordinates(event.touches[0]);
        this.canvasContext.beginPath();
        this.canvasContext.moveTo(coords.x, coords.y);
    }

    handleTouchMove(event) {
        event.preventDefault();
        if (!this.isDrawing) return;
        const coords = this.getCoordinates(event.touches[0]);
        this.canvasContext.lineTo(coords.x, coords.y);
        this.canvasContext.stroke();
    }
    
    handleTouchEnd(event) {
        event.preventDefault();
        if (!this.isDrawing) return;
        this.isDrawing = false;
        this.drawnSignatureData = this.template.querySelector('canvas.signature-canvas').toDataURL();
    }

    getCoordinates(event) {
        const canvas = this.template.querySelector('canvas.signature-canvas');
        const rect = canvas.getBoundingClientRect();
        return { x: event.clientX - rect.left, y: event.clientY - rect.top };
    }

    handleClearCanvas() {
        this.canvasContext.clearRect(0, 0, this.template.querySelector('canvas.signature-canvas').width, this.template.querySelector('canvas.signature-canvas').height);
        this.drawnSignatureData = '';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}
