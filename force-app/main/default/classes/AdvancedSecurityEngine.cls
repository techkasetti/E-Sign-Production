public with sharing class AdvancedSecurityEngine {

    // Define the risk score for each specific anomaly. These are configurable here.
    private static final Map<String, Integer> SECURITY_RISK_WEIGHTS = new Map<String, Integer>{
        'IP_ANOMALY'          => 25, // Signing from a new/unexpected country
        'LOCATION_ANOMALY'    => 50, // "Impossible Travel" - physically impossible speed
        'BEHAVIORAL_ANOMALY'  => 40, // Robotic, unnaturally fast signing
        'TIME_ANOMALY'        => 15  // Signing at unusual late-night hours
    };

    /**
     * @description Main method to perform a security assessment. This is the only method you need to call.
     * @param signatureRequestId The ID of the Signature_Request__c record to analyze.
     * @return SecurityAssessmentResult A wrapper class containing the final score, level, and details.
     */
    @AuraEnabled
    public static SecurityAssessmentResult performSecurityAssessment(String signatureRequestId) {
        System.debug('--- AdvancedSecurityEngine: Starting Assessment for Request ID: ' + signatureRequestId + ' ---');
        SecurityAssessmentResult assessment = new SecurityAssessmentResult();
        assessment.signatureRequestId = signatureRequestId;
        assessment.assessmentTimestamp = System.now();
        assessment.riskFactors = new List<RiskFactor>();
        assessment.totalRiskScore = 0;
        assessment.success = false;

        try {
            // Query the request record which should already have IP, location, etc. saved.
            Signature_Request__c request = [
                SELECT Id, SignerEmail__c, SigningLocation__c, IP_Country__c, 
                       Time_To_Complete_Seconds__c, CreatedDate, CompletedDate__c
                FROM Signature_Request__c
                WHERE Id = :signatureRequestId
                LIMIT 1
            ];

            // --- Run all four of your selected fraud checks ---
            // 1. IP Anomaly Check (New Country)
            RiskFactor ipRisk = assessIpAnomaly(request);
            if (ipRisk != null) {
                assessment.riskFactors.add(ipRisk);
                assessment.totalRiskScore += ipRisk.riskLevel;
            }

            // 2. Location Anomaly Check (Impossible Travel)
            RiskFactor locationRisk = assessLocationAnomaly(request);
            if (locationRisk != null) {
                assessment.riskFactors.add(locationRisk);
                assessment.totalRiskScore += locationRisk.riskLevel;
            }

            // 3. Behavioral Anomaly Check (Signing Speed)
            RiskFactor behavioralRisk = assessBehavioralAnomaly(request);
            if (behavioralRisk != null) {
                assessment.riskFactors.add(behavioralRisk);
                assessment.totalRiskScore += behavioralRisk.riskLevel;
            }

            // 4. Time Anomaly Check (Unusual Hours)
            RiskFactor timeRisk = assessTimeAnomalies(request);
            if (timeRisk != null) {
                assessment.riskFactors.add(timeRisk);
                assessment.totalRiskScore += timeRisk.riskLevel;
            }

            // Determine overall risk level and provide recommendations
            assessment.riskLevel = determineRiskLevel(assessment.totalRiskScore);
            assessment.recommendations = generateSecurityRecommendations(assessment);
            assessment.success = true;

            System.debug('--- AdvancedSecurityEngine: Assessment Complete ---');
            System.debug('Final Score: ' + assessment.totalRiskScore + ' | Risk Level: ' + assessment.riskLevel);
            return assessment;

        } catch (Exception e) {
            System.debug('ERROR in AdvancedSecurityEngine: ' + e.getMessage());
            assessment.success = false;
            assessment.errorMessage = 'Security assessment failed: ' + e.getMessage();
            return assessment;
        }
    }

    // --- Private Helper Methods for Each Fraud Check ---

    /**
     * @description Checks if the signing country is new for this user.
     * @param currentRequest The signature request being analyzed.
     * @return RiskFactor object if an anomaly is detected, otherwise null.
     */
    private static RiskFactor assessIpAnomaly(Signature_Request__c currentRequest) {
        if (String.isBlank(currentRequest.IP_Country__c) || currentRequest.IP_Country__c == 'Unknown') {
            return null; // Cannot check if there is no country data
        }

        Set<String> historicalCountries = new Set<String>();
        for (AggregateResult ar : [
            SELECT IP_Country__c FROM Signature_Request__c
            WHERE SignerEmail__c = :currentRequest.SignerEmail__c
            AND Id != :currentRequest.Id AND IP_Country__c != NULL
            GROUP BY IP_Country__c
        ]) {
            historicalCountries.add((String)ar.get('IP_Country__c'));
        }

        if (!historicalCountries.isEmpty() && !historicalCountries.contains(currentRequest.IP_Country__c)) {
            String reason = 'Foreign IP Anomaly detected. Signing from a new country: ' + currentRequest.IP_Country__c;
            return new RiskFactor('IP_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('IP_ANOMALY'));
        }
        return null;
    }

    /**
     * @description Checks for "Impossible Travel" by calculating the speed between the last two signature locations.
     * @param currentRequest The signature request being analyzed.
     * @return RiskFactor object if an anomaly is detected, otherwise null.
     */
    private static RiskFactor assessLocationAnomaly(Signature_Request__c currentRequest) {
        if (String.isBlank(currentRequest.SigningLocation__c) || currentRequest.CompletedDate__c == null) {
            return null; // Cannot check if location or completion date is missing
        }

        List<Signature_Request__c> lastSignatureList = [
            SELECT SigningLocation__c, CompletedDate__c FROM Signature_Request__c
            WHERE SignerEmail__c = :currentRequest.SignerEmail__c AND Id != :currentRequest.Id
            AND SigningLocation__c != NULL AND CompletedDate__c != NULL
            ORDER BY CompletedDate__c DESC LIMIT 1
        ];

        if (lastSignatureList.isEmpty()) {
            return null; // No previous location to compare against
        }

        try {
            Signature_Request__c lastSignature = lastSignatureList[0];

            List<String> currentCoords = currentRequest.SigningLocation__c.split(',');
            List<String> lastCoords = lastSignature.SigningLocation__c.split(',');

            if (currentCoords.size() != 2 || lastCoords.size() != 2) return null;

            Location currentLocation = Location.newInstance(Decimal.valueOf(currentCoords[0]), Decimal.valueOf(currentCoords[1]));
            Location lastLocation = Location.newInstance(Decimal.valueOf(lastCoords[0]), Decimal.valueOf(lastCoords[1]));

            Long timeDiffSeconds = (currentRequest.CompletedDate__c.getTime() - lastSignature.CompletedDate__c.getTime()) / 1000;
            if(timeDiffSeconds <= 0) return null; // Avoid division by zero

            Decimal distanceKm = Location.getDistance(currentLocation, lastLocation, 'km');
            Decimal timeDiffHours = (Decimal)timeDiffSeconds / 3600.0;
            Decimal speedKmh = distanceKm / timeDiffHours;

            if (speedKmh > 900) { // Commercial jets fly around 900 km/h
                String reason = 'Impossible travel detected. Calculated speed of ' + speedKmh.setScale(0) + ' km/h between signatures.';
                return new RiskFactor('LOCATION_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('LOCATION_ANOMALY'));
            }
        } catch (Exception e) {
            System.debug('Location coordinate parsing error: ' + e.getMessage());
            return null;
        }

        return null;
    }

    /**
     * @description Checks for robotic signing behavior (signing too quickly).
     * @param currentRequest The signature request being analyzed.
     * @return RiskFactor object if an anomaly is detected, otherwise null.
     */
    private static RiskFactor assessBehavioralAnomaly(Signature_Request__c currentRequest) {
        if (currentRequest.Time_To_Complete_Seconds__c == null) {
            return null;
        }

        if (currentRequest.Time_To_Complete_Seconds__c < 3) {
            String reason = 'Robotic signing detected. Signature was completed in under 3 seconds.';
            return new RiskFactor('BEHAVIORAL_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('BEHAVIORAL_ANOMALY'));
        }
        return null;
    }

    /**
     * @description Checks if signing occurred during unusual hours.
     * @param currentRequest The signature request being analyzed.
     * @return RiskFactor object if an anomaly is detected, otherwise null.
     */
    private static RiskFactor assessTimeAnomalies(Signature_Request__c currentRequest) {
        Integer currentHour = currentRequest.CreatedDate.time().hour();

        // Flag as risky if signing occurs during unusual late-night hours (e.g., midnight to 5 AM)
        if (currentHour >= 0 && currentHour <= 5) {
            String reason = 'Signing occurred during unusual late-night hours (' + currentHour + ':00).';
            return new RiskFactor('TIME_ANOMALY', reason, SECURITY_RISK_WEIGHTS.get('TIME_ANOMALY'));
        }
        return null;
    }

    // --- Risk Level and Recommendation Logic ---
    private static String determineRiskLevel(Integer totalScore) {
        if (totalScore >= 70) return 'CRITICAL';
        if (totalScore >= 40) return 'HIGH';
        if (totalScore >= 20) return 'MEDIUM';
        return 'LOW';
    }

    private static List<String> generateSecurityRecommendations(SecurityAssessmentResult assessment) {
        List<String> recommendations = new List<String>();
        if (assessment.riskLevel == 'CRITICAL') {
            recommendations.add('IMMEDIATE ACTION: Block signature request and investigate user account.');
        } else if (assessment.riskLevel == 'HIGH') {
            recommendations.add('Require additional multi-factor authentication before processing.');
            recommendations.add('Manually review signer identity.');
        } else if (assessment.riskLevel == 'MEDIUM') {
            recommendations.add('Consider sending a verification email to the signer.');
        } else {
            recommendations.add('Process normally with standard security measures.');
        }
        return recommendations;
    }

    // --- Wrapper Classes for Data Structure ---
    public class SecurityAssessmentResult {
        @AuraEnabled public String signatureRequestId { get; set; }
        @AuraEnabled public DateTime assessmentTimestamp { get; set; }
        @AuraEnabled public List<RiskFactor> riskFactors { get; set; }
        @AuraEnabled public Integer totalRiskScore { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public List<String> recommendations { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class RiskFactor {
        @AuraEnabled public String factorType { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Integer riskLevel { get; set; }

        public RiskFactor(String type, String description, Integer level) {
            this.factorType = type;
            this.description = description;
            this.riskLevel = level;
        }
    }
}
