public with sharing class AdvancedSecurityEngine {
    private static final Map<String, Integer> SECURITY_RISK_WEIGHTS = new Map<String, Integer>{ 'LOCATION_ANOMALY' => 25, 'DEVICE_FINGERPRINT_MISMATCH' => 20, 'VELOCITY_ANOMALY' => 30, 'BEHAVIORAL_ANOMALY' => 15, 'TIME_ANOMALY' => 10 };

    @AuraEnabled(cacheable=false)
    public static SecurityAssessmentResult performSecurityAssessment(String signatureRequestId) {
        // --- [DEBUG] --- Start of the assessment process
        System.debug('--- [AdvancedSecurityEngine] START: Assessing Signature Request ID: ' + signatureRequestId + ' ---');

        if (String.isBlank(signatureRequestId)) {
            throw new AuraHandledException('Signature Request ID is required for security assessment.');
        }

        SecurityAssessmentResult assessment = new SecurityAssessmentResult();
        assessment.signatureRequestId = signatureRequestId;
        assessment.assessmentTimestamp = System.now();
        assessment.riskFactors = new List<RiskFactor>();
        assessment.totalRiskScore = 0;

        try {
            Signature_Request__c request = [ SELECT Id, SignerEmail__c, SigningLocation__c, DeviceFingerprint__c, CreatedDate, Time_To_Complete_Hours__c, SignatureMethod__c, Session_Duration_Minutes__c FROM Signature_Request__c WHERE Id = :signatureRequestId LIMIT 1 ];
            System.debug('[AdvancedSecurityEngine] Assessing Request Data: Location=' + request.SigningLocation__c + ', Signing Time=' + request.Time_To_Complete_Hours__c);

            // --- [DEBUG] --- Log score from each assessment step
            RiskFactor locationRisk = assessLocationRisk(request);
            System.debug('[AdvancedSecurityEngine] Location Risk Score: ' + locationRisk.riskLevel);
            if (locationRisk.riskLevel > 0) assessment.riskFactors.add(locationRisk);

            RiskFactor deviceRisk = assessDeviceRisk(request);
            System.debug('[AdvancedSecurityEngine] Device Risk Score: ' + deviceRisk.riskLevel);
            if (deviceRisk.riskLevel > 0) assessment.riskFactors.add(deviceRisk);

            RiskFactor velocityRisk = assessVelocityRisk(request);
            System.debug('[AdvancedSecurityEngine] Velocity Risk Score: ' + velocityRisk.riskLevel);
            if (velocityRisk.riskLevel > 0) assessment.riskFactors.add(velocityRisk);

            RiskFactor behavioralRisk = assessBehavioralRisk(request);
            System.debug('[AdvancedSecurityEngine] Behavioral Risk Score: ' + behavioralRisk.riskLevel);
            if (behavioralRisk.riskLevel > 0) assessment.riskFactors.add(behavioralRisk);

            RiskFactor timeRisk = assessTimeAnomalies(request);
            System.debug('[AdvancedSecurityEngine] Time Risk Score: ' + timeRisk.riskLevel);
            if (timeRisk.riskLevel > 0) assessment.riskFactors.add(timeRisk);

            // Sum up scores
            assessment.totalRiskScore = locationRisk.riskLevel + deviceRisk.riskLevel + velocityRisk.riskLevel + behavioralRisk.riskLevel + timeRisk.riskLevel;
            System.debug('[AdvancedSecurityEngine] Final Calculated Risk Score: ' + assessment.totalRiskScore);

            // Finalize
            assessment.riskLevel = determineRiskLevel(assessment.totalRiskScore);
            System.debug('[AdvancedSecurityEngine] Final Calculated Risk Level: ' + assessment.riskLevel);

            assessment.recommendations = generateSecurityRecommendations(assessment);
            assessment.success = true;

        } catch (Exception e) {
            assessment.success = false;
            assessment.errorMessage = 'Failed to perform security assessment: ' + e.getMessage();
            // --- [DEBUG] --- This will catch any hidden errors
            System.debug('--- [AdvancedSecurityEngine] FATAL ERROR: ' + e.getMessage() + ' ---');
            System.debug('[AdvancedSecurityEngine] Stack Trace: ' + e.getStackTraceString());
        }

        System.debug('--- [AdvancedSecurityEngine] END: Assessment complete. ---');
        return assessment;
    }

    // --- All other private helper methods remain unchanged ---
  private static RiskFactor assessLocationRisk(Signature_Request__c request) {
    RiskFactor factor = new RiskFactor('LOCATION_ANOMALY', 0);
    try {
        List<AggregateResult> locationHistory = [
            SELECT SigningLocation__c, COUNT(Id) locationCount
            FROM Signature_Request__c
            WHERE SignerEmail__c = :request.SignerEmail__c
                AND SigningLocation__c != null
                AND CreatedDate >= LAST_N_DAYS:90
            GROUP BY SigningLocation__c
        ];

        boolean isKnownLocation = false;

        if (request.SigningLocation__c != null) {
            for (AggregateResult loc : locationHistory) {
                String historicalLocation = (String) loc.get('SigningLocation__c');
                if (historicalLocation.equals(request.SigningLocation__c)) {
                    isKnownLocation = true;
                    break;
                }
            }
        }

        if (!isKnownLocation && !locationHistory.isEmpty()) {
            factor.riskLevel = SECURITY_RISK_WEIGHTS.get('LOCATION_ANOMALY');
            factor.description = 'Signing from new/unknown geographic location.';
        }

    } catch (Exception e) {
        factor.riskLevel = 5;
        factor.description = 'Could not verify location due to a system error.';
    }
    return factor;
}

private static RiskFactor assessDeviceRisk(Signature_Request__c request) {
    RiskFactor factor = new RiskFactor('DEVICE_FINGERPRINT_MISMATCH', 0);
    try {
        List<AggregateResult> deviceHistory = [
            SELECT DeviceFingerprint__c, COUNT(Id) usageCount
            FROM Signature_Request__c
            WHERE SignerEmail__c = :request.SignerEmail__c
                AND DeviceFingerprint__c != null
                AND CreatedDate >= LAST_N_DAYS:180
            GROUP BY DeviceFingerprint__c
            HAVING COUNT(Id) > 1
        ];

        boolean isKnownDevice = false;

        if (request.DeviceFingerprint__c != null) {
            for (AggregateResult dev : deviceHistory) {
                if (request.DeviceFingerprint__c.equals((String) dev.get('DeviceFingerprint__c'))) {
                    isKnownDevice = true;
                    break;
                }
            }
        }

        if (!isKnownDevice && !deviceHistory.isEmpty()) {
            factor.riskLevel = SECURITY_RISK_WEIGHTS.get('DEVICE_FINGERPRINT_MISMATCH');
            factor.description = 'Signing from an unrecognized device.';
        }

    } catch (Exception e) {
        factor.riskLevel = 5;
        factor.description = 'Could not verify device due to a system error.';
    }
    return factor;
}

private static RiskFactor assessVelocityRisk(Signature_Request__c request) {
    RiskFactor factor = new RiskFactor('VELOCITY_ANOMALY', 0);
    try {
        Datetime twentyFourHoursAgo = System.now().addHours(-24);

        Integer recentCount = [
            SELECT COUNT()
            FROM Signature_Request__c
            WHERE SignerEmail__c = :request.SignerEmail__c
                AND CreatedDate >= :twentyFourHoursAgo
        ];

        if (recentCount > 10) {
            factor.riskLevel = SECURITY_RISK_WEIGHTS.get('VELOCITY_ANOMALY');
            factor.description =
                'Unusually high signing velocity detected (' + recentCount + ' in 24h).';
        }

    } catch (Exception e) {
        factor.riskLevel = 5;
        factor.description = 'Could not assess signing velocity due to a system error.';
    }
    return factor;
}

private static RiskFactor assessBehavioralRisk(Signature_Request__c request) {
    RiskFactor factor = new RiskFactor('BEHAVIORAL_ANOMALY', 0);
    try {
        AggregateResult[] behaviorPatterns = [
            SELECT AVG(Time_To_Complete_Hours__c) avgCompletion
            FROM Signature_Request__c
            WHERE SignerEmail__c = :request.SignerEmail__c
                AND Status__c = 'Completed'
                AND Time_To_Complete_Hours__c != null
        ];

        Decimal avgCompletion = 0;

        if (!behaviorPatterns.isEmpty() &&
            behaviorPatterns[0].get('avgCompletion') != null) {
            avgCompletion = (Decimal) behaviorPatterns[0].get('avgCompletion');
        }

        if (request.Time_To_Complete_Hours__c != null &&
            avgCompletion > 0 &&
            request.Time_To_Complete_Hours__c < (avgCompletion * 0.1)) {

            factor.riskLevel = SECURITY_RISK_WEIGHTS.get('BEHAVIORAL_ANOMALY');
            factor.description =
                'Signature completed significantly faster than user average.';
        }

    } catch (Exception e) {
        factor.riskLevel = 5;
        factor.description = 'Could not analyze behavioral patterns due to a system error.';
    }
    return factor;
}

private static RiskFactor assessTimeAnomalies(Signature_Request__c request) {
    RiskFactor factor = new RiskFactor('TIME_ANOMALY', 0);

    Integer signingHour = request.CreatedDate.hour();

    if (signingHour < 5 || signingHour >= 23) {
        factor.riskLevel = SECURITY_RISK_WEIGHTS.get('TIME_ANOMALY');
        factor.description = 'Signature occurred during unusual late-night hours.';
    }
    return factor;
}

private static String determineRiskLevel(Integer score) {
    if (score >= 70) return 'CRITICAL';
    if (score >= 40) return 'HIGH';
    if (score >= 20) return 'MEDIUM';
    return 'LOW';
}

private static List<String> generateSecurityRecommendations(SecurityAssessmentResult assessment) {
    List<String> recommendations = new List<String>();

    switch on assessment.riskLevel {
        when 'CRITICAL' {
            recommendations.add('IMMEDIATE ACTION: Block signature request and investigate.');
            recommendations.add('Require multi-factor authentication verification.');
            recommendations.add('Flag user account for enhanced monitoring.');
        }
        when 'HIGH' {
            recommendations.add('Require additional authentication before processing.');
            recommendations.add('Review and verify signer identity manually.');
            recommendations.add('Enable enhanced audit logging for this user.');
        }
        when 'MEDIUM' {
            recommendations.add('Consider sending an email verification to the signer.');
            recommendations.add('Implement additional monitoring for this session.');
        }
        when 'LOW' {
            recommendations.add('No immediate action required. Continue standard monitoring.');
        }
    }

    return recommendations;
}

public class SecurityAssessmentResult {
    @AuraEnabled public String signatureRequestId { get; set; }
    @AuraEnabled public Datetime assessmentTimestamp { get; set; }
    @AuraEnabled public List<RiskFactor> riskFactors { get; set; }
    @AuraEnabled public Integer totalRiskScore { get; set; }
    @AuraEnabled public String riskLevel { get; set; }
    @AuraEnabled public List<String> recommendations { get; set; }
    @AuraEnabled public Boolean success { get; set; }
    @AuraEnabled public String errorMessage { get; set; }
}

public class RiskFactor {
    @AuraEnabled public String factorType { get; set; }
    @AuraEnabled public Integer riskLevel { get; set; }
    @AuraEnabled public String description { get; set; }
    @AuraEnabled public String evidence { get; set; }

    public RiskFactor(String type, Integer level) {
        this.factorType = type;
        this.riskLevel = level;
        this.description = '';
        this.evidence = '';
    }
}

}
