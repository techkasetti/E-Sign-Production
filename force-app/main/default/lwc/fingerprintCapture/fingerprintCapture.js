import { LightningElement, api, track, wire } from 'lwc';
import validateBiometricSignature from '@salesforce/apex/BiometricSecurityEngine.validateBiometricSignature';
import getExistingCredentialId from '@salesforce/apex/BiometricSecurityEngine.getExistingCredentialId';

// Helper function to convert the Base64URL string from Apex to an ArrayBuffer for the WebAuthn API
function bufferDecode(value) {
    const s = window.atob(value.replace(/-/g, '+').replace(/_/g, '/'));
    const a = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i++) { a[i] = s.charCodeAt(i); }
    return a;
}

export default class FingerprintCapture extends LightningElement {
    @api recordId;
    @track isLoading = true;
    @track errorMessage;
    @track buttonLabel = 'Checking Status...';

    isEnrolled = false;
    credentialId;

    get isVerifyDisabled() {
        return this.isLoading;
    }
    
    // 1. When the component loads, check if the user is already enrolled
    @wire(getExistingCredentialId, { signatureRequestId: '$recordId' })
    wiredCredential({ error, data }) {
        if (data) {
            this.isEnrolled = true;
            this.credentialId = data; // Save the passkey ID from the server
            this.buttonLabel = 'Verify with Fingerprint';
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = 'Could not check enrollment status.';
            console.error('Error fetching credential ID:', error);
        } else {
            // No data and no error means no credential found
            this.isEnrolled = false;
            this.buttonLabel = 'Enroll Fingerprint';
        }
        this.isLoading = false;
    }

    connectedCallback() {
        if (!navigator.credentials || !navigator.credentials.get) {
            this.errorMessage = 'Fingerprint verification (WebAuthn) is not supported on this browser.';
            this.isLoading = false;
        }
    }

    // 2. This single click handler decides which flow to run
    async handleVerifyClick() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            if (this.isEnrolled) {
                // If ENROLLED, perform real-time verification (the 'get' flow)
                await this.performVerification();
            } else {
                // If NOT ENROLLED, perform one-time enrollment (the 'create' flow)
                await this.performEnrollment();
            }
            
            // If either flow succeeds, dispatch success event
            this.dispatchEvent(new CustomEvent('success'));

        } catch (error) {
            console.error('WebAuthn or Apex error:', error);
            if (error.name === 'NotAllowedError') {
                this.errorMessage = 'Verification was cancelled. Please try again.';
            } else {
                this.errorMessage = error.message || 'An unknown error occurred. Please ensure your device is set up correctly.';
            }
        } finally {
            this.isLoading = false;
        }
    }

    // 3. The ENROLLMENT flow (using navigator.credentials.create)
    async performEnrollment() {
        const publicKey = {
            challenge: crypto.getRandomValues(new Uint8Array(32)),
            rp: { name: 'KT E-Sign', id: window.location.hostname },
            user: {
                id: Uint8Array.from(String(this.recordId), c => c.charCodeAt(0)),
                name: 'signer-' + this.recordId,
                displayName: 'Signer ' + this.recordId
            },
            pubKeyCredParams: [{ type: 'public-key', alg: -7 }], // ES256
            authenticatorSelection: {
                authenticatorAttachment: 'platform',
                userVerification: 'required',
                residentKey: 'preferred'
            },
            timeout: 60000,
            attestation: 'none'
        };

        const credential = await navigator.credentials.create({ publicKey });

        const result = await validateBiometricSignature({
            signatureRequestId: this.recordId,
            biometricData: JSON.stringify(this.credentialToJSON(credential)), // Send full object
            biometricType: 'FINGERPRINT', // Your Apex logic handles routing based on template existence
            deviceFingerprint: 'SimulatedDeviceFingerprint123'
        });

        if (!result.validationPassed) {
            throw new Error(result.errorMessage || 'Enrollment failed on the server.');
        }
    }
    
    // 4. The VERIFICATION flow (using navigator.credentials.get)
    async performVerification() {
        const publicKey = {
            challenge: crypto.getRandomValues(new Uint8Array(32)),
            rpId: window.location.hostname,
            allowCredentials: [{
                type: 'public-key',
                id: bufferDecode(this.credentialId), // Use the REAL credential ID from the server
                transports: ['internal']
            }],
            userVerification: 'required',
            timeout: 60000
        };

        const credential = await navigator.credentials.get({ publicKey });

        const result = await validateBiometricSignature({
            signatureRequestId: this.recordId,
            biometricData: JSON.stringify(this.credentialToJSON(credential)),
            biometricType: 'FINGERPRINT',
            deviceFingerprint: 'SimulatedDeviceFingerprint123'
        });

        if (!result.validationPassed) {
            throw new Error(result.errorMessage || 'Verification failed on the server.');
        }
    }

    // Helper to convert ArrayBuffers to Base64URL for JSON serialization
    credentialToJSON(cred) {
        if (cred instanceof PublicKeyCredential) {
            const json = {
                id: cred.id,
                rawId: this.bufferEncode(cred.rawId),
                type: cred.type,
                response: {},
            };
            if (cred.response.attestationObject) {
                json.response.attestationObject = this.bufferEncode(cred.response.attestationObject);
            }
            if (cred.response.clientDataJSON) {
                json.response.clientDataJSON = this.bufferEncode(cred.response.clientDataJSON);
            }
            if (cred.response.signature) {
                json.response.signature = this.bufferEncode(cred.response.signature);
            }
            if (cred.response.userHandle) {
                json.response.userHandle = this.bufferEncode(cred.response.userHandle);
            }
            return json;
        }
        return cred;
    }

    bufferEncode(value) {
        return btoa(String.fromCharCode.apply(null, new Uint8Array(value)))
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=/g, '');
    }
}
