// public with sharing class AdvancedSecurityEngine {

//     // Define the risk score for each specific anomaly. These are configurable here.
//     private static final Map<String, Integer> SECURITY_RISK_WEIGHTS = new Map<String, Integer>{
//         'IP_ANOMALY' => 25,          // Signing from a new/unexpected country
//         'LOCATION_ANOMALY' => 50,   // "Impossible Travel" - physically impossible speed
//         'BEHAVIORAL_ANOMALY' => 40, // Robotic, unnaturally fast signing
//         'TIME_ANOMALY' => 15        // Signing at unusual late-night hours
//     };

//     /**
//      * @description Main method to perform a security assessment. This is the only method you need to call.
//      * @param signatureRequestId The ID of the Signature_Request__c record to analyze.
//      * @return SecurityAssessmentResult A wrapper class containing the final score, level, and details.
//      */
//     @AuraEnabled
//     public static SecurityAssessmentResult performSecurityAssessment(String signatureRequestId) {
//         System.debug('--- AdvancedSecurityEngine: Starting Assessment for Request ID: ' + signatureRequestId + ' ---');
//         SecurityAssessmentResult assessment = new SecurityAssessmentResult();
//         assessment.signatureRequestId = signatureRequestId;
//         assessment.assessmentTimestamp = System.now();
//         assessment.riskFactors = new List<RiskFactor>();
//         assessment.totalRiskScore = 0;
//         assessment.success = false;

//         try {
//             // Query the request record which should now have IP, location, etc., saved.
//             Signature_Request__c request = [
//                 SELECT Id, SignerEmail__c, SigningLocation__c, IP_Country__c, Time_To_Complete_Seconds__c, CreatedDate, CompletedDate__c, Fraud_Rules_To_Run__c
//                 FROM Signature_Request__c
//                 WHERE Id = :signatureRequestId
//                 LIMIT 1
//             ];

//             if (String.isBlank(request.Fraud_Rules_To_Run__c)) {
//                  assessment.success = true; // Technically successful, just nothing to do.
//                  return assessment;
//             }

//             List<String> rulesToRun = request.Fraud_Rules_To_Run__c.split(';');

//             // --- Run all four of your selected fraud checks ---
//             if(rulesToRun.contains('IP_ANOMALY')) {
//                 RiskFactor ipRisk = assessIpAnomaly(request);
//                 if (ipRisk != null) {
//                     assessment.riskFactors.add(ipRisk);
//                     assessment.totalRiskScore += ipRisk.riskLevel;
//                 }
//             }
//             if(rulesToRun.contains('LOCATION_ANOMALY')) {
//                 RiskFactor locationRisk = assessLocationAnomaly(request);
//                 if (locationRisk != null) {
//                     assessment.riskFactors.add(locationRisk);
//                     assessment.totalRiskScore += locationRisk.riskLevel;
//                 }
//             }
//             if(rulesToRun.contains('BEHAVIORAL_ANOMALY')) {
//                 RiskFactor behavioralRisk = assessBehavioralAnomaly(request);
//                 if (behavioralRisk != null) {
//                     assessment.riskFactors.add(behavioralRisk);
//                     assessment.totalRiskScore += behavioralRisk.riskLevel;
//                 }
//             }
//              if(rulesToRun.contains('TIME_ANOMALY')) {
//                 RiskFactor timeRisk = assessTimeAnomalies(request);
//                 if (timeRisk != null) {
//                     assessment.riskFactors.add(timeRisk);
//                     assessment.totalRiskScore += timeRisk.riskLevel;
//                 }
//             }

//             assessment.riskLevel = determineRiskLevel(assessment.totalRiskScore);
//             assessment.success = true;

//             System.debug('--- AdvancedSecurityEngine: Assessment Complete ---');
//             System.debug('Final Score: ' + assessment.totalRiskScore + ' | Risk Level: ' + assessment.riskLevel);

//             return assessment;

//         } catch (Exception e) {
//             System.debug('ERROR in AdvancedSecurityEngine: ' + e.getMessage());
//             assessment.success = false;
//             assessment.errorMessage = 'Security assessment failed: ' + e.getMessage();
//             return assessment;
//         }
//     }

//     // --- Private Helper Methods for Each Fraud Check ---

//     private static RiskFactor assessIpAnomaly(Signature_Request__c currentRequest) {
//         if (String.isBlank(currentRequest.IP_Country__c) || currentRequest.IP_Country__c == 'Unknown') return null;

//         Set<String> historicalCountries = new Set<String>();
//         for (AggregateResult ar : [
//             SELECT IP_Country__c FROM Signature_Request__c
//             WHERE SignerEmail__c = :currentRequest.SignerEmail__c
//             AND Id != :currentRequest.Id
//             AND IP_Country__c != NULL
//             GROUP BY IP_Country__c
//         ]) {
//             historicalCountries.add((String)ar.get('IP_Country__c'));
//         }

//         if (!historicalCountries.isEmpty() && !historicalCountries.contains(currentRequest.IP_Country__c)) {
//             String reason = 'Foreign IP Anomaly detected. Signing from a new country: ' + currentRequest.IP_Country__c;
//             return new RiskFactor('IP_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('IP_ANOMALY'));
//         }
//         return null;
//     }

//     private static RiskFactor assessLocationAnomaly(Signature_Request__c currentRequest) {
//         if (String.isBlank(currentRequest.SigningLocation__c) || currentRequest.CompletedDate__c == null) return null;

//         List<Signature_Request__c> lastSignatureList = [
//             SELECT SigningLocation__c, CompletedDate__c FROM Signature_Request__c
//             WHERE SignerEmail__c = :currentRequest.SignerEmail__c
//             AND Id != :currentRequest.Id
//             AND SigningLocation__c != NULL
//             AND CompletedDate__c != NULL
//             ORDER BY CompletedDate__c DESC
//             LIMIT 1
//         ];

//         if (lastSignatureList.isEmpty()) return null;

//         try {
//             Signature_Request__c lastSignature = lastSignatureList[0];

//             List<String> currentCoords = currentRequest.SigningLocation__c.split(',');
//             List<String> lastCoords = lastSignature.SigningLocation__c.split(',');

//             if (currentCoords.size() != 2 || lastCoords.size() != 2) return null;

//             Location currentLocation = Location.newInstance(Decimal.valueOf(currentCoords[0]), Decimal.valueOf(currentCoords[1]));
//             Location lastLocation = Location.newInstance(Decimal.valueOf(lastCoords[0]), Decimal.valueOf(lastCoords[1]));

//             Long timeDiffSeconds = (currentRequest.CompletedDate__c.getTime() - lastSignature.CompletedDate__c.getTime()) / 1000;
//             if(timeDiffSeconds <= 0) return null;

//             Decimal distanceKm = Location.getDistance(currentLocation, lastLocation, 'km');
//             Decimal timeDiffHours = (Decimal)timeDiffSeconds / 3600.0;
//             Decimal speedKmh = distanceKm / timeDiffHours;

//             if (speedKmh > 900) { // Commercial jets fly around 900 km/h
//                 String reason = 'Impossible travel detected. Calculated speed of ' + speedKmh.setScale(0) + ' km/h between signatures.';
//                 return new RiskFactor('LOCATION_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('LOCATION_ANOMALY'));
//             }
//         } catch (Exception e) {
//             System.debug('Location coordinate parsing error: ' + e.getMessage());
//             return null;
//         }
//         return null;
//     }

//     private static RiskFactor assessBehavioralAnomaly(Signature_Request__c currentRequest) {
//         if (currentRequest.Time_To_Complete_Seconds__c == null) return null;
        
//         if (currentRequest.Time_To_Complete_Seconds__c < 3) {
//             String reason = 'Robotic signing detected. Signature was completed in under 3 seconds.';
//             return new RiskFactor('BEHAVIORAL_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('BEHAVIORAL_ANOMALY'));
//         }
//         return null;
//     }

//     private static RiskFactor assessTimeAnomalies(Signature_Request__c currentRequest) {
//         Integer currentHour = currentRequest.CreatedDate.time().hour();
        
//         if (currentHour >= 0 && currentHour <= 5) { // Between midnight and 5 AM
//             String reason = 'Signing occurred during unusual late-night hours (' + currentHour + ':00).';
//             return new RiskFactor('TIME_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('TIME_ANOMALY'));
//         }
//         return null;
//     }

//     private static String determineRiskLevel(Integer totalScore) {
//         if (totalScore >= 70) return 'CRITICAL';
//         if (totalScore >= 40) return 'HIGH';
//         if (totalScore >= 20) return 'MEDIUM';
//         return 'LOW';
//     }

//     // --- Wrapper Classes for Data Structure ---
//     public class SecurityAssessmentResult {
//         @AuraEnabled public String signatureRequestId { get; set; }
//         @AuraEnabled public DateTime assessmentTimestamp { get; set; }
//         @AuraEnabled public List<RiskFactor> riskFactors { get; set; }
//         @AuraEnabled public Integer totalRiskScore { get; set; }
//         @AuraEnabled public String riskLevel { get; set; }
//         @AuraEnabled public Boolean success { get; set; }
//         @AuraEnabled public String errorMessage { get; set; }
//         @AuraEnabled public List<String> recommendations {get; set;}
//     }

//     public class RiskFactor {
//         @AuraEnabled public String factorType { get; set; }
//         @AuraEnabled public String description { get; set; }
//         @AuraEnabled public Integer riskLevel { get; set; }

//         public RiskFactor(String type, String description, Integer level) {
//             this.factorType = type;
//             this.description = description;
//             this.riskLevel = level;
//         }
//     }
// }
// File: AdvancedSecurityEngine.cls
// Final Unified Logic: If a data point is new, the risk is CRITICAL.

public with sharing class AdvancedSecurityEngine {

    /**
     * Wrapper class for the final security assessment result.
     */
    public class SecurityAssessmentResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Integer totalRiskScore { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public List<RiskFactor> riskFactors { get; set; }
    }

    /**
     * Represents a single identified risk factor.
     */
    public class RiskFactor {
        @AuraEnabled public String factorType { get; set; }
        @AuraEnabled public String description { get; set; }
    }

    /**
     * Main method to perform the security assessment.
     */
    @AuraEnabled
    public static SecurityAssessmentResult performSecurityAssessment(String signatureRequestId) {
        SecurityAssessmentResult assessment = new SecurityAssessmentResult();
        assessment.success = true;
        assessment.riskFactors = new List<RiskFactor>();
        assessment.totalRiskScore = 0;

        try {
            Signature_Request__c request = [
                SELECT Id, SignerEmail__c, IPAddress__c, SigningLocation__c,
                       Time_To_Complete_Seconds__c, CreatedDate, Fraud_Rules_To_Run__c
                FROM Signature_Request__c
                WHERE Id = :signatureRequestId
                LIMIT 1
            ];

            String rulesToRun = request.Fraud_Rules_To_Run__c;

            List<Signature_Request__c> historicalRequests = [
                SELECT IPAddress__c, SigningLocation__c, Time_To_Complete_Seconds__c, CreatedDate
                FROM Signature_Request__c
                WHERE SignerEmail__c = :request.SignerEmail__c
                  AND Id != :request.Id
                  AND Status__c = 'Signed'
            ];

            // If there's no history, this is the first signature, which is always LOW risk.
            if (historicalRequests.isEmpty()) {
                assessment.riskLevel = 'LOW';
                return assessment;
            }

            if (rulesToRun != null) {
                // Run each check. If any check fails, the risk becomes CRITICAL.
                if (rulesToRun.contains('IP_ANOMALY')) {
                    assessIpUniqueness(request, historicalRequests, assessment);
                }
                if (rulesToRun.contains('LOCATION_ANOMALY')) {
                    assessLocationUniqueness(request, historicalRequests, assessment);
                }
                if (rulesToRun.contains('BEHAVIORAL_ANOMALY')) {
                    assessBehavioralPattern(request, historicalRequests, assessment);
                }
                if (rulesToRun.contains('TIME_ANOMALY')) {
                    assessTimePattern(request, historicalRequests, assessment);
                }
            }

            assessment.riskLevel = determineRiskLevel(assessment.totalRiskScore);

        } catch (Exception e) {
            assessment.success = false;
            assessment.totalRiskScore = 100; // CRITICAL
            assessment.riskLevel = 'CRITICAL';
            RiskFactor errorFactor = new RiskFactor();
            errorFactor.factorType = 'SYSTEM_ERROR';
            errorFactor.description = 'The fraud analysis engine failed: ' + e.getMessage();
            assessment.riskFactors.add(errorFactor);
        }
        return assessment;
    }

    /**
     * CRITICAL if IP is NEW. LOW if it matches a past IP.
     */
    private static void assessIpUniqueness(Signature_Request__c currentRequest, List<Signature_Request__c> history, SecurityAssessmentResult assessment) {
        if (String.isBlank(currentRequest.IPAddress__c)) return;

        Set<String> historicalIPs = new Set<String>();
        for (Signature_Request__c pastRequest : history) {
            if (String.isNotBlank(pastRequest.IPAddress__c)) {
                historicalIPs.add(pastRequest.IPAddress__c);
            }
        }

        if (!historicalIPs.contains(currentRequest.IPAddress__c)) {
            RiskFactor factor = new RiskFactor();
            factor.factorType = 'IP_ANOMALY';
            factor.description = 'CRITICAL RISK: A new, unrecognized IP address was used.';
            assessment.riskFactors.add(factor);
            assessment.totalRiskScore += 100;
        }
    }

    /**
     * CRITICAL if Location is NEW. LOW if it matches a past location.
     */
    private static void assessLocationUniqueness(Signature_Request__c currentRequest, List<Signature_Request__c> history, SecurityAssessmentResult assessment) {
        if (String.isBlank(currentRequest.SigningLocation__c)) return;

        Set<String> historicalLocations = new Set<String>();
        for (Signature_Request__c pastRequest : history) {
            if (String.isNotBlank(pastRequest.SigningLocation__c)) {
                historicalLocations.add(pastRequest.SigningLocation__c);
            }
        }

        if (!historicalLocations.contains(currentRequest.SigningLocation__c)) {
            RiskFactor factor = new RiskFactor();
            factor.factorType = 'LOCATION_ANOMALY';
            factor.description = 'CRITICAL RISK: A new, unrecognized location was used.';
            assessment.riskFactors.add(factor);
            assessment.totalRiskScore += 100;
        }
    }

    /**
     * CRITICAL if signing speed is NEW. LOW if it's close to a past speed.
     */
    private static void assessBehavioralPattern(Signature_Request__c currentRequest, List<Signature_Request__c> history, SecurityAssessmentResult assessment) {
    if (currentRequest.Time_To_Complete_Seconds__c == null) return;

    Decimal totalSeconds = 0;
    Integer count = 0;
    for (Signature_Request__c pastRequest : history) {
        if (pastRequest.Time_To_Complete_Seconds__c != null) {
            totalSeconds += pastRequest.Time_To_Complete_Seconds__c;
            count++;
        }
    }

    if (count == 0) return; // No valid history to compare against

    Decimal averageSpeed = totalSeconds / count;
    Decimal currentSpeed = currentRequest.Time_To_Complete_Seconds__c;

    // Define a tolerance (e.g., 50% faster or 100% slower is anomalous)
    Decimal lowerBound = averageSpeed * 0.5; // 50% of average
    Decimal upperBound = averageSpeed * 2.0; // 200% of average

    // If the current speed is outside the normal range, it's a new pattern.
    if (currentSpeed < lowerBound || currentSpeed > upperBound) {
        RiskFactor factor = new RiskFactor();
        factor.factorType = 'BEHAVIORAL_ANOMALY';
        factor.description = 'CRITICAL RISK: The signing speed of ' + currentSpeed.setScale(0) + 's is a significant deviation from the user\'s average of ' + averageSpeed.setScale(0) + 's.';
        assessment.riskFactors.add(factor);
        assessment.totalRiskScore += 100;
    }
}


    /**
     * CRITICAL if the signing hour is NEW. LOW if it matches a past hour.
     */
    private static void assessTimePattern(Signature_Request__c currentRequest, List<Signature_Request__c> history, SecurityAssessmentResult assessment) {
        Set<Integer> historicalHours = new Set<Integer>();
        for (Signature_Request__c pastRequest : history) {
            historicalHours.add(pastRequest.CreatedDate.hour());
        }

        Integer currentHour = currentRequest.CreatedDate.hour();

        if (!historicalHours.contains(currentHour)) {
            RiskFactor factor = new RiskFactor();
            factor.factorType = 'TIME_ANOMALY';
            factor.description = 'CRITICAL RISK: Signing at ' + currentHour + ':00 is a new and unrecognized time for this user.';
            assessment.riskFactors.add(factor);
            assessment.totalRiskScore += 100;
        }
    }

    /**
     * Simplified risk level calculation: Any risk found is CRITICAL.
     */
    private static String determineRiskLevel(Integer totalRiskScore) {
        if (totalRiskScore > 0) {
            return 'CRITICAL';
        } else {
            return 'LOW';
        }
    }
}
