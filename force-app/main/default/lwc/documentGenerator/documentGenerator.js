// force-app/main/default/lwc/documentGenerator/documentGenerator.js
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import generateClause from '@salesforce/apex/ClauseGenerator.generateClause';
import validateCompliance from '@salesforce/apex/ComplianceChecker.validateCompliance';
import generateDocument from '@salesforce/apex/DocumentLifecycleDeploymentManager.generateDocument';
import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';
import generateEnhancedClause from '@salesforce/apex/AdvancedAIService.generateEnhancedClause';


export default class DocumentGenerator extends LightningElement {
    @track currentStep = 'step-1';
    @track isLoading = false;

    // Step 1 Data
    @track selectedRegion = '';
    @track selectedRole = '';
    @track selectedContractType = '';
    @track documentTitle = '';

    // Step 2 Data
    @track previewClause = '';
 @track useAI = false;
    @track aiInsightId = null;
    // Step 3 Data
    @track complianceResult = null;

    // Step 4 Data
    @track generatedDocumentId = '';
    @track showSignatureModal = false;
    @track signerEmail = '';
    @track signerName = '';

    // Combobox Options
    get regionOptions() {
        return [
            { label: 'US (United States)', value: 'US' },
            { label: 'EU (European Union)', value: 'EU' },
            { label: 'APAC (Asia-Pacific)', value: 'APAC' },
        ];
    }

    get roleOptions() {
        return [
            { label: 'Manager', value: 'Manager' },
            { label: 'Director', value: 'Director' },
            { label: 'Employee', value: 'Employee' },
        ];
    }

    get contractTypeOptions() {
        return [
            { label: 'Employment Agreement', value: 'Employment' },
            { label: 'Non-Disclosure Agreement (NDA)', value: 'NDA' },
            { label: 'Service Agreement', value: 'Service Agreement' },
        ];
    }
    
    // --- GETTERS FOR UI STATE ---
    get isStep1() { return this.currentStep === 'step-1'; }
    get isStep2() { return this.currentStep === 'step-2'; }
    get isStep3() { return this.currentStep === 'step-3'; }
    get isStep4() { return this.currentStep === 'step-4'; }

    get isFirstStep() { return this.currentStep === 'step-1'; }
    get isLastStep() { return this.currentStep === 'step-4'; }

    get hasViolations() {
        return this.complianceResult && this.complianceResult.violations && this.complianceResult.violations.length > 0;
    }

    get complianceBoxClass() {
        if (!this.complianceResult) return 'slds-box';
        return this.complianceResult.isCompliant ? 'slds-box slds-theme_success' : 'slds-box slds-theme_warning';
    }

    get complianceStatusClass() {
        if (!this.complianceResult) return '';
        return this.complianceResult.isCompliant ? 'slds-badge_lightest' : 'slds-badge_warning';
    }

    // --- HANDLERS ---
    handleInputChange(event) {
        const { name, value } = event.target;
        if (name === 'region') this.selectedRegion = value;
        if (name === 'role') this.selectedRole = value;
        if (name === 'contractType') this.selectedContractType = value;
        if (name === 'documentTitle') this.documentTitle = value;
    }

    handleNext() {
        if (this.currentStep === 'step-1') {
            if (this.validateStep1()) {
                this.currentStep = 'step-2';
                this.handleGeneratePreview();
            }
        } else if (this.currentStep === 'step-2') {
            this.currentStep = 'step-3';
            this.handleComplianceCheck();
        } else if (this.currentStep === 'step-3') {
            if (!this.complianceResult || !this.complianceResult.isCompliant) {
                this.showToast('Warning', 'Document must be compliant to proceed.', 'warning');
                return;
            }
            this.currentStep = 'step-4';
        }
    }

    handlePrevious() {
        if (this.currentStep === 'step-2') this.currentStep = 'step-1';
        if (this.currentStep === 'step-3') this.currentStep = 'step-2';
        if (this.currentStep === 'step-4') this.currentStep = 'step-3';
    }

    validateStep1() {
        if (!this.selectedRegion || !this.selectedRole || !this.selectedContractType || !this.documentTitle) {
            this.showToast('Error', 'Please fill in all required fields.', 'error');
            return false;
        }
        return true;
    }

    // --- APEX CALLS ---
    async handleGeneratePreview() {
        this.isLoading = true;
        try {
            this.previewClause = await generateClause({
                region: this.selectedRegion,
                role: this.selectedRole,
                contractType: this.selectedContractType
            });
        } catch (error) {
            this.showToast('Error', 'Failed to generate preview: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleComplianceCheck() {
        this.isLoading = true;
        try {
            this.complianceResult = await validateCompliance({
                clause: this.previewClause,
                region: this.selectedRegion,
                contractType: this.selectedContractType
            });
        } catch (error) {
            this.showToast('Error', 'Compliance check failed: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateDocument() {
        this.isLoading = true;
        try {
            const docId = await generateDocument({
                region: this.selectedRegion,
                role: this.selectedRole,
                contractType: this.selectedContractType,
                documentTitle: this.documentTitle
            });
            this.generatedDocumentId = docId;
            this.showToast('Success', 'Document generated successfully!', 'success');
        } catch (error) {
            this.showToast('Error', 'Document generation failed: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }
handleAIToggle(event) {
        this.useAI = event.target.checked;
        // Regenerate the preview when the toggle changes
        this.handleGeneratePreview();
    }

    // 4. Update the preview handler to choose which Apex method to call
    async handleGeneratePreview() {
        this.isLoading = true;
        this.previewClause = ''; // Clear previous preview
        try {
            if (this.useAI) {
                // Call the new AI service
                const result = await generateEnhancedClause({
                    region: this.selectedRegion,
                    role: this.selectedRole,
                    contractType: this.selectedContractType,
                    documentTitle: this.documentTitle
                });
                this.previewClause = result.GeneratedClause__c;
                this.aiInsightId = result.Id; // Store the ID for later
                this.showToast('Success', 'AI-enhanced clause generated.', 'success');
            } else {
                // Call the original, faster generator
                this.previewClause = await generateClause({
                    region: this.selectedRegion,
                    role: this.selectedRole,
                    contractType: this.selectedContractType
                });
                this.aiInsightId = null; // Clear the AI Insight ID
            }
        } catch (error) {
            this.showToast(
                'Error',
                'Failed to generate preview: ' + error.body.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }
    async handleSendSignatureRequest() {
        if (!this.signerEmail || !this.signerName) {
            this.showToast('Error', 'Please provide both signer email and name.', 'error');
            return;
        }
        this.isLoading = true;
        try {
            const requestId = await initiateSignatureRequest({
                documentId: this.generatedDocumentId,
                signerEmail: this.signerEmail,
                signerName: this.signerName
            });
            this.showToast('Success', `Signature request sent successfully! Request ID: ${requestId}`, 'success');
            this.handleCloseSignatureModal();
        } catch (error) {
            this.showToast('Error', 'Failed to send signature request: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    get complianceStatusLabel() {
    if (!this.complianceResult) {
        return 'N/A';
    }
    return this.complianceResult.isCompliant ? 'Compliant' : 'Requires Review';
}

    
    // --- MODAL & UTILITY FUNCTIONS ---
    handleOpenSignatureModal() { this.showSignatureModal = true; }

    handleCloseSignatureModal() {
        this.showSignatureModal = false;
        this.signerEmail = '';
        this.signerName = '';
    }

    handleSignerChange(event) {
        if (event.target.dataset.field === 'email') this.signerEmail = event.target.value;
        if (event.target.dataset.field === 'name') this.signerName = event.target.value;
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}