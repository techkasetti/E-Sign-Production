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
            // Assess all relevant threats
            BehavioralThreatResult behavioralResult = assessBehavioralThreats(userContext, signatureRequestId);
            result.behavioralThreatScore = behavioralResult.threatScore;
            result.detectedThreats.addAll(behavioralResult.threats);
            System.debug('[ThreatAssessmentEngine] Behavioral Threat Score calculated: ' + result.behavioralThreatScore);

            // Calculate the final score based on all assessments
            result = calculateOverallThreatScore(result);
            System.debug('[ThreatAssessmentEngine] Overall Threat Score calculated: ' + result.overallThreatScore);

            // Determine the final threat level
            result = determineThreatLevel(result);
            System.debug('[ThreatAssessmentEngine] Threat Level determined: ' + result.threatLevel);

            result = generateThreatRecommendations(result);

            // Check if the final score meets the threshold for logging a threat
            System.debug('[ThreatAssessmentEngine] Checking if score ' + result.overallThreatScore + ' is >= 0.4');
            if (result.overallThreatScore >= 0.4) { // Using a lower threshold to catch MEDIUM and HIGH
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

    private static BehavioralThreatResult assessBehavioralThreats(String userContext, String signatureRequestId) {
        BehavioralThreatResult result = new BehavioralThreatResult();
        if (String.isBlank(userContext)) {
            System.debug('[ThreatAssessmentEngine] assessBehavioralThreats: userContext is blank. Defaulting to low risk.');
            result.threatScore = 0.1; 
            return result;
        }

        Map<String, Object> context = (Map<String, Object>) JSON.deserializeUntyped(userContext);
        Boolean isAnomalous = context.containsKey('isAnomalous') ? (Boolean)context.get('isAnomalous') : false;
        System.debug('[ThreatAssessmentEngine] assessBehavioralThreats: isAnomalous flag from context is: ' + isAnomalous);

        if (isAnomalous) {
            result.threatScore = 0.9;
            result.threats.add(new ThreatIndicator('BEHAVIORAL_ANOMALY', 'Unusual user interaction patterns detected', 0.9, 'HIGH'));
        } else {
            result.threatScore = 0.1;
        }
        return result;
    }

    // *** CORRECTED SCORING LOGIC ***
    private static ThreatAssessmentResult calculateOverallThreatScore(ThreatAssessmentResult result) {
        // This now correctly assigns the score. In the future, you can add other scores here.
        result.overallThreatScore = result.behavioralThreatScore; 
        return result;
    }

    private static ThreatAssessmentResult determineThreatLevel(ThreatAssessmentResult result) {
        if (result.overallThreatScore >= 0.7) {
            result.threatLevel = 'HIGH';
            result.requiresImmediateAction = true;
        } else if (result.overallThreatScore >= 0.4) {
            result.threatLevel = 'MEDIUM';
            result.requiresImmediateAction = false;
        } else {
            result.threatLevel = 'LOW';
            result.requiresImmediateAction = false;
        }
        return result;
    }

    // *** CORRECTED METHOD TO CREATE THE RIGHT OBJECT FOR YOUR DASHBOARD ***
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
                ThreatType__c = 'Behavioral Anomaly', // Example type
                RelatedRecordId__c = result.signatureRequestId,
                IsActive__c = true,
                LastSeen__c = Date.today()
            );

            System.debug('[ThreatAssessmentEngine] ATTEMPTING TO INSERT ThreatIntelligence__c: ' + JSON.serialize(threat));
            insert threat;
            System.debug('--- [ThreatAssessmentEngine] SUCCESS: ThreatIntelligence__c record inserted with ID: ' + threat.Id + ' ---');

        } catch (Exception e) {
            System.debug('--- [ThreatAssessmentEngine] FATAL DML ERROR: Failed to insert ThreatIntelligence__c. Reason: ' + e.getMessage() + ' ---');
            System.debug('[ThreatAssessmentEngine] DML Stack Trace: ' + e.getStackTraceString());
            throw e;
        }
    }

    // --- Helper and Fallback Methods (unchanged) ---
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

    // --- Inner Classes for Data Structure (unchanged) ---
    public class ThreatAssessmentResult { @AuraEnabled public String assessmentId; @AuraEnabled public String signatureRequestId; @AuraEnabled public DateTime timestamp; @AuraEnabled public Decimal overallThreatScore = 0; @AuraEnabled public String threatLevel; @AuraEnabled public Boolean requiresImmediateAction; @AuraEnabled public Decimal behavioralThreatScore = 0; @AuraEnabled public List<ThreatIndicator> detectedThreats = new List<ThreatIndicator>(); @AuraEnabled public List<String> recommendations; }
    public class ThreatIndicator { public String type; public String description; public Decimal riskScore; public String severity; public ThreatIndicator(String type, String description, Decimal riskScore, String severity) { this.type = type; this.description = description; this.riskScore = riskScore; this.severity = severity; } }
    public class BehavioralThreatResult { public Decimal threatScore; public List<ThreatIndicator> threats = new List<ThreatIndicator>(); }
}
// ``` ### **Step 2: Run the Test One Last Time** 1. **Save** the updated class.
// 2. **Perform your fraud test again** (VPN on, sign quickly).
// 3. **Check the Dashboard.** It may now be populated. ### **Step 3: Verify with a Query** If the dashboard is still empty, let's confirm the record was created by running our original query again in the **Developer Console > Query Editor**: ```sql
// SELECT Id, RiskScore__c, RiskLevel__c, ThreatType__c, Description__c, CreatedDate FROM ThreatIntelligence__c ORDER BY CreatedDate DESC LIMIT 5
// ``` This time, you should see a new row with a `RiskLevel__c` of `HIGH` and a `RiskScore__c` of `90`. Once you confirm that the record is being created, we can be certain the backend is fixed, and any remaining issue would be with the dashboard's controller.
