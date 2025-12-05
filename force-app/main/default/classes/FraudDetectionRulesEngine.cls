public with sharing class FraudDetectionRulesEngine {
    public static FraudAnalysisResult runSelectedChecks(Signature_Request__c sigRequest) {
        System.debug('================ START FraudDetectionRulesEngine =================');
        
        // --- DEBUGGER ADDITION ---
        // STEP 3: VERIFY WHAT THE FRAUD ENGINE IS READING FROM THE RECORD
        System.debug('DEBUG 3 (Engine): Value read from Fraud_Rules_To_Run__c -> ' + sigRequest.Fraud_Rules_To_Run__c);
        // --- END OF ADDITION ---
        
        System.debug('Incoming Signature Request: ' + JSON.serialize(sigRequest));
        if (sigRequest == null) {
            System.debug('ERROR: sigRequest is NULL');
            return new FraudAnalysisResult(false, 'LOW', 0, new List<String>(), new List<String>());
        }
        if (String.isBlank(sigRequest.Fraud_Rules_To_Run__c)) {
            System.debug('No Fraud Rules selected. Skipping all checks.');
            return new FraudAnalysisResult(false, 'LOW', 0, new List<String>(), new List<String>());
        }
        List<String> rulesToRun = sigRequest.Fraud_Rules_To_Run__c.split(';');
        System.debug('Rules Selected: ' + rulesToRun);
        List<RiskFactor> detectedRisks = new List<RiskFactor>();
        for (String rule : rulesToRun) {
            System.debug('---------- Evaluating Rule: ' + rule + ' ----------');
            RiskFactor factor = null;
            if (rule == 'IP_ANOMALY') {
                factor = checkIpAnomaly(sigRequest);
            } else if (rule == 'LOCATION_ANOMALY') {
                factor = checkLocationAnomaly(sigRequest);
            } else if (rule == 'BEHAVIORAL_ANOMALY') {
                factor = checkBehavioralAnomaly(sigRequest);
            } else if (rule == 'TIME_ANOMALY') {
                factor = checkTimeAnomaly(sigRequest);
            }
            if (factor!= null) {
                System.debug('RISK DETECTED --> ' + factor.ruleName + ' | Score: ' + factor.score);
                detectedRisks.add(factor);
            } else {
                System.debug('No risk detected for rule: ' + rule);
            }
        }
        System.debug('Total Risks Detected: ' + detectedRisks.size());
        FraudAnalysisResult result = compileFinalResult(detectedRisks);
        System.debug('FINAL FRAUD RESULT: ' + JSON.serialize(result));
        System.debug('================ END FraudDetectionRulesEngine =================');
        return result;
    }

    private static RiskFactor checkIpAnomaly(Signature_Request__c currentRequest) {
        System.debug('--- IP_ANOMALY CHECK START ---');
        System.debug('Signer Email: ' + currentRequest.SignerEmail__c);
        System.debug('Current Country: ' + currentRequest.IP_Country__c);
        if (String.isBlank(currentRequest.IP_Country__c) || currentRequest.IP_Country__c == 'Unknown') {
            System.debug('Skipping IP check due to missing country.');
            return null;
        }
        Set<String> historicalCountries = new Set<String>();
        List<AggregateResult> queryResult = [
            SELECT IP_Country__c
            FROM Signature_Request__c
            WHERE SignerEmail__c = :currentRequest.SignerEmail__c AND Id!= :currentRequest.Id AND IP_Country__c!= NULL
            GROUP BY IP_Country__c
        ];
        for (AggregateResult ar : queryResult) {
            historicalCountries.add((String)ar.get('IP_Country__c'));
        }
        System.debug('Historical Countries: ' + historicalCountries);
        if (!historicalCountries.isEmpty() &&!historicalCountries.contains(currentRequest.IP_Country__c)) {
            String reason = 'Foreign IP Anomaly detected from new country: ' + currentRequest.IP_Country__c;
            return new RiskFactor('IP_ANOMALY', reason, 25);
        }
        System.debug('IP check passed.');
        return null;
    }

    private static RiskFactor checkLocationAnomaly(Signature_Request__c currentRequest) {
        System.debug('--- LOCATION_ANOMALY CHECK START ---');
        System.debug('Current Location: ' + currentRequest.SigningLocation__c);
        if (String.isBlank(currentRequest.SigningLocation__c)) {
            System.debug('Location missing. Skipping.');
            return null;
        }
        List<Signature_Request__c> lastSignatureList = [
            SELECT SigningLocation__c, CompletedDate__c
            FROM Signature_Request__c
            WHERE SignerEmail__c = :currentRequest.SignerEmail__c AND Id!= :currentRequest.Id AND SigningLocation__c!= NULL
            ORDER BY CompletedDate__c DESC
            LIMIT 1
        ];
        if (lastSignatureList.isEmpty()) {
            System.debug('No previous location found. Skipping.');
            return null;
        }
        Signature_Request__c lastSignature = lastSignatureList[0];
        System.debug('Previous Location: ' + lastSignature.SigningLocation__c);
        System.debug('Previous Time: ' + lastSignature.CompletedDate__c);
        List<String> currentCoords = currentRequest.SigningLocation__c.split(',');
        List<String> lastCoords = lastSignature.SigningLocation__c.split(',');
        if (currentCoords.size()!= 2 || lastCoords.size()!= 2) {
            System.debug('Invalid coordinate format.');
            return null;
        }
        Location currentLocation = Location.newInstance(Decimal.valueOf(currentCoords[0]), Decimal.valueOf(currentCoords[1]));
        Location lastLocation = Location.newInstance(Decimal.valueOf(lastCoords[0]), Decimal.valueOf(lastCoords[1]));
        Long timeDiffSeconds = (System.now().getTime() - lastSignature.CompletedDate__c.getTime()) / 1000;
        Decimal distanceKm = Location.getDistance(currentLocation, lastLocation, 'km');
        Decimal timeDiffHours = timeDiffSeconds / 3600.0;
        Decimal speed = distanceKm / timeDiffHours;
        System.debug('Distance KM: ' + distanceKm);
        System.debug('Time Hours: ' + timeDiffHours);
        System.debug('Speed KM/H: ' + speed);
        if (speed > 900) {
            String reason = 'Impossible travel detected: Speed ' + speed;
            return new RiskFactor('LOCATION_ANOMALY', reason, 50);
        }
        System.debug('Location check passed.');
        return null;
    }

    private static RiskFactor checkBehavioralAnomaly(Signature_Request__c currentRequest) {
        System.debug('--- BEHAVIORAL_ANOMALY CHECK START ---');
        System.debug('Current Time To Sign: ' + currentRequest.Time_To_Complete_Seconds__c);
        if (currentRequest.Time_To_Complete_Seconds__c == null) return null;
        List<AggregateResult> userHistory = [
            SELECT AVG(Time_To_Complete_Seconds__c) avgTime
            FROM Signature_Request__c
            WHERE SignerEmail__c = :currentRequest.SignerEmail__c AND Id!= :currentRequest.Id AND Status__c = 'Signed' AND Time_To_Complete_Seconds__c!= NULL
        ];
        if (!userHistory.isEmpty() && userHistory[0].get('avgTime')!= null) {
            Decimal avgTime = (Decimal)userHistory[0].get('avgTime');
            System.debug('User Average Time: ' + avgTime);
            if (avgTime > 15 && currentRequest.Time_To_Complete_Seconds__c < 3) {
                return new RiskFactor('BEHAVIORAL_ANOMALY', 'Robotic signing detected', 40);
            }
        }
        return null;
    }

    private static RiskFactor checkTimeAnomaly(Signature_Request__c currentRequest) {
        System.debug('--- TIME_ANOMALY CHECK START ---');
        Integer currentHour = System.now().hour();
        System.debug('Current Hour: ' + currentHour);
        Set<Integer> hours = new Set<Integer>();
        List<AggregateResult> queryResult = [
            SELECT HOUR_IN_DAY(CompletedDate__c) hour
            FROM Signature_Request__c
            WHERE SignerEmail__c = :currentRequest.SignerEmail__c AND Id!= :currentRequest.Id AND Status__c = 'Signed'
            GROUP BY HOUR_IN_DAY(CompletedDate__c)
        ];
        for (AggregateResult ar : queryResult) {
            hours.add((Integer)ar.get('hour'));
        }
        System.debug('User Typical Hours: ' + hours);
        if (!hours.contains(currentHour) && (currentHour < 6 || currentHour > 22)) {
            return new RiskFactor('TIME_ANOMALY', 'Unusual signing hour detected', 15);
        }
        return null;
    }

    private static FraudAnalysisResult compileFinalResult(List<RiskFactor> detectedRisks) {
        System.debug('--- COMPILING FINAL FRAUD RESULT ---');
        Decimal totalScore = 0;
        List<String> rules = new List<String>();
        List<String> reasons = new List<String>();
        for (RiskFactor r : detectedRisks) {
            totalScore += r.score;
            rules.add(r.ruleName);
            reasons.add(r.reason);
        }
        System.debug('TOTAL SCORE: ' + totalScore);
        String riskLevel = totalScore >= 70? 'CRITICAL' : totalScore >= 40? 'HIGH' : totalScore >= 20? 'MEDIUM' : 'LOW';
        return new FraudAnalysisResult(!detectedRisks.isEmpty(), riskLevel, totalScore, rules, reasons);
    }

    public class RiskFactor {
        public String ruleName { get; private set; }
        public String reason { get; private set; }
        public Decimal score { get; private set; }
        public RiskFactor(String ruleName, String reason, Decimal score) {
            this.ruleName = ruleName;
            this.reason = reason;
            this.score = score;
        }
    }

    public class FraudAnalysisResult {
        @AuraEnabled public Boolean isFraudDetected { get; private set; }
        @AuraEnabled public String riskLevel { get; private set; }
        @AuraEnabled public Decimal overallRiskScore { get; private set; }
        @AuraEnabled public List<String> triggeredRules { get; private set; }
        @AuraEnabled public List<String> reasons { get; private set; }
        public FraudAnalysisResult(Boolean detected, String level, Decimal score, List<String> rules, List<String> reasons) {
            this.isFraudDetected = detected;
            this.riskLevel = level;
            this.overallRiskScore = score;
            this.triggeredRules = rules;
            this.reasons = reasons;
        }
    }
}
