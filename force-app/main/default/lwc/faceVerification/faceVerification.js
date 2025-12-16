import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import detectFaces from '@salesforce/apex/FacePlusPlusService.detectFaces';
import compareFaces from '@salesforce/apex/FacePlusPlusService.compareFaces';
import saveVerifiedFaceImage from '@salesforce/apex/FacePlusPlusService.saveVerifiedFaceImage';


export default class FaceVerification extends LightningElement {

    @track isCameraInitialized = false;
    @track isVerifying = false;
    @track isVerified = false;


    cameraStream;
    videoElement;
    isVideoPlaying = false;

    // 🔴 TEMP: hard-coded registered face token (PASTE REAL TOKEN)
    REGISTERED_FACE_TOKEN = 'e25a2b67865a1db76f1ffe19f76cf1ed';

    initializeCamera() {
        navigator.mediaDevices.getUserMedia({ video: true })
            .then(stream => {
                console.log('[CAMERA] Access granted');
                this.cameraStream = stream;
                this.isCameraInitialized = true;
            })
            .catch(error => {
                console.error('[CAMERA] Error:', error);
                this.showToast('Camera Error', error.message, 'error');
            });
    }

    renderedCallback() {
        if (this.isCameraInitialized && !this.isVideoPlaying) {
            this.videoElement = this.template.querySelector('video[data-id="video"]');
            if (this.videoElement) {
                this.videoElement.srcObject = this.cameraStream;
                this.isVideoPlaying = true;
                console.log('[VIDEO] Stream attached');
            }
        }
    }
get isVerifyDisabled() {
    return this.isVerifying || this.isVerified;
}

    async captureAndVerify() {

        if (
        !this.videoElement ||
        this.videoElement.videoWidth === 0 ||
        this.videoElement.videoHeight === 0
    ) {
        console.warn('[VIDEO] Not ready yet. Please wait a moment.');
        return;
    }
        this.isVerifying = true;
        console.log('--- FACE VERIFICATION START ---');

        const canvas = this.template.querySelector('canvas[data-id="canvas"]');
        canvas.height = this.videoElement.videoHeight;
        canvas.width = this.videoElement.videoWidth;

        const ctx = canvas.getContext('2d');
        ctx.drawImage(this.videoElement, 0, 0, canvas.width, canvas.height);
        const imageBase64 = canvas.toDataURL('image/jpeg').split(',')[1];

        try {
            // 🔹 Detect LIVE face
            console.log('[DETECT] Calling Face++ detect for live image...');
            const detectResult = await detectFaces({ imageBase64 });

            console.log('[DETECT RESULT]', JSON.stringify(detectResult));

            if (!detectResult || detectResult.face_num === 0) {
                this.showToast('Failed', 'No face detected', 'error');
                return;
            }

            const liveFaceToken = detectResult.faces[0].face_token;

            console.log('[TOKENS]');
            console.log('Registered Token:', this.REGISTERED_FACE_TOKEN);
            console.log('Live Token:', liveFaceToken);

            // 🔹 Compare with registered face
            console.log('[COMPARE] Calling Face++ compare...');
            const compareResult = await compareFaces({
                faceToken1: this.REGISTERED_FACE_TOKEN,
                faceToken2: liveFaceToken
            });

            console.log('[COMPARE RESULT]');
            console.log('Confidence:', compareResult.confidence);
            console.log('Threshold e3:', compareResult.thresholds.e3);
            console.log('Threshold e4:', compareResult.thresholds.e4);
            console.log('Threshold e5:', compareResult.thresholds.e5);

            // 🔒 STRICT CHECK FOR TESTING
            if (compareResult.confidence >= 85) {
                this.isVerified = true;
                // 🔐 SAVE THE VERIFIED IMAGE
    const contentVersionId = await saveVerifiedFaceImage({
        imageBase64: imageBase64
    });

    console.log('Verified face image saved. CV Id:', contentVersionId);

                console.log('[RESULT] FACE MATCHED');
                this.showToast('Success', 'Face verified successfully', 'success');

                this.dispatchEvent(
                    new CustomEvent('verificationcomplete', {
                        detail: { faceVerified: true }
                    })
                );
            } else {
                console.warn('[RESULT] FACE MISMATCH');
                this.showToast(
                    'Verification Failed',
                    'Face does not match registered photo',
                    'error'
                );
            }

        } catch (error) {
            console.error('[ERROR] Face verification failed:', error);
            this.showToast('Error', 'Face verification failed', 'error');
        } finally {
            console.log('--- FACE VERIFICATION END ---');
            this.isVerifying = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
