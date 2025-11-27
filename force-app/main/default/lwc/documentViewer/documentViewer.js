// import { LightningElement, api, track, wire } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// import getDocumentData from '@salesforce/apex/SignatureRequestController.getDocumentData';
// import analyzeDocumentById from '@salesforce/apex/DocumentAnalysisService.analyzeDocumentById';
// import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';
// import getAuditTrail from '@salesforce/apex/AuditTrailManager.getAuditTrail';

// export default class DocumentViewer extends LightningElement {
//     @api recordId; // DocumentLifecycleConfiguration__c Id

//     @track documentData;
//     @track wiredDocumentResult;
//     @track isLoading = true;

//     // AI analysis state
//     @track isAnalyzing = false;
//     @track analysisResult = null;

//     // Signature modal state
//     @track showSignatureModal = false;
//     @track signerEmail = '';
//     @track signerName = '';
//     @track isSendingRequest = false;

//     // Audit trail state
//     @track showAuditModal = false;
//     @track auditTrailData;
//     @track isAuditLoading = false;

//     connectedCallback() {
//         console.log('DocumentViewer initialized with recordId:', this.recordId);
//         // IMPORTANT: remove this hard-coded override in real use
//         // this.recordId = 'a01fo00000Br7I4AAJ';
//     }

//     // Load document data
//     @wire(getDocumentData, { documentId: '$recordId' })
//     wiredDocument(result) {
//         console.log('Wired document result:', result);
//         this.wiredDocumentResult = result;
//         this.isLoading = true;

//         if (result.data) {
//             this.documentData = result.data.document;
//             console.log('Loaded document data:', this.documentData);
//             this.isLoading = false;
//         } else if (result.error) {
//             this.showToast('Error', 'Failed to load document details.', 'error');
//             this.isLoading = false;
//         }
//     }

//     // AI document analysis
//     async handleAnalyzeDocument() {
//         this.isAnalyzing = true;
//         this.analysisResult = null;

//         try {
//             const result = await analyzeDocumentById({ documentId: this.recordId });
//             this.analysisResult = result;
//             this.showToast('Success', 'Document analysis complete.', 'success');
//         } catch (error) {
//             const errorMessage =
//                 (error && error.body && error.body.message)
//                     ? error.body.message
//                     : error.message;
//             this.showToast(
//                 'Analysis Failed',
//                 'Error calling AI service: ' + errorMessage,
//                 'error'
//             );
//         } finally {
//             this.isAnalyzing = false;
//         }
//     }

//     // Menu action handler
//     handleMenuSelect(event) {
//         const selectedItemValue = event.detail.value;

//         switch (selectedItemValue) {
//             case 'requestSignature':
//                 this.showSignatureModal = true;
//                 break;

//             case 'downloadPDF':
//                 this.handleDownloadPdf();
//                 break;

//             case 'auditTrail':
//                 this.handleViewAuditTrail();
//                 break;

//             default:
//                 this.showToast(
//                     'Action',
//                     `Unknown action '${selectedItemValue}'`,
//                     'info'
//                 );
//         }
//     }

//     // Simple PDF handler: open browser print dialog (user can "Save as PDF")
//     handleDownloadPdf() {
//         try {
//             window.print();
//         } catch (e) {
//             this.showToast(
//                 'Error',
//                 'Unable to open print dialog for PDF download.',
//                 'error'
//             );
//         }
//     }

//     // AUDIT TRAIL

//     async handleViewAuditTrail() {
//         this.showAuditModal = true;
//         this.isAuditLoading = true;
//         this.auditTrailData = null;

//         try {
//             const data = await getAuditTrail({ documentId: this.recordId });
//             // Data is a list of AuditTrail__c (Action__c, Status__c, Details__c, Timestamp__c, UserId__c, User__r.Name) @191
//             this.auditTrailData = data;
//         } catch (error) {
//             const msg =
//                 (error && error.body && error.body.message)
//                     ? error.body.message
//                     : error.message;
//             this.showToast(
//                 'Error',
//                 'Failed to load audit trail: ' + msg,
//                 'error'
//             );
//         } finally {
//             this.isAuditLoading = false;
//         }
//     }

//     handleCloseAuditModal() {
//         this.showAuditModal = false;
//         this.auditTrailData = null;
//     }

//     // Columns for audit datatable
//     get auditColumns() {
//         return [
//             { label: 'Action', fieldName: 'Action__c' },
//             { label: 'Status', fieldName: 'Status__c' },
//             { label: 'Details', fieldName: 'Details__c' },
//             {
//                 label: 'Timestamp',
//                 fieldName: 'Timestamp__c',
//                 type: 'date',
//                 typeAttributes: {
//                     year: 'numeric',
//                     month: 'short',
//                     day: '2-digit',
//                     hour: '2-digit',
//                     minute: '2-digit'
//                 }
//             }
//         ];
//     }

//     // SIGNATURE MODAL

//     get isSendDisabled() {
//         return !this.signerEmail || !this.signerName || this.isSendingRequest;
//     }

//     handleCloseSignatureModal() {
//         this.showSignatureModal = false;
//         this.signerEmail = '';
//         this.signerName = '';
//         this.isSendingRequest = false;
//     }

//     handleSignerEmailChange(event) {
//         this.signerEmail = event.detail.value;
//     }

//     handleSignerNameChange(event) {
//         this.signerName = event.detail.value;
//     }

//     async handleSendSignatureRequest() {
//         if (!this.signerEmail || !this.signerName) {
//             this.showToast(
//                 'Error',
//                 'Please provide both signer email and signer name.',
//                 'error'
//             );
//             return;
//         }

//         this.isSendingRequest = true;

//         try {
//             await initiateSignatureRequest({
//                 documentId: this.recordId,
//                 signerEmail: this.signerEmail,
//                 signerName: this.signerName
//             });

//             this.showToast(
//                 'Success',
//                 'Signature request sent successfully!',
//                 'success'
//             );
//             this.handleCloseSignatureModal();
//         } catch (error) {
//             const msg =
//                 (error && error.body && error.body.message)
//                     ? error.body.message
//                     : error.message;
//             this.showToast(
//                 'Error',
//                 'Failed to send signature request: ' + msg,
//                 'error'
//             );
//         } finally {
//             this.isSendingRequest = false;
//         }
//     }

//     // Toast helper
//     showToast(title, message, variant) {
//         const evt = new ShowToastEvent({
//             title,
//             message,
//             variant
//         });
//         this.dispatchEvent(evt);
//     }
// }
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentData from '@salesforce/apex/SignatureRequestController.getDocumentData';
import analyzeDocumentById from '@salesforce/apex/DocumentAnalysisService.analyzeDocumentById';
import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';
import getAuditTrail from '@salesforce/apex/AuditTrailManager.getAuditTrail'; // This now matches the Apex class

export default class DocumentViewer extends LightningElement {
    @api recordId; // DocumentLifecycleConfiguration__c Id
    @track documentData;
    @track wiredDocumentResult;
    @track isLoading = true;

    // AI analysis state
    @track isAnalyzing = false;
    @track analysisResult = null;

    // Signature modal state
    @track showSignatureModal = false;
    @track signerEmail = '';
    @track signerName = '';
    @track isSendingRequest = false;

    // Audit trail state
    @track showAuditModal = false;
    @track auditTrailData;
    @track isAuditLoading = false;



    @track securityAssessmentResult = null;
    @track isAssessingSecurity = false;

    connectedCallback() {
        console.log('DocumentViewer initialized with recordId:', this.recordId);
    }

    // Load document data
    @wire(getDocumentData, { documentId: '$recordId' })
    wiredDocument(result) {
        this.wiredDocumentResult = result;
        this.isLoading = true;
        if (result.data) {
            this.documentData = result.data.document;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load document details.', 'error');
            this.isLoading = false;
        }
    }

    // AI document analysis
    async handleAnalyzeDocument() {
        this.isAnalyzing = true;
        this.analysisResult = null;
        try {
            const result = await analyzeDocumentById({ documentId: this.recordId });
            this.analysisResult = result;
            this.showToast('Success', 'Document analysis complete.', 'success');
        } catch (error) {
            const errorMessage = (error?.body?.message) ? error.body.message : error.message;
            this.showToast('Analysis Failed', 'Error calling AI service: ' + errorMessage, 'error');
        } finally {
            this.isAnalyzing = false;
        }
    }

    // Menu action handler
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
                this.showToast('Action', `Unknown action '${selectedItemValue}'`, 'info');
        }
    }

    // Simple PDF handler: open browser print dialog


//      handleDownloadPDF() {
//     try {
//         if (!this.recordId) {
//             this.showToast('Error', 'No document Id found for PDF generation', 'error');
//             return;
//         }

//         // Open Visualforce PDF page in a new tab
//         const url = '/apex/DocumentPDF?id=' + this.recordId;
//         window.open(url, '_blank');

//     } catch (error) {
//         const message =
//             (error && error.body && error.body.message) ||
//             error?.message ||
//             'Failed to open PDF';

//         this.showToast('Error', message, 'error');
//     }
// }
    handleDownloadPdf() {
        try {
            window.print();
        } catch (e) {
            this.showToast('Error', 'Unable to open print dialog.', 'error');
        }
    }


    

    // AUDIT TRAIL
    async handleViewAuditTrail() {
        this.showAuditModal = true;
        this.isAuditLoading = true;
        this.auditTrailData= null;
        try {
            // This call now matches the corrected Apex class
            const data = await getAuditTrail({ recordId: this.recordId, limitCount: 50 });
            this.auditTrailData = data;
        } catch (error) {
            const msg = (error?.body?.message) ? error.body.message : error.message;
            this.showToast('Error', 'Failed to load audit trail: ' + msg, 'error');
        } finally {
            this.isAuditLoading = false;
        }
    }

    handleCloseAuditModal() {
        this.showAuditModal = false;
        this.auditTrailData = null;
    }

    get auditColumns() {
        return [
            { label: 'Action', fieldName: 'Action__c' },
            { label: 'Status', fieldName: 'Status__c' },
            { label: 'Details', fieldName: 'Details__c', wrapText: true },
            { label: 'User', fieldName: 'UserName', type: 'text', initialWidth: 150, 
              // To access User.Name, we need to flatten the data
              fieldName: 'User.Name'
            },
            {
                label: 'Timestamp', fieldName: 'Timestamp__c', type: 'date',
                typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
            }
        ];
    }
    

    // SIGNATURE MODAL
    get isSendDisabled() {
        return !this.signerEmail || !this.signerName || this.isSendingRequest;
    }
    
    handleCloseSignatureModal() {
        this.showSignatureModal = false;
        this.signerEmail = '';
        this.signerName = '';
        this.isSendingRequest = false;
    }
    
    handleSignerEmailChange(event) {
        this.signerEmail = event.detail.value;
    }
    
    handleSignerNameChange(event) {
        this.signerName = event.detail.value;
    }
    
    async handleSendSignatureRequest() {
        if (!this.signerEmail || !this.signerName) {
            this.showToast('Error', 'Please provide both signer email and name.', 'error');
            return;
        }
        this.isSendingRequest = true;
        try {
            await initiateSignatureRequest({
                documentId: this.recordId,
                signerEmail: this.signerEmail,
                signerName: this.signerName
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

    // Toast helper
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(evt);
    }
}