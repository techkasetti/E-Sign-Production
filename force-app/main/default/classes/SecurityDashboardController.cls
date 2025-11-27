public class SecurityDashboardController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getThreatMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        try {
            // This query now correctly looks at ThreatIntelligence__c
            List<AggregateResult> riskResults = [
                SELECT AVG(RiskScore__c) avgScore, COUNT(Id) totalThreats 
                FROM ThreatIntelligence__c 
                WHERE CreatedDate = LAST_N_DAYS:1 AND RiskScore__c >= 40
            ];

            if (!riskResults.isEmpty() && riskResults[0].get('totalThreats') != null) {
                metrics.put('averageRiskScore', riskResults[0].get('avgScore'));
                metrics.put('suspiciousActivities', riskResults[0].get('totalThreats'));
            } else {
                metrics.put('averageRiskScore', 0);
                metrics.put('suspiciousActivities', 0);
            }

            // This query correctly counts high-risk threats from the right object
            List<AggregateResult> highRiskThreats = [
                SELECT COUNT(Id) highRiskCount 
                FROM ThreatIntelligence__c 
                WHERE CreatedDate = LAST_N_DAYS:1 AND RiskLevel__c IN ('HIGH', 'CRITICAL')
            ];
            metrics.put('activeHighRiskThreats', highRiskThreats.isEmpty() ? 0 : highRiskThreats[0].get('highRiskCount'));
            metrics.put('systemHealth', 'HEALTHY');

        } catch (Exception e) {
            System.debug('Error getting threat metrics: ' + e.getMessage());
            metrics.put('averageRiskScore', 0);
            metrics.put('suspiciousActivities', 0);
            metrics.put('activeHighRiskThreats', 0);
            metrics.put('systemHealth', 'UNKNOWN');
        }
        return metrics;
    }

    @AuraEnabled(cacheable=false)
    public static List<ActiveThreat> getActiveThreats() {
        List<ActiveThreat> activeThreats = new List<ActiveThreat>();
        try {
            // This query now correctly gets the list of threats from ThreatIntelligence__c
            List<ThreatIntelligence__c> threats = [
                SELECT Id, CreatedById, RiskLevel__c, RiskScore__c, Description__c, CreatedDate 
                FROM ThreatIntelligence__c 
                WHERE CreatedDate = LAST_N_DAYS:1 AND RiskScore__c >= 40 
                ORDER BY RiskScore__c DESC, CreatedDate DESC 
                LIMIT 50
            ];

            for (ThreatIntelligence__c threat : threats) {
                ActiveThreat activeThreat = new ActiveThreat();
                activeThreat.id = threat.Id;
                activeThreat.userId = threat.CreatedById;
                activeThreat.threatLevel = threat.RiskLevel__c;
                activeThreat.riskScore = threat.RiskScore__c.intValue();
                activeThreat.description = threat.Description__c;
                activeThreat.activity = 'E-Signature Submission';
                activeThreat.timestamp = threat.CreatedDate;
                activeThreat.formattedTimestamp = formatTimestamp(threat.CreatedDate);
                activeThreats.add(activeThreat);
            }
        } catch (Exception e) {
            System.debug('Error getting active threats: ' + e.getMessage());
        }
        return activeThreats;
    }

    private static String formatTimestamp(DateTime timestamp) {
        if (timestamp == null) return '';
        return timestamp.format('h:mm:ss a');
    }

    // Wrapper class for active threats
    public class ActiveThreat {
        @AuraEnabled public String id;
        @AuraEnabled public String userId;
        @AuraEnabled public String threatLevel;
        @AuraEnabled public Integer riskScore;
        @AuraEnabled public String description;
        @AuraEnabled public String activity;
        @AuraEnabled public DateTime timestamp;
        @AuraEnabled public String formattedTimestamp;
    }
}
