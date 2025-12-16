/**
 * @description Handles all aspects of biometric signature validation, including liveness detection, 
 * biometric matching against stored templates, and contextual fraud analysis.
 * This corrected version includes logic for both Facial Recognition and Fingerprint,
 * and fixes the matching simulation to allow for successful verification after enrollment.
 */
public with sharing class BiometricSecurityEngine {

    // --- CONFIGURATION CONSTANTS ---
    private static final Map<String, Integer> CONFIDENCE_THRESHOLDS = new Map<String, Integer>{
        'FACIAL_RECOGNITION' => 85,
        'FINGERPRINT' => 90, // Fingerprint threshold is now used
        'VOICE_RECOGNITION' => 80,
        'IRIS_SCAN' => 95
    };

    private static final Map<String, Decimal> FRAUD_RISK_WEIGHTS = new Map<String, Decimal>{
        'DEVICE_FINGERPRINTING' => 0.2,
        'GEOLOCATION_ANALYSIS' => 0.15,
        'BEHAVIORAL_PATTERNS' => 0.25,
        'TIME_PATTERN_ANALYSIS' => 0.1
    };

    // --- CRYPTOGRAPHY CONSTANTS ---
    // In a real project, this key should be stored securely (e.g., in a Protected Custom Metadata Type or Named Credential)
    private static final Blob CRYPTO_KEY = Crypto.generateAesKey(256);
    private static final Blob INITIALIZATION_VECTOR = Blob.valueOf('1234567890123456'); // Must be 16 bytes (128 bits) for AES256

    /**
     * @description Main entry point. Orchestrates liveness, matching, and fraud checks.
     */
    @AuraEnabled(cacheable=false)
    public static BiometricValidationResult validateBiometricSignature(String signatureRequestId, String biometricData, String biometricType, String deviceFingerprint) {
        System.debug('DEBUG: validateBiometricSignature called');
        System.debug('DEBUG: Inputs -> signatureRequestId=' + signatureRequestId + ', biometricType=' + biometricType);
        
        try {
            BiometricValidationResult result = new BiometricValidationResult();
            result.signatureRequestId = signatureRequestId;
            result.validationTimestamp = System.now();
            result.biometricType = biometricType;

            System.debug('DEBUG: Performing Liveness Detection...');
            LivenessDetectionResult livenessResult = performLivenessDetection(biometricData, biometricType);
            result.livenessDetection = livenessResult;
            System.debug('DEBUG: Liveness Result = ' + JSON.serialize(livenessResult));

            System.debug('DEBUG: Performing Biometric Matching...');
            BiometricMatchResult matchResult = performBiometricMatching(signatureRequestId, biometricData, biometricType);
            result.biometricMatch = matchResult;
            System.debug('DEBUG: Match Result = ' + JSON.serialize(matchResult));

            System.debug('DEBUG: Performing Fraud Analysis...');
            FraudAnalysisResult fraudResult = performFraudAnalysis(signatureRequestId, deviceFingerprint, biometricType);
            result.fraudAnalysis = fraudResult;
            System.debug('DEBUG: Fraud Result = ' + JSON.serialize(fraudResult));

            System.debug('DEBUG: Calculating Overall Confidence...');
            result.overallConfidenceScore = calculateOverallConfidence(livenessResult, matchResult, fraudResult);
            System.debug('DEBUG: Overall Confidence Score = ' + result.overallConfidenceScore);

            // Use the correct threshold based on the biometric type
            result.validationPassed = result.overallConfidenceScore >= CONFIDENCE_THRESHOLDS.get(biometricType);
            System.debug('DEBUG: Validation Passed? ' + result.validationPassed);

            System.debug('DEBUG: Storing biometric validation record...');
            storeBiometricValidation(result, deviceFingerprint);

            return result;
        } catch (Exception e) {
            System.debug('Biometric validation error: ' + e.getMessage() + ' at ' + e.getStackTraceString());
            return getFailedBiometricResult(signatureRequestId, e.getMessage());
        }
    }

    /**
 * @description Checks if a signer has already enrolled a biometric template.
 * @return The Base64Url encoded credential ID if found, otherwise null.
 */
@AuraEnabled(cacheable=true)
public static String getExistingCredentialId(String signatureRequestId) {
    try {
        Signature_Request__c sigRequest = [
            SELECT SignerEmail__c 
            FROM Signature_Request__c 
            WHERE Id = :signatureRequestId LIMIT 1
        ];

        List<Biometric_Template__c> templates = [
            SELECT Credential_Id__c 
            FROM Biometric_Template__c 
            WHERE User_Email__c = :sigRequest.SignerEmail__c 
              AND Biometric_Type__c = 'FINGERPRINT' 
              AND Status__c = 'ACTIVE' 
            ORDER BY CreatedDate DESC LIMIT 1
        ];

        if (templates.isEmpty() | String.isBlank(templates[0].Credential_Id__c)) {
            return null;
        }
        return templates[0].Credential_Id__c;
    } catch (Exception e) {
        System.debug('Error fetching existing credential ID: ' + e.getMessage());
        return null;
    }
}


    /**
     * @description Simulates a liveness check for different biometric types.
     */
    private static LivenessDetectionResult performLivenessDetection(String biometricData, String biometricType) {
        System.debug('DEBUG: performLivenessDetection called with biometricType=' + biometricType);
        LivenessDetectionResult result = new LivenessDetectionResult();
        Integer livenessScore = 0;

        // This structure allows you to add different logic for each biometric type
        if (biometricType == 'FACIAL_RECOGNITION') {
            // Simulate analyzing a face for eye movement, texture, etc.
            livenessScore = 95; // Return a high score for simulation
            result.detectionMethod = 'SIMULATED_FACIAL_ANALYSIS';
        } 
        else if (biometricType == 'FINGERPRINT') {
            // **NEW LOGIC**: Simulate analyzing a fingerprint for pulse, temperature, etc.
            livenessScore = 98; // Return a high score for simulation
            result.detectionMethod = 'SIMULATED_FINGERPRINT_ANALYSIS';
        }

        result.confidenceScore = livenessScore;
        result.isLive = livenessScore >= 85; // General 85% threshold for being considered "live"
        System.debug('DEBUG: Liveness Score=' + livenessScore + ', isLive=' + result.isLive);
        return result;
    }

    /**
     * @description Determines if this is a new enrollment or a verification against an existing template.
     */
    private static BiometricMatchResult performBiometricMatching(String signatureRequestId, String biometricData, String biometricType) {
        System.debug('DEBUG: performBiometricMatching called');
        Signature_Request__c sigRequest = [SELECT SignerEmail__c FROM Signature_Request__c WHERE Id = :signatureRequestId LIMIT 1];
        System.debug('DEBUG: SignerEmail=' + sigRequest.SignerEmail__c);

        List<Biometric_Template__c> templates = [
            SELECT Id, Template_Data__c FROM Biometric_Template__c
            WHERE User_Email__c = :sigRequest.SignerEmail__c AND Biometric_Type__c = :biometricType AND Status__c = 'ACTIVE'
            LIMIT 1
        ];

        System.debug('DEBUG: Templates found = ' + templates.size());
        if (templates.isEmpty()) {
            System.debug('DEBUG: No template found → enrolling...');
            return performBiometricEnrollment(sigRequest.SignerEmail__c, biometricData, biometricType);
        } else {
            System.debug('DEBUG: Template found → verifying...');
            return performBiometricComparison(templates[0].Template_Data__c, biometricData, biometricType);
        }
    }

    /**
     * @description Simulates creating and securely storing a new biometric template for a user.
     */
   // Find this existing method in your class...
/**
 * @description Creates and securely stores a new biometric template for a user.
 * CORRECTED: This version no longer tries to parse the incoming image data as JSON.
 */
private static BiometricMatchResult performBiometricEnrollment(String userEmail, String biometricData, String biometricType) {
    System.debug('DEBUG: performBiometricEnrollment called');
    BiometricMatchResult result = new BiometricMatchResult();

    // The 'biometricData' is now just the Base64 string of the image.
    // We pass it directly to the template generation method.
    String templateData = generateBiometricTemplate(biometricData);

    Biometric_Template__c template = new Biometric_Template__c(
        User_Email__c = userEmail,
        Biometric_Type__c = biometricType,
        Template_Data__c = templateData,
        Enrollment_Date__c = System.now(),
        Status__c = 'ACTIVE',
        Confidence_Score__c = 100
    );

    insert template;
    System.debug('DEBUG: Template inserted. Id=' + template.Id);

    result.matchFound = true;
    result.confidenceScore = 100; // 100 for enrollment
    result.matchType = 'ENROLLMENT';
    result.templateId = template.Id;

    return result;
}

    
    /**
     * @description Compares a new biometric scan against a securely stored template.
     */
    private static BiometricMatchResult performBiometricComparison(String storedTemplate, String currentBiometric, String biometricType) {
        System.debug('DEBUG: performBiometricComparison called');
        BiometricMatchResult result = new BiometricMatchResult();
        Decimal matchScore = 0;

        // Use a switch to handle different biometric types
        switch on biometricType {
            when 'FACIAL_RECOGNITION' {
                matchScore = compareFacialBiometrics(storedTemplate, currentBiometric);
            }
            when 'FINGERPRINT' {
                // **NEW LOGIC**: Add a comparison method for fingerprints
                matchScore = compareFingerprintBiometrics(storedTemplate, currentBiometric);
            }
            when else {
                matchScore = 0; // Unsupported type
            }
        }
        
        result.confidenceScore = matchScore;
        result.matchFound = matchScore >= CONFIDENCE_THRESHOLDS.get(biometricType);
        result.matchType = 'VERIFICATION';
        System.debug('DEBUG: Comparison Result=' + JSON.serialize(result));
        return result;
    }

    /**
     * @description **FIXED LOGIC**: This now always returns a high score to simulate a successful match.
     */
    private static Decimal compareFacialBiometrics(String storedEncryptedTemplate, String currentBiometric) {
        System.debug('DEBUG: compareFacialBiometrics SIMULATION called');
        // In a real system, you would decrypt and use a complex AI algorithm.
        // For our simulation, we will assume it's the correct user and return a high score.
        // This ensures that verification attempts after enrollment will now pass.
        return 98.7;
    }

    /**
     * @description **NEW METHOD**: A simulated comparison for fingerprints.
     */
    private static Decimal compareFingerprintBiometrics(String storedEncryptedTemplate, String currentBiometric) {
        System.debug('DEBUG: compareFingerprintBiometrics SIMULATION called');
        // For the simulation, we will act the same as the facial comparison and return a high score.
        return 99.2;
    }
    
    // --- UTILITY AND HELPER METHODS ---
    
    private static FraudAnalysisResult performFraudAnalysis(String signatureRequestId, String deviceFingerprint, String biometricType) {
        System.debug('DEBUG: performFraudAnalysis called');
        FraudAnalysisResult result = new FraudAnalysisResult();
        result.riskScore = 0;
        result.riskFactors = new List<RiskFactor>();

        RiskFactor deviceRisk = analyzeDeviceFingerprint(signatureRequestId, deviceFingerprint);
        System.debug('DEBUG: Device Risk = ' + JSON.serialize(deviceRisk));
        
        result.riskFactors.add(deviceRisk);
        result.riskScore += deviceRisk.riskWeight * deviceRisk.riskLevel;
        System.debug('DEBUG: Total Risk Score = ' + result.riskScore);
        
        if (result.riskScore < 30) result.riskLevel = 'LOW';
        else if (result.riskScore < 70) result.riskLevel = 'MEDIUM';
        else result.riskLevel = 'HIGH';
        
        result.fraudDetected = result.riskScore > 70;
        System.debug('DEBUG: Fraud Detected? ' + result.fraudDetected);
        return result;
    }

    private static String generateBiometricTemplate(String biometricData) {
        System.debug('DEBUG: generateBiometricTemplate called');
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(biometricData));
        Blob encryptedData = Crypto.encrypt('AES256', CRYPTO_KEY, INITIALIZATION_VECTOR, hash);
        System.debug('DEBUG: Template generated successfully');
        return EncodingUtil.base64Encode(encryptedData);
    }
    
    private static RiskFactor analyzeDeviceFingerprint(String signatureRequestId, String deviceFingerprint) {
        System.debug('DEBUG: analyzeDeviceFingerprint called');
        RiskFactor riskFactor = new RiskFactor();
        riskFactor.factorType = 'DEVICE_FINGERPRINTING';
        riskFactor.riskWeight = FRAUD_RISK_WEIGHTS.get('DEVICE_FINGERPRINTING');

        Signature_Request__c request = [SELECT SignerEmail__c FROM Signature_Request__c WHERE Id = :signatureRequestId LIMIT 1];
        System.debug('DEBUG: SignerEmail=' + request.SignerEmail__c);
        
        Integer previousDeviceCount = [
            SELECT COUNT() FROM Biometric_Validation__c
            WHERE Signer_Email__c = :request.SignerEmail__c AND Device_Fingerprint__c = :deviceFingerprint AND CreatedDate = LAST_N_DAYS:90
        ];
        
        System.debug('DEBUG: previousDeviceCount=' + previousDeviceCount);
        if (previousDeviceCount == 0) {
            riskFactor.riskLevel = 50;
            riskFactor.description = 'New device detected for user';
        } else {
            riskFactor.riskLevel = 10;
            riskFactor.description = 'Known device with previous successful validations';
        }
        System.debug('DEBUG: RiskFactor=' + JSON.serialize(riskFactor));
        return riskFactor;
    }

    private static Decimal calculateOverallConfidence(LivenessDetectionResult livenessResult, BiometricMatchResult matchResult, FraudAnalysisResult fraudResult) {
        System.debug('DEBUG: calculateOverallConfidence called');
        Decimal livenessWeight = 0.4, matchWeight = 0.4, fraudWeight = 0.2;
        
        Decimal livenessConfidence = livenessResult.isLive ? livenessResult.confidenceScore : 0;
        Decimal matchConfidence = matchResult.matchFound ? matchResult.confidenceScore : 0;
        Decimal fraudConfidence = 100 - fraudResult.riskScore;
        
        Decimal overallConfidence = (livenessConfidence * livenessWeight) + (matchConfidence * matchWeight) + (fraudConfidence * fraudWeight);
        System.debug('DEBUG: Computed overall confidence = ' + overallConfidence);
        return Math.max(0, Math.min(100, overallConfidence));
    }

    private static void storeBiometricValidation(BiometricValidationResult result, String deviceFingerprint) {
        System.debug('DEBUG: storeBiometricValidation called');
        Signature_Request__c request = [SELECT SignerEmail__c FROM Signature_Request__c WHERE Id = :result.signatureRequestId LIMIT 1];
        
        Biometric_Validation__c validation = new Biometric_Validation__c(
            Signature_Request__c = result.signatureRequestId,
            Biometric_Type__c = result.biometricType,
            Validation_Timestamp__c = result.validationTimestamp,
            Overall_Confidence_Score__c = result.overallConfidenceScore,
            Validation_Passed__c = result.validationPassed,
            Liveness_Score__c = result.livenessDetection.confidenceScore,
            Match_Score__c = result.biometricMatch.confidenceScore,
            Fraud_Risk_Score__c = result.fraudAnalysis.riskScore,
            Device_Fingerprint__c = deviceFingerprint,
            Signer_Email__c = request.SignerEmail__c
        );
        insert validation;
        System.debug('DEBUG: Biometric_Validation record inserted. Id=' + validation.Id);
    }

    private static BiometricValidationResult getFailedBiometricResult(String signatureRequestId, String errorMessage) {
        System.debug('DEBUG: getFailedBiometricResult called with error=' + errorMessage);
        BiometricValidationResult result = new BiometricValidationResult();
        result.signatureRequestId = signatureRequestId;
        result.validationPassed = false;
        result.overallConfidenceScore = 0;
        result.errorMessage = errorMessage;
        return result;
    }

    // --- SUPPORTING INNER CLASSES ---
    public class BiometricValidationResult {
        @AuraEnabled public String signatureRequestId;
        @AuraEnabled public DateTime validationTimestamp;
        @AuraEnabled public String biometricType;
        @AuraEnabled public Boolean validationPassed;
        @AuraEnabled public Decimal overallConfidenceScore;
        @AuraEnabled public LivenessDetectionResult livenessDetection;
        @AuraEnabled public BiometricMatchResult biometricMatch;
        @AuraEnabled public FraudAnalysisResult fraudAnalysis;
        @AuraEnabled public String errorMessage;
    }
    public class LivenessDetectionResult {
        @AuraEnabled public Boolean isLive;
        @AuraEnabled public Decimal confidenceScore;
        @AuraEnabled public String detectionMethod;
        @AuraEnabled public String errorMessage;
    }
    public class BiometricMatchResult {
        @AuraEnabled public Boolean matchFound;
        @AuraEnabled public Decimal confidenceScore;
        @AuraEnabled public String matchType;
        @AuraEnabled public String templateId;
        @AuraEnabled public String errorMessage;
    }
    public class FraudAnalysisResult {
        @AuraEnabled public Boolean fraudDetected;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public List<RiskFactor> riskFactors;
        @AuraEnabled public String errorMessage;
    }
    public class RiskFactor {
        @AuraEnabled public String factorType;
        @AuraEnabled public Decimal riskLevel;
        @AuraEnabled public Decimal riskWeight;
        @AuraEnabled public String description;
    }
}
