// File: SecurityDashboardController.cls
public with sharing class SecurityDashboardController {
    /**
     * Wrapper class for the dashboard's data structure.
     */
    public class DashboardData {
        @AuraEnabled public Integer criticalEvents24h { get; set; }
        @AuraEnabled public Integer totalAssessments24h { get; set; }
        @AuraEnabled public List<Signature_Request__c> recentCriticalEvents { get; set; }
    }

    /**
     * Fetches all data needed for the security dashboard.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        DashboardData data = new DashboardData();
        DateTime last24Hours = System.now().addHours(-24);

        // Aggregate counts for the last 24 hours
        List<AggregateResult> results24h = [
            SELECT Fraud_Risk_Level__c, COUNT(Id) eventCount
            FROM Signature_Request__c
            WHERE CreatedDate >= :last24Hours
            AND Fraud_Risk_Level__c != NULL
            GROUP BY Fraud_Risk_Level__c
        ];

        // Initialize counts
        data.criticalEvents24h = 0;
        data.totalAssessments24h = 0;

        for (AggregateResult ar : results24h) {
            String riskLevel = (String) ar.get('Fraud_Risk_Level__c');
            Integer count = (Integer) ar.get('eventCount');

            if (riskLevel == 'CRITICAL') {
                data.criticalEvents24h += count;
            }
            data.totalAssessments24h += count;
        }

        // Get recent critical events from the last 7 days
        data.recentCriticalEvents = [
            SELECT Id, SignerName__c, Status__c, Fraud_Risk_Level__c, Fraud_Analysis_Details__c, CreatedDate
            FROM Signature_Request__c
            WHERE CreatedDate = LAST_N_DAYS:7
            AND Fraud_Risk_Level__c = 'CRITICAL'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        return data;
    }
}
