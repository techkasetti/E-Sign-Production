public with sharing class ThreatAssessmentEngine {
    // Defines the weight of each type of threat
    private static final Map<String, Decimal> THREAT_WEIGHTS = new Map<String, Decimal>{
        'BEHAVIORAL_ANOMALY' => 0.75,
        'LOCATION_ANOMALY' => 0.70,
        'VELOCITY_ANOMALY' => 0.65,
        'TIME_ANOMALY' => 0.60
    };

    @AuraEnabled(cacheable=false)
    public static ThreatAssessmentResult assessComprehensiveThreat(String signatureRequestId, String userContext, String systemContext, String networkContext) {
        System.debug('--- [ThreatAssessmentEngine] START: Assessing Signature Request ID: ' + signatureRequestId + ' ---');
        System.debug('[ThreatAssessmentEngine] Input userContext: ' + userContext);

        ThreatAssessmentResult result = new ThreatAssessmentResult();
        result.assessmentId = 'TA-' + System.now().getTime();
        result.signatureRequestId = signatureRequestId;
        result.timestamp = System.now();

        try {
            BehavioralThreatResult behavioralResult = assessBehavioralThreats(userContext, signatureRequestId);
            result.behavioralThreatScore = behavioralResult.threatScore;
            result.detectedThreats.addAll(behavioralResult.threats);
            System.debug('[ThreatAssessmentEngine] Behavioral Threat Score calculated: ' + result.behavioralThreatScore);

            result = calculateOverallThreatScore(result);
            System.debug('[ThreatAssessmentEngine] Overall Threat Score calculated: ' + result.overallThreatScore);

            result = determineThreatLevel(result);
            System.debug('[ThreatAssessmentEngine] Threat Level determined: ' + result.threatLevel);

            result = generateThreatRecommendations(result);

            System.debug('[ThreatAssessmentEngine] Checking if score ' + result.overallThreatScore + ' is >= 0.4');
            if (result.overallThreatScore >= 0.4) {
                System.debug('[ThreatAssessmentEngine] Threshold met. Proceeding to create ThreatIntelligence__c record.');
                createThreatIntelligenceRecord(result);
            } else {
                System.debug('[ThreatAssessmentEngine] INFO: Risk score is below threshold. No threat record will be created.');
            }

        } catch (Exception e) {
            System.debug('--- [ThreatAssessmentEngine] FATAL ERROR: ' + e.getMessage() + ' ---');
            System.debug('[ThreatAssessmentEngine] Stack Trace: ' + e.getStackTraceString());
            return createMaximumSecurityThreatResult(signatureRequestId, e.getMessage());
        }

        System.debug('--- [ThreatAssessmentEngine] END: Assessment complete. ---');
        return result;
    }

    // *** REWRITTEN TO HANDLE BOTH INTERNAL AND EXTERNAL USERS ***
    private static BehavioralThreatResult assessBehavioralThreats(String userContext, String signatureRequestId) {
        BehavioralThreatResult result = new BehavioralThreatResult();
        result.threatScore = 0.1; // Default to low base score

        if (String.isBlank(userContext)) {
            System.debug('[ThreatAssessmentEngine] assessBehavioralThreats: userContext is blank. Defaulting to low risk.');
            return result;
        }

        Map<String, Object> currentContext = (Map<String, Object>) JSON.deserializeUntyped(userContext);
        Decimal currentTimeToSign = (Decimal)currentContext.get('timeToSign');

        // Get signer email from the request
        Signature_Request__c request = [SELECT SignerEmail__c FROM Signature_Request__c WHERE Id = :signatureRequestId LIMIT 1];
        String signerEmail = request.SignerEmail__c;

        // Try to find an internal user first
        List<User> users = [SELECT Id FROM User WHERE Email = :signerEmail AND IsActive = true LIMIT 1];
        Id userId = null;
        if (!users.isEmpty()) {
            userId = users[0].Id;
        }

        // Query for historical behavior using either the User ID or the email address
        List<UserBehaviorMetrics__c> historyList = [
            SELECT Id, AverageTimeToSign__c, TotalSignatures__c
            FROM UserBehaviorMetrics__c
            WHERE (User__c = :userId AND User__c != null) OR (SignerEmail__c = :signerEmail)
            LIMIT 1
        ];

        if (historyList.isEmpty()) {
            // NEW USER/SIGNER: Create their first baseline record
            System.debug('[ThreatAssessmentEngine] No history found for signer. Creating baseline for email: ' + signerEmail);
            createBehavioralBaseline(userId, signerEmail, currentTimeToSign);
            result.threatScore = 0.1; // First signature is always considered low risk
        } else {
            // EXISTING USER/SIGNER: Compare the metrics
            UserBehaviorMetrics__c history = historyList[0];
            System.debug('[ThreatAssessmentEngine] Found history for signer. Comparing...');

            if (history.AverageTimeToSign__c != null && history.AverageTimeToSign__c > 0) {
                // ANOMALY CHECK: Is the signing time less than 20% of their average?
                if (currentTimeToSign < (history.AverageTimeToSign__c * 0.2)) {
                    result.threatScore = 0.9;
                    result.threats.add(new ThreatIndicator(
                        'BEHAVIORAL_ANOMALY',
                        'Completion time (' + currentTimeToSign + 's) is significantly faster than user average (' + history.AverageTimeToSign__c.setScale(1) + 's).',
                        0.9,
                        'HIGH'
                    ));
                }
            }
            
            // LEARN: If not a threat, update the history to make the engine smarter
            if (result.threatScore < 0.4) {
                updateBehaviorMetrics(history.Id, currentTimeToSign);
            }
        }

        return result;
    }
    
    // *** UPDATED TO SUPPORT BOTH IDENTIFIERS ***
    private static void createBehavioralBaseline(Id userId, String signerEmail, Decimal firstTimeToSign) {
        UserBehaviorMetrics__c newHistory = new UserBehaviorMetrics__c(
            User__c = userId, // This will be null for external users, which is correct
            SignerEmail__c = signerEmail,
            TotalSignatures__c = 1,
            AverageTimeToSign__c = firstTimeToSign
        );
        insert newHistory;
    }

    // No changes needed to this method
    @future
    public static void updateBehaviorMetrics(Id historyId, Decimal newTimeToSign) {
        UserBehaviorMetrics__c history = [SELECT Id, AverageTimeToSign__c, TotalSignatures__c FROM UserBehaviorMetrics__c WHERE Id = :historyId FOR UPDATE];
        Decimal oldTotalTime = (history.AverageTimeToSign__c != null ? history.AverageTimeToSign__c : 0) * (history.TotalSignatures__c != null ? history.TotalSignatures__c : 0);
        Decimal newTotalSignatures = (history.TotalSignatures__c != null ? history.TotalSignatures__c : 0) + 1;
        
        history.AverageTimeToSign__c = (oldTotalTime + newTimeToSign) / newTotalSignatures;
        history.TotalSignatures__c = newTotalSignatures;
        update history;
        System.debug('[ThreatAssessmentEngine] Updated behavior metrics for record: ' + history.Id);
    }
    
    private static ThreatAssessmentResult calculateOverallThreatScore(ThreatAssessmentResult result) {
        result.overallThreatScore = result.behavioralThreatScore;
        return result;
    }

    private static ThreatAssessmentResult determineThreatLevel(ThreatAssessmentResult result) {
        if (result.overallThreatScore >= 0.9) {
            result.threatLevel = 'CRITICAL';
            result.requiresImmediateAction = true;
        } else if (result.overallThreatScore >= 0.7) {
            result.threatLevel = 'HIGH';
            result.requiresImmediateAction = true;
        } else if (result.overallThreatScore >= 0.5) {
            result.threatLevel = 'MEDIUM';
            result.requiresImmediateAction = false;
        } else if (result.overallThreatScore >= 0.3) {
            result.threatLevel = 'LOW';
            result.requiresImmediateAction = false;
        } else {
            result.threatLevel = 'MINIMAL';
            result.requiresImmediateAction = false;
        }
        return result;
    }

    private static void createThreatIntelligenceRecord(ThreatAssessmentResult result) {
        try {
            String threatDescription = 'No specific threats detected.';
            if (!result.detectedThreats.isEmpty()) {
                threatDescription = result.detectedThreats[0].description;
            }
            ThreatIntelligence__c threat = new ThreatIntelligence__c(
                Description__c = threatDescription,
                RiskLevel__c = result.threatLevel,
                RiskScore__c = result.overallThreatScore * 100,
                ThreatType__c = 'Behavioral Anomaly',
                RelatedRecordId__c = result.signatureRequestId,
                IsActive__c = true,
                LastSeen__c = Date.today()
            );
            insert threat;
            System.debug('--- [ThreatAssessmentEngine] SUCCESS: ThreatIntelligence__c record inserted with ID: ' + threat.Id + ' ---');
        } catch (Exception e) {
            System.debug('--- [ThreatAssessmentEngine] FATAL DML ERROR: Failed to insert ThreatIntelligence__c. Reason: ' + e.getMessage() + ' ---');
            throw e;
        }
    }

    private static ThreatAssessmentResult createMaximumSecurityThreatResult(String signatureRequestId, String errorMessage) {
        ThreatAssessmentResult result = new ThreatAssessmentResult();
        result.overallThreatScore = 1.0;
        result.threatLevel = 'CRITICAL';
        result.requiresImmediateAction = true;
        return result;
    }

    private static ThreatAssessmentResult generateThreatRecommendations(ThreatAssessmentResult result) {
        result.recommendations = new List<String>();
        if (result.threatLevel == 'HIGH' || result.threatLevel == 'CRITICAL') {
            result.recommendations.add('IMMEDIATE REVIEW: Manual verification of signer identity is recommended.');
        }
        return result;
    }

    public class ThreatAssessmentResult {
        @AuraEnabled public String assessmentId;
        @AuraEnabled public String signatureRequestId;
        @AuraEnabled public DateTime timestamp;
        @AuraEnabled public Decimal overallThreatScore = 0;
        @AuraEnabled public String threatLevel;
        @AuraEnabled public Boolean requiresImmediateAction;
        @AuraEnabled public Decimal behavioralThreatScore = 0;
        @AuraEnabled public List<ThreatIndicator> detectedThreats = new List<ThreatIndicator>();
        @AuraEnabled public List<String> recommendations;
    }

    public class ThreatIndicator {
        public String type;
        public String description;
        public Decimal riskScore;
        public String severity;
        public ThreatIndicator(String type, String description, Decimal riskScore, String severity) {
            this.type = type;
            this.description = description;
            this.riskScore = riskScore;
            this.severity = severity;
        }
    }

    public class BehavioralThreatResult {
        public Decimal threatScore;
        public List<ThreatIndicator> threats = new List<ThreatIndicator>();
    }
}
