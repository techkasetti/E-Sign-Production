import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSignatureRequest from '@salesforce/apex/SignatureRequestController.getSignatureRequest';
import submitSignature from '@salesforce/apex/SignatureRequestController.submitSignature';
import logSignatureViewed from 
'@salesforce/apex/SignatureRequestController.logSignatureViewed';


export default class SignaturePad extends LightningElement {

    @api recordId;
    @track signatureRequest;
    @track documentContent;
    @track isLoading = true;
    @track isSignatureComplete = false;
    @track selectedSignatureMethod = 'type';
    @track typedSignature = '';
    @track uploadedSignatureUrl = '';
    @track agreementAccepted = false;

    isDrawing = false;
    canvasContext;
    drawnSignatureData = '';
    @track startTime;
    @track userCoordinates = null;

    
    // for face recogniztion 

    @track isFaceVerified = false;

    connectedCallback() {
        this.startTime = new Date();

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.userCoordinates = `${position.coords.latitude},${position.coords.longitude}`;
                    console.log('Geolocation captured:', this.userCoordinates);
                },
                (error) => {
                    console.error('Geolocation Error:', error.message);
                }
            );
        } else {
            console.log('Geolocation is not supported by this browser.');
        }
    }
    connectedCallback() {
    logSignatureViewed({ requestId: this.recordId });
}


    @wire(getSignatureRequest, { requestId: '$recordId' })
    wiredRequest({ error, data }) {
        if (data) {
            this.signatureRequest = data;

            if (data.Status__c === 'Signed' || data.Status__c === 'Completed') {
                this.isSignatureComplete = true;
            } else {
                if (data.DocumentId__r) {
                    this.documentContent = data.DocumentId__r.GeneratedClause__c;
                }
            }
        } else if (error) {
            this.showToast('Error Loading Data', error.body.message, 'error');
        }

        this.isLoading = false;
    }

    async getClientIPAddress() {
        try {
            const response = await fetch('https://api.ipify.org?format=json');

            if (!response.ok) {
                throw new Error('Network response was not ok for ipify.');
            }

            const data = await response.json();
            console.log('Successfully fetched IP:', data.ip);
            return data.ip;

        } catch (error) {
            console.error('Failed to fetch IP address:', error);
            this.showToast(
                'Network Error',
                'Could not retrieve IP address. Fraud check may be limited.',
                'warning'
            );
            return null;
        }
    }

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
                this.showToast('Error', 'Invalid signature method.', 'error');
                this.isLoading = false;
                return;
        }

        const endTime = new Date();
        const timeToSignSeconds = Math.round((endTime - this.startTime) / 1000);
        const clientIp = await this.getClientIPAddress();

        const userContext = {
            timeToSign: timeToSignSeconds,
            location: this.userCoordinates,
            ip: clientIp
        };

        try {
            const result = await submitSignature({
                requestId: this.recordId,
                signatureData: signatureData,
                signatureMethod: signatureMethod,
                userContextJSON: JSON.stringify(userContext)
            });

            if (result === 'SUCCESS') {
                this.isSignatureComplete = true;
                this.showToast('Success', 'Signature submitted successfully!', 'success');
            } else {
                this.showToast('Submission Info', result, 'info');
            }

        } catch (error) {
            this.showToast(
                'Submission Failed',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    get signatureMethodOptions() {
        return [
            { label: 'Type My Name', value: 'type' },
            { label: 'Draw Signature', value: 'draw' },
            { label: 'Upload Image', value: 'upload' }
            ];
    }

    get isTypedSignature() {
        return this.selectedSignatureMethod === 'type';
    }

    get isDrawSignature() {
        return this.selectedSignatureMethod === 'draw';
    }

    get isUploadSignature() {
        return this.selectedSignatureMethod === 'upload';
    }

    get isSubmitDisabled() {
        if (!this.agreementAccepted || this.isLoading) return true;
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
            this.uploadedSignatureUrl =
                `/sfc/servlet.shepherd/document/download/${uploadedFiles[0].documentId}`;
        }
    }

    renderedCallback() {
        if (this.isDrawSignature && !this.canvasContext) {
            this.initializeCanvas();
        }
    }

    initializeCanvas() {
        const canvas = this.template.querySelector('canvas');
        this.canvasContext = canvas.getContext('2d');
        this.canvasContext.strokeStyle = "#000";
        this.canvasContext.lineWidth = 2;
    }

    startDrawing(event) {
        event.preventDefault();
        this.isDrawing = true;

        const pos = this.getCanvasCoordinates(event);
        this.canvasContext.beginPath();
        this.canvasContext.moveTo(pos.x, pos.y);
    }

    draw(event) {
        event.preventDefault();
        if (!this.isDrawing) return;

        const pos = this.getCanvasCoordinates(event);
        this.canvasContext.lineTo(pos.x, pos.y);
        this.canvasContext.stroke();
    }

    stopDrawing() {
        if (!this.isDrawing) return;

        this.isDrawing = false;
        this.drawnSignatureData =
            this.template.querySelector('canvas').toDataURL();
    }

    getCanvasCoordinates(event) {
        const canvas = this.template.querySelector('canvas');
        const rect = canvas.getBoundingClientRect();

        const clientX = event.touches
            ? event.touches[0].clientX
            : event.clientX;

        const clientY = event.touches
            ? event.touches[0].clientY
            : event.clientY;

        return {
            x: clientX - rect.left,
            y: clientY - rect.top
        };
    }
 

    handleClearCanvas() {
        const canvas = this.template.querySelector('canvas');
        this.canvasContext.clearRect(0, 0, canvas.width, canvas.height);
        this.drawnSignatureData = '';
    }




    // for face recogniztion 

 
   handleVerificationSuccess(event) {
    console.log('Face verification event received:', event.detail);

    if (event.detail?.faceVerified === true) {
        this.isFaceVerified = true;

        // 🔥 FORCE LWC RE-RENDER
        this.isLoading = true;
        setTimeout(() => {
            this.isLoading = false;
        }, 0);
    }
}

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
    }
