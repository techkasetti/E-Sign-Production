public with sharing class AdvancedSecurityEngine {

    /* =========================
     * Result Wrapper
     * ========================= */
    public class SecurityAssessmentResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Integer totalRiskScore { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public List<RiskFactor> riskFactors { get; set; }
    }

    public class RiskFactor {
        @AuraEnabled public String factorType { get; set; }
        @AuraEnabled public String description { get; set; }
    }

    /* =========================
     * Entry Point
     * ========================= */
    @AuraEnabled
    public static SecurityAssessmentResult performSecurityAssessment(String signatureRequestId) {

        SecurityAssessmentResult assessment = new SecurityAssessmentResult();
        assessment.success = true;
        assessment.totalRiskScore = 0;
        assessment.riskFactors = new List<RiskFactor>();

        try {
            /* --- Fetch current request --- */
            Signature_Request__c request = [
                SELECT Id,
                       SignerEmail__c,
                       IPAddress__c,
                       SigningLocation__c,
                       Time_To_Complete_Seconds__c,
                       CompletedDate__c,
                       Fraud_Rules_To_Run__c
                FROM Signature_Request__c
                WHERE Id = :signatureRequestId
                LIMIT 1
            ];

            String rulesToRun = request.Fraud_Rules_To_Run__c;

            /* --- Fetch history --- */
  List<Signature_Request__c> baselineList = [
    SELECT Id,
           IPAddress__c,
           SigningLocation__c,
           Time_To_Complete_Seconds__c,
           CompletedDate__c
    FROM Signature_Request__c
    WHERE SignerEmail__c = :request.SignerEmail__c
      AND Status__c = 'Signed'
      AND Id != :request.Id
    ORDER BY CreatedDate__c ASC
    LIMIT 1
];

if (baselineList.isEmpty()) {
    assessment.riskLevel = 'LOW';
    return assessment;
}

Signature_Request__c baseline = baselineList[0];


            /* --- ONLY ONE TOGGLE --- */
         if (rulesToRun != null) {

    if (rulesToRun.contains('IP_ANOMALY')) {
        compareIp(request, baseline, assessment);
    }

    if (rulesToRun.contains('LOCATION_ANOMALY')) {
        compareLocation(request, baseline, assessment);
    }

    if (rulesToRun.contains('BEHAVIORAL_ANOMALY')) {
        compareBehavior(request, baseline, assessment);
    }
}

            assessment.riskLevel = determineRiskLevel(assessment.totalRiskScore);
            return assessment;

        } catch (Exception e) {
            assessment.success = false;
            assessment.totalRiskScore = 100;
            assessment.riskLevel = 'CRITICAL';

            RiskFactor rf = new RiskFactor();
            rf.factorType = 'SYSTEM_ERROR';
            rf.description = 'Fraud engine failed: ' + e.getMessage();
            assessment.riskFactors.add(rf);

            return assessment;
        }
    }
private static void compareIp(
    Signature_Request__c current,
    Signature_Request__c baseline,
    SecurityAssessmentResult assessment
) {
    if (baseline.IPAddress__c != null &&
        current.IPAddress__c != baseline.IPAddress__c) {

        addRisk(
            assessment,
            'IP_ANOMALY',
            'The signature was completed from a different IP address than previously observed for this signer.'
        );
    }
}
private static void compareLocation(
    Signature_Request__c current,
    Signature_Request__c baseline,
    SecurityAssessmentResult assessment
) {
    if (baseline.SigningLocation__c != null &&
        current.SigningLocation__c != baseline.SigningLocation__c) {

        addRisk(
            assessment,
            'LOCATION_ANOMALY',
            'The signing location differs from the signer’s previously recorded location.'
        );
    }
}
private static void compareBehavior(
    Signature_Request__c current,
    Signature_Request__c baseline,
    SecurityAssessmentResult assessment
) {

    // Fast signing (absolute)
    if (current.Time_To_Complete_Seconds__c != null &&
        current.Time_To_Complete_Seconds__c < 10) {

        addRisk(
            assessment,
            'BEHAVIORAL_ANOMALY',
            'Extremely fast signing detected.'
        );
        return;
    }

    // Time deviation vs baseline
    if (baseline.Time_To_Complete_Seconds__c != null &&
        current.Time_To_Complete_Seconds__c != null) {

        Decimal base = baseline.Time_To_Complete_Seconds__c;
        Decimal curr = current.Time_To_Complete_Seconds__c;

        if (curr < base * 0.5 || curr > base * 2) {
            addRisk(
                assessment,
                'BEHAVIORAL_ANOMALY',
                'The signing behavior differs from the signer’s typical pattern.'
            );
        }
    }
}

    
    /* =========================
     * Helpers
     * ========================= */
    private static void addRisk(
        SecurityAssessmentResult assessment,
        String type,
        String message
    ) {
        RiskFactor rf = new RiskFactor();
        rf.factorType = type;
        rf.description = 'CRITICAL RISK: ' + message;
        assessment.riskFactors.add(rf);
        assessment.totalRiskScore += 100;
    }

    private static String determineRiskLevel(Integer score) {
        return score > 0 ? 'CRITICAL' : 'LOW';
    }
}
