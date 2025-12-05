public with sharing class SecurityDashboardController {

    @AuraEnabled(cacheable=true)
    public static SecurityDashboardData getSecurityDashboardData() {
        try {
            SecurityDashboardData dashboard = new SecurityDashboardData();
            Date yesterday = Date.today().addDays(-1);

            // Metric 1: High-Risk Events in the last 24 hours
            dashboard.highRiskEvents24h = [
                SELECT COUNT() FROM Signature_Request__c
                WHERE (Fraud_Risk_Level__c = 'HIGH' OR Fraud_Risk_Level__c = 'CRITICAL')
                AND CreatedDate >= :yesterday
            ];

            // Metric 2: Active High-Risk Threats (All time, not just 24h)
            dashboard.activeHighRiskThreats = [
                SELECT Id, SignerEmail__c, Fraud_Score__c, Fraud_Risk_Level__c, 
                       Fraud_Analysis_Details__c, CreatedDate
                FROM Signature_Request__c
                WHERE Fraud_Risk_Level__c = 'HIGH' OR Fraud_Risk_Level__c = 'CRITICAL'
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];

            return dashboard;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load security dashboard: ' + e.getMessage());
        }
    }

    // Wrapper class to hold all dashboard data
    public class SecurityDashboardData {
        @AuraEnabled public Integer highRiskEvents24h { get; set; }
        @AuraEnabled public List<Signature_Request__c> activeHighRiskThreats { get; set; }
    }
}

