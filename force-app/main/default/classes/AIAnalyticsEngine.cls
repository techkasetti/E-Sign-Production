public with sharing class AIAnalyticsEngine {

    /* ---------------------------
       Supporting data classes
       --------------------------- */

    public class BottleneckPrediction {
        @AuraEnabled public String component;
        @AuraEnabled public String bottleneckType;
        @AuraEnabled public Decimal severity;
        @AuraEnabled public Datetime predictedTime;
        @AuraEnabled public String description;
        @AuraEnabled public List<String> mitigation;
        public BottleneckPrediction() {
            mitigation = new List<String>();
        }
    }

    public class RiskTrend {
        @AuraEnabled public String riskId;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal score;
        @AuraEnabled public Datetime timestamp;
        public RiskTrend() {}
    }

    public class ChurnPrediction {
        @AuraEnabled public String userId;
        @AuraEnabled public Decimal churnProbability;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public List<String> indicators;
        @AuraEnabled public List<String> retentionActions;
        public ChurnPrediction() {
            indicators = new List<String>();
            retentionActions = new List<String>();
        }
    }

    public class CapacityRecommendation {
        @AuraEnabled public String resourceType;
        @AuraEnabled public String action;
        @AuraEnabled public Decimal currentUtilization;
        @AuraEnabled public Decimal projectedUtilization;
        @AuraEnabled public String timeframe;
        @AuraEnabled public Decimal estimatedCostImpact;
        public CapacityRecommendation() {}
    }

    public class PredictedOutcome {
        @AuraEnabled public String requestId;
        @AuraEnabled public String signerEmail;
        @AuraEnabled public Decimal completionProbability;
        @AuraEnabled public Integer estimatedDays;
        @AuraEnabled public Decimal confidenceLevel;
        @AuraEnabled public List<String> riskFactors;
        @AuraEnabled public List<String> recommendations;
        public PredictedOutcome() {
            riskFactors = new List<String>();
            recommendations = new List<String>();
        }
    }

    public class VolumeForecast {
        @AuraEnabled public Date forecastDate;
        @AuraEnabled public Integer predictedVolume;
        @AuraEnabled public Decimal confidence;
        @AuraEnabled public String category;
        public VolumeForecast() {}
    }

    public class BehavioralAnomaly {
        @AuraEnabled public String anomalyId;
        @AuraEnabled public String description;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal severity;
        @AuraEnabled public Datetime detectedAt;
        @AuraEnabled public List<String> affectedUsers;
        public BehavioralAnomaly() {
            affectedUsers = new List<String>();
            detectedAt = System.now();
        }
    }

    public class EngagementScore {
        @AuraEnabled public String userId;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String segment;
        @AuraEnabled public List<String> factors;
        public EngagementScore() {
            factors = new List<String>();
        }
    }

    public class AbandonmentPoint {
        @AuraEnabled public String pointId;
        @AuraEnabled public String description;
        @AuraEnabled public Integer userCount;
        @AuraEnabled public Integer stepNumber;
        @AuraEnabled public List<String> reasons;
        public AbandonmentPoint() {
            reasons = new List<String>();
        }
    }

    public class UsageCluster {
        @AuraEnabled public String clusterId;
        @AuraEnabled public String clusterName;
        @AuraEnabled public String description;
        @AuraEnabled public Integer userCount;
        @AuraEnabled public List<String> usagePatterns;
        @AuraEnabled public Decimal avgEngagementScore;
        public UsageCluster() {
            usagePatterns = new List<String>();
        }
    }

    public class AttackPattern {
        @AuraEnabled public String patternId;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Integer occurrenceCount;
        @AuraEnabled public List<String> affectedComponents;
        public AttackPattern() {
            affectedComponents = new List<String>();
        }
    }

    public class AnomalyAlert {
        @AuraEnabled public String type;
        @AuraEnabled public String description;
        @AuraEnabled public String severity;
        @AuraEnabled public Datetime timestamp;
        @AuraEnabled public String recordId;
        @AuraEnabled public Decimal magnitude;
        @AuraEnabled public Decimal mlScore;
        @AuraEnabled public Decimal frequency;
        @AuraEnabled public String context;
        @AuraEnabled public Decimal historicalDeviation;
        @AuraEnabled public List<String> suggestedActions;
        public AnomalyAlert() {
            suggestedActions = new List<String>();
            timestamp = System.now();
        }
        public AnomalyAlert(String type, String description, Decimal magnitude, Datetime timestamp, String severity, String recordId) {
            this.type = type;
            this.description = description;
            this.magnitude = magnitude;
            this.timestamp = timestamp;
            this.severity = severity;
            this.recordId = recordId;
            this.suggestedActions = new List<String>();
        }
    }

    public class ForecastDataPoint {
        @AuraEnabled public Date forecastDate;
        @AuraEnabled public Decimal predictedValue;
        @AuraEnabled public Decimal confidenceInterval;
        @AuraEnabled public String metric;
        @AuraEnabled public Decimal historicalValue;
        @AuraEnabled public Decimal trend;
        public ForecastDataPoint() {}
    }

    public class MLPredictionResult {
        public Decimal probability;
        public Integer estimatedDays;
        public Decimal confidence;
        public List<String> riskFactors;
        public Map<String, Object> featureImportance;
        public MLPredictionResult() {
            riskFactors = new List<String>();
            featureImportance = new Map<String, Object>();
        }
    }

    public class UserSegment {
        @AuraEnabled public String segmentId;
        @AuraEnabled public String segmentName;
        @AuraEnabled public String description;
        @AuraEnabled public Integer userCount;
        @AuraEnabled public List<String> characteristics;
        @AuraEnabled public List<String> recommendedActions;
        @AuraEnabled public Decimal avgEngagementScore;
        public UserSegment() {
            characteristics = new List<String>();
            recommendedActions = new List<String>();
        }
    }

    public class AIRecommendation implements Comparable {
        @AuraEnabled public String category;
        @AuraEnabled public String priority;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String impact;
        @AuraEnabled public String effort;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String estimatedImprovement;
        @AuraEnabled public List<String> implementationSteps;
        @AuraEnabled public Decimal confidenceScore;
        @AuraEnabled public Datetime generatedDate;
        public AIRecommendation() {
            implementationSteps = new List<String>();
            generatedDate = System.now();
        }
        public Integer compareTo(Object compareTo) {
            AIRecommendation other = (AIRecommendation) compareTo;
            Map<String, Integer> weight = new Map<String, Integer>{ 'High' => 3, 'Medium' => 2, 'Low' => 1 };
            Integer thisP = weight.containsKey(this.priority) ? weight.get(this.priority) : 2;
            Integer otherP = weight.containsKey(other.priority) ? weight.get(other.priority) : 2;
            if (thisP > otherP) return -1;
            if (thisP < otherP) return 1;
            Integer thisI = weight.containsKey(this.impact) ? weight.get(this.impact) : 2;
            Integer otherI = weight.containsKey(other.impact) ? weight.get(other.impact) : 2;
            if (thisI > otherI) return -1;
            if (thisI < otherI) return 1;
            return 0;
        }
    }

    public class SystemResourceMetrics {
        @AuraEnabled public Decimal cpuUtilization;
        @AuraEnabled public Decimal memoryUtilization;
        @AuraEnabled public Decimal diskUtilization;
        @AuraEnabled public Decimal networkUtilization;
        @AuraEnabled public Datetime lastUpdated;
    }

    public class StorageOptimization {
        @AuraEnabled public String category;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal currentSize;
        @AuraEnabled public Decimal optimizedSize;
        @AuraEnabled public Decimal savingsPercentage;
        @AuraEnabled public String action;
    }

    public class ScalingRecommendation {
        @AuraEnabled public String component;
        @AuraEnabled public String recommendationType;
        @AuraEnabled public String rationale;
        @AuraEnabled public Decimal estimatedCostChange;
        @AuraEnabled public String priority;
    }

    /* ---------------------------
       Constants
       --------------------------- */
    private static final String ML_ENDPOINT = 'callout:ML_Service';
    private static final Decimal ANOMALY_THRESHOLD = 0.75;
    private static final Integer PREDICTION_HORIZON_DAYS = 30;

    /* ---------------------------
       Public entrypoints
       --------------------------- */

    @AuraEnabled
    public static Map<String, Object> generateAnalyticsDashboard(String timeRange, List<String> metrics) {
        Map<String, Object> dashboard = new Map<String, Object>();
        Date startDate = calculateStartDate(timeRange);

        try {
            dashboard.put('performanceMetrics', calculatePerformanceMetrics(startDate));
            dashboard.put('predictiveInsights', generatePredictiveInsights(startDate));
            dashboard.put('behaviorAnalysis', analyzeUserBehaviorPatterns(startDate));
            dashboard.put('securityAnalytics', generateSecurityAnalytics(startDate));
            dashboard.put('costOptimization', analyzeCostOptimization(startDate));
            dashboard.put('userSatisfaction', calculateUserSatisfactionMetrics(startDate));
        } catch (Exception e) {
            dashboard.put('error', 'generateAnalyticsDashboard failed: ' + e.getMessage());
        }
        return dashboard;
    }

    /* ---------------------------
       Core analytics methods
       --------------------------- */

    private static Map<String, Object> calculatePerformanceMetrics(Date startDate) {
        Map<String, Object> metrics = new Map<String, Object>();
        try {
            // Document generation metrics aggregate
            List<AggregateResult> docStats = [
                SELECT COUNT(Id) totalDocuments,
                       AVG(Generation_Time_Seconds__c) avgGenerationTime,
                       MAX(Generation_Time_Seconds__c) maxGenerationTime,
                       MIN(Generation_Time_Seconds__c) minGenerationTime
                FROM DocumentLifecycleConfiguration__c
                WHERE CreatedDate >= :startDate
            ];

            if (!docStats.isEmpty()) {
                AggregateResult ar = docStats[0];
                Map<String, Object> docMetrics = new Map<String, Object>();
                docMetrics.put('totalDocuments', (Integer) ar.get('totalDocuments'));
                docMetrics.put('avgGenerationTime', (Decimal) ar.get('avgGenerationTime'));
                docMetrics.put('maxGenerationTime', (Decimal) ar.get('maxGenerationTime'));
                docMetrics.put('minGenerationTime', (Decimal) ar.get('minGenerationTime'));
                Decimal avgTime = (Decimal) ar.get('avgGenerationTime') != null ? (Decimal) ar.get('avgGenerationTime') : 0;
                docMetrics.put('performanceGrade', calculatePerformanceGrade(avgTime));
                metrics.put('documentMetrics', docMetrics);
            }

            // Signature metrics grouped by status
            List<AggregateResult> sigStats = [
                SELECT Status__c status, COUNT(Id) cnt, AVG(Time_To_Complete_Hours__c) avgTime
                FROM Signature_Request__c
                WHERE CreatedDate >= :startDate
                GROUP BY Status__c
            ];
            Integer totalRequests = 0;
            Integer completedRequests = 0;
            Integer rejectedRequests = 0;
            Decimal avgCompletionTime = 0;
            for (AggregateResult gr : sigStats) {
                Integer cnt = (Integer) gr.get('cnt');
                totalRequests += cnt;
                String st = (String) gr.get('status');
                if (st == 'Completed') {
                    completedRequests = cnt;
                    avgCompletionTime = (Decimal) gr.get('avgTime') != null ? (Decimal) gr.get('avgTime') : avgCompletionTime;
                } else if (st == 'Rejected') {
                    rejectedRequests = cnt;
                }
            }
            Map<String, Object> sigMetrics = new Map<String, Object>();
            sigMetrics.put('totalRequests', totalRequests);
            sigMetrics.put('completedRequests', completedRequests);
            sigMetrics.put('rejectedRequests', rejectedRequests);
            sigMetrics.put('avgCompletionTime', avgCompletionTime);
            if (totalRequests > 0) {
                sigMetrics.put('completionRate', (completedRequests * 100.0) / totalRequests);
                sigMetrics.put('rejectionRate', (rejectedRequests * 100.0) / totalRequests);
            }
            metrics.put('signatureMetrics', sigMetrics);

            // Resource metrics & error metrics
            metrics.put('resourceMetrics', calculateResourceMetrics(startDate));
            metrics.put('errorMetrics', calculateErrorMetrics(startDate));

        } catch (Exception e) {
            metrics.put('error', 'Performance metrics calculation failed: ' + e.getMessage());
        }
        return metrics;
    }

    private static Map<String, Object> generatePredictiveInsights(Date startDate) {
        Map<String, Object> insights = new Map<String, Object>();
        try {
            insights.put('completionPredictions', predictSignatureCompletions());
            insights.put('volumeForecasts', forecastDocumentVolume(startDate));
            insights.put('bottleneckPredictions', predictPerformanceBottlenecks());
            insights.put('churnPredictions', predictUserChurn(startDate));
            insights.put('capacityRecommendation', recommendCapacityChanges(startDate));
            insights.put('seasonalTrends', analyzeSeasonalTrends(startDate));
        } catch (Exception e) {
            insights.put('error', 'Predictive insights generation failed: ' + e.getMessage());
        }
        return insights;
    }

    private static Map<String, Object> analyzeUserBehaviorPatterns(Date startDate) {
        Map<String, Object> behaviorAnalysis = new Map<String, Object>();
        try {
            behaviorAnalysis.put('userSegments', performUserSegmentation(startDate));
            behaviorAnalysis.put('usageClusters', clusterUsagePatterns(startDate));
            behaviorAnalysis.put('journeyAnalysis', analyzeUserJourneys(startDate));
            behaviorAnalysis.put('abandonmentPoints', identifyAbandonmentPoints(startDate));
            behaviorAnalysis.put('engagementScores', calculateEngagementScores(startDate));
            behaviorAnalysis.put('behavioralAnomalies', detectBehavioralAnomalies(startDate));
        } catch (Exception e) {
            behaviorAnalysis.put('error', 'Behavior analysis failed: ' + e.getMessage());
        }
        return behaviorAnalysis;
    }

    private static Map<String, Object> generateSecurityAnalytics(Date startDate) {
        Map<String, Object> securityAnalytics = new Map<String, Object>();
        try {
            securityAnalytics.put('threatIntelligence', generateThreatIntelligence(startDate));
            securityAnalytics.put('riskTrends', analyzeRiskScoreTrends(startDate));
            securityAnalytics.put('attackPatterns', identifyAttackPatterns(startDate));
            securityAnalytics.put('vulnerabilityAssessment', performVulnerabilityAssessment());
            securityAnalytics.put('geoRiskAnalysis', analyzeGeographicRisks(startDate));
            securityAnalytics.put('securityPostureScore', calculateSecurityPostureScore(startDate));
        } catch (Exception e) {
            securityAnalytics.put('error', 'Security analytics generation failed: ' + e.getMessage());
        }
        return securityAnalytics;
    }

    /* ---------------------------
       Stubs and helper methods
       --------------------------- */

    private static Date calculateStartDate(String timeRange) {
        if (timeRange == 'Last30Days') return Date.today().addDays(-30);
        if (timeRange == 'Last7Days') return Date.today().addDays(-7);
        if (timeRange == 'Today') return Date.today();
        return Date.today().addDays(-30);
    }

    private static List<BehavioralAnomaly> detectBehavioralAnomalies(Date startDate) {
        List<BehavioralAnomaly> anomalies = new List<BehavioralAnomaly>();
        BehavioralAnomaly a = new BehavioralAnomaly();
        a.anomalyId = 'BA-001';
        a.description = 'Unusual login pattern detected';
        a.type = 'Login';
        a.severity = 0.7;
        a.affectedUsers.add('U-001');
        anomalies.add(a);
        return anomalies;
    }

    private static List<BottleneckPrediction> predictPerformanceBottlenecks() {
    List<BottleneckPrediction> bottlenecks = new List<BottleneckPrediction>();
    BottleneckPrediction bp = new BottleneckPrediction();
    bp.component = 'API';
    bp.bottleneckType = 'RateLimit';
    bp.severity = 0.8;
    bp.predictedTime = System.now().addDays(1);
    bp.description = 'API rate limit may be reached soon.';
    bp.mitigation.add('Optimize API calls');
    bottlenecks.add(bp);
    return bottlenecks;
    }

    private static List<RiskTrend> analyzeRiskScoreTrends(Date startDate) {
        List<RiskTrend> trends = new List<RiskTrend>();
        RiskTrend t = new RiskTrend();
        t.riskId = 'RISK-001';
        t.name = 'Phishing';
        t.description = 'Phishing attempts detected';
        t.score = 0.3;
        t.timestamp = System.now();
        trends.add(t);
        return trends;
    }

    private static List<ChurnPrediction> predictUserChurn(Date startDate) {
        List<ChurnPrediction> churns = new List<ChurnPrediction>();
        ChurnPrediction cp = new ChurnPrediction();
        cp.userId = 'U-001';
        cp.churnProbability = 0.2;
        cp.riskLevel = 'Low';
        cp.indicators.add('Low engagement');
        cp.retentionActions.add('Send survey');
        churns.add(cp);
        return churns;
    }

    private static CapacityRecommendation recommendCapacityChanges(Date startDate) {
        CapacityRecommendation rec = new CapacityRecommendation();
        rec.resourceType = 'Storage';
        rec.action = 'Scale Up';
        rec.currentUtilization = 80.0;
        rec.projectedUtilization = 95.0;
        rec.timeframe = 'Next Month';
        rec.estimatedCostImpact = 500.0;
        return rec;
    }

    private static Map<String, Object> calculateErrorMetrics(Date startDate) {
        Map<String, Object> errorMetrics = new Map<String, Object>();
        // simplified safe defaults
        Integer totalAttempts = 0;
        Integer errorCount = 0;
        try {
            List<AggregateResult> grp = [
                SELECT COUNT(Id) cnt, Status__c status
                FROM Signature_Request__c
                WHERE CreatedDate >= :startDate
                GROUP BY Status__c
            ];
            for (AggregateResult ar : grp) {
                Integer cnt = (Integer) ar.get('cnt');
                totalAttempts += cnt;
                if ((String) ar.get('status') == 'Error') errorCount += cnt;
            }
        } catch (Exception e) {
            // swallow; return defaults
        }
        errorMetrics.put('totalAttempts', totalAttempts);
        errorMetrics.put('errorCount', errorCount);
        errorMetrics.put('errorRate', totalAttempts > 0 ? (errorCount * 100.0) / totalAttempts : 0);
        return errorMetrics;
    }

    private static List<PredictedOutcome> predictSignatureCompletions() {
        List<PredictedOutcome> preds = new List<PredictedOutcome>();
        PredictedOutcome po = new PredictedOutcome();
        po.requestId = 'REQ-001';
        po.signerEmail = 'user@example.com';
        po.completionProbability = 0.95;
        po.estimatedDays = 2;
        po.confidenceLevel = 0.9;
        po.riskFactors.add('None');
        po.recommendations.add('Send reminder');
        preds.add(po);
        return preds;
    }

    private static List<VolumeForecast> forecastDocumentVolume(Date startDate) {
    List<VolumeForecast> forecasts = new List<VolumeForecast>();
    VolumeForecast vf = new VolumeForecast();
    vf.forecastDate = Date.today().addDays(1);
    vf.predictedVolume = 100;
    vf.confidence = 0.9;
    vf.category = 'General';
    forecasts.add(vf);
    return forecasts;
    }

    private static String calculatePerformanceGrade(Decimal avgTime) {
        if (avgTime == null) avgTime = 9999;
        if (avgTime <= 5) return 'A';
        if (avgTime <= 10) return 'B';
        if (avgTime <= 20) return 'C';
        if (avgTime <= 30) return 'D';
        return 'F';
    }

    private static Map<String, Object> calculateResourceMetrics(Date startDate) {
        Map<String, Object> resourceMetrics = new Map<String, Object>();
        resourceMetrics.put('cpuUtilization', 50.0);
        resourceMetrics.put('memoryUtilization', 60.0);
        resourceMetrics.put('diskUtilization', 40.0);
        resourceMetrics.put('networkUtilization', 30.0);
        resourceMetrics.put('lastUpdated', System.now());
        return resourceMetrics;
    }

    // ----- small stubs for many referenced methods so class compiles ----- //

    private static List<AbandonmentPoint> identifyAbandonmentPoints(Date startDate) {
        List<AbandonmentPoint> points = new List<AbandonmentPoint>();
        AbandonmentPoint p = new AbandonmentPoint();
        p.pointId = 'AP-001';
        p.description = 'Step 3: Document review';
        p.userCount = 20;
        p.stepNumber = 3;
        p.reasons.add('Confusing instructions');
        points.add(p);
        return points;
    }

    private static List<EngagementScore> calculateEngagementScores(Date startDate) {
        List<EngagementScore> scores = new List<EngagementScore>();
        EngagementScore s = new EngagementScore();
        s.userId = 'U-001';
        s.score = 95.0;
        s.segment = 'Active Users';
        s.factors.add('High login frequency');
        scores.add(s);
        return scores;
    }

    private static List<UsageCluster> clusterUsagePatterns(Date startDate) {
        List<UsageCluster> clusters = new List<UsageCluster>();
        UsageCluster c = new UsageCluster();
        c.clusterId = 'CL-001';
        c.clusterName = 'Frequent Users';
        c.description = 'Users with frequent activity';
        c.userCount = 50;
        c.usagePatterns.add('Daily login');
        c.avgEngagementScore = 90.0;
        clusters.add(c);
        return clusters;
    }

    private static Map<String, Object> analyzeUserJourneys(Date startDate) {
        Map<String, Object> journey = new Map<String, Object>();
        journey.put('averageSteps', 5);
        journey.put('commonDropOffStep', 3);
        journey.put('recommendations', new List<String>{'Reduce steps', 'Add tooltips'});
        return journey;
    }

    private static Map<String, Object> generateThreatIntelligence(Date startDate) {
        Map<String, Object> threat = new Map<String, Object>();
        threat.put('threatLevel', 'Low');
        threat.put('recentIncidents', 0);
        threat.put('recommendations', new List<String>{'Monitor login attempts', 'Review access logs'});
        return threat;
    }

    private static List<AttackPattern> identifyAttackPatterns(Date startDate) {
    List<AttackPattern> attackPatterns = new List<AttackPattern>();
    return attackPatterns;
    }

    private static Object performVulnerabilityAssessment() {
        return new Map<String, Object>{ 'status' => 'NotImplemented' };
    }

    private static Map<String, Object> analyzeGeographicRisks(Date startDate) {
        return new Map<String, Object>{ 'regions' => new List<String>() };
    }

    private static Object calculateSecurityPostureScore(Date startDate) {
        return new Map<String, Object>{ 'score' => 85 };
    }

    private static List<AIRecommendation> generateAIRecommendations(Date startDate) {
        return new List<AIRecommendation>();
    }

    private static List<AnomalyAlert> detectRealTimeAnomalies() {
        // combine other anomaly detectors and score them
        List<AnomalyAlert> all = new List<AnomalyAlert>();
        all.addAll(detectDocumentGenerationAnomalies());
        all.addAll(detectSignatureRequestAnomalies());
        // simple ML scoring pass (stubs)
        for (AnomalyAlert a : all) {
            a.mlScore = calculateMLAnomalyScore(a);
            // convert mlScore to severity label if needed
            a.severity = a.mlScore >= ANOMALY_THRESHOLD ? 'HIGH' : 'MEDIUM';
        }
        List<AnomalyAlert> significant = new List<AnomalyAlert>();
        for (AnomalyAlert a : all) {
            if (a.mlScore >= ANOMALY_THRESHOLD) significant.add(a);
        }
        return significant;
    }

    private static Decimal calculateMLAnomalyScore(AnomalyAlert anomaly) {
        // safe stub: small deterministic score calculation to avoid external call
        if (anomaly == null) return 0.5;
        Decimal base = 0.5;
        if (anomaly.magnitude != null) base = Math.min(1.0, base + (anomaly.magnitude / 10));
        return base;
    }

    public static List<AnomalyAlert> detectDocumentGenerationAnomalies() {
        List<AnomalyAlert> anomalies = new List<AnomalyAlert>();
        try {
            Datetime oneHourAgo = System.now().addHours(-1);
            List<DocumentLifecycleConfiguration__c> slowDocs = [
                SELECT Id, DocumentTitle__c, Generation_Time_Seconds__c, CreatedDate
                FROM DocumentLifecycleConfiguration__c
                WHERE CreatedDate >= :oneHourAgo
                AND Generation_Time_Seconds__c > 30
                ORDER BY Generation_Time_Seconds__c DESC
                LIMIT 10
            ];
            for (DocumentLifecycleConfiguration__c doc : slowDocs) {
                AnomalyAlert anomaly = new AnomalyAlert();
                anomaly.type = 'SLOW_DOCUMENT_GENERATION';
                anomaly.description = 'Document "' + doc.DocumentTitle__c + '" took ' + doc.Generation_Time_Seconds__c + ' seconds';
                anomaly.magnitude = doc.Generation_Time_Seconds__c != null ? doc.Generation_Time_Seconds__c / 5.0 : 1.0;
                anomaly.timestamp = doc.CreatedDate;
                anomaly.recordId = doc.Id;
                anomaly.severity = 'MEDIUM';
                anomalies.add(anomaly);
            }
        } catch (Exception e) {
            AnomalyAlert err = new AnomalyAlert();
            err.type = 'ANOMALY_DETECTION_ERROR';
            err.description = 'Detection failed: ' + e.getMessage();
            err.severity = 'MEDIUM';
            anomalies.add(err);
        }
        return anomalies;
    }

    public static List<AnomalyAlert> detectSignatureRequestAnomalies() {
        List<AnomalyAlert> anomalies = new List<AnomalyAlert>();
        try {
            Datetime oneHourAgo = System.now().addHours(-1);
            List<AggregateResult> signingPatterns = [
                SELECT SignerEmail__c signer,
                       COUNT(Id) signatureCount,
                       AVG(Time_To_Complete_Hours__c) avgCompletionTime
                FROM Signature_Request__c
                WHERE CreatedDate >= :oneHourAgo
                AND Status__c = 'Completed'
                GROUP BY SignerEmail__c
                HAVING COUNT(Id) > 5
            ];
            for (AggregateResult pattern : signingPatterns) {
                String signerEmail = (String) pattern.get('signer');
                Integer signatureCount = (Integer) pattern.get('signatureCount');
                Decimal avgCompletionTime = (Decimal) pattern.get('avgCompletionTime');
                if (signatureCount > 10) {
                    anomalies.add(new AnomalyAlert('RAPID_SIGNING', 'User ' + signerEmail + ' completed ' + signatureCount + ' signatures in 1 hour', signatureCount / 3.0, System.now(), 'HIGH', null));
                }
                if (avgCompletionTime != null && avgCompletionTime < 0.1) {
                    anomalies.add(new AnomalyAlert('ULTRA_FAST_SIGNING', 'User ' + signerEmail + ' averaged ' + (avgCompletionTime * 60).setScale(0) + ' minutes per signature', 10.0 / (avgCompletionTime * 60), System.now(), 'MEDIUM', null));
                }
            }

            // Rejection rate spikes
            List<AggregateResult> rejectionStats = [
                SELECT Status__c status, COUNT(Id) cnt
                FROM Signature_Request__c
                WHERE CreatedDate >= :oneHourAgo
                GROUP BY Status__c
            ];
            Integer totalRequests = 0;
            Integer rejectedRequests = 0;
            for (AggregateResult ar : rejectionStats) {
                Integer cnt = (Integer) ar.get('cnt');
                totalRequests += cnt;
                if ((String) ar.get('status') == 'Rejected') rejectedRequests = cnt;
            }
            if (totalRequests > 0) {
                Decimal rejectionRate = (rejectedRequests * 100.0) / totalRequests;
                if (rejectionRate > 20.0) {
                    anomalies.add(new AnomalyAlert('HIGH_REJECTION_RATE', 'High signature rejection rate: ' + rejectionRate.setScale(1) + '%', rejectionRate / 10.0, System.now(), 'HIGH', null));
                }
            }

        } catch (Exception e) {
            anomalies.add(new AnomalyAlert('ANOMALY_DETECTION_ERROR', 'Signature request anomaly detection failed: ' + e.getMessage(), null, System.now(), 'MEDIUM', null));
        }
        return anomalies;
    }

    private static Map<String, Object> analyzeCostOptimization(Date startDate) {
        Map<String, Object> costAnalysis = new Map<String, Object>();
        try {
            costAnalysis.put('resourceCosts', calculateResourceCosts(startDate));
            costAnalysis.put('efficiencyMetrics', calculateProcessingEfficiency(startDate));
            costAnalysis.put('storageOptimizations', identifyStorageOptimizations());
            costAnalysis.put('apiOptimizations', analyzeAPIUsageOptimization(startDate));
            costAnalysis.put('scalingRecommendations', generateScalingRecommendations());
            costAnalysis.put('roiAnalysis', calculateROIMetrics(startDate));
        } catch (Exception e) {
            costAnalysis.put('error', 'Cost optimization analysis failed: ' + e.getMessage());
        }
        return costAnalysis;
    }

    private static Map<String, Object> calculateResourceCosts(Date startDate) {
        return new Map<String, Object>{ 'monthlyCost' => 1200.0 };
    }
    private static Map<String, Object> calculateProcessingEfficiency(Date startDate) {
        return new Map<String, Object>{ 'efficiency' => 92.0 };
    }
    private static List<StorageOptimization> identifyStorageOptimizations() {
        return new List<StorageOptimization>();
    }
    private static Map<String, Object> analyzeAPIUsageOptimization(Date startDate) {
        return new Map<String, Object>{ 'recommendations' => new List<String>() };
    }
    private static List<ScalingRecommendation> generateScalingRecommendations() {
        return new List<ScalingRecommendation>();
    }
    private static Map<String, Object> calculateROIMetrics(Date startDate) {
        return new Map<String, Object>{ 'estimatedROI' => 1.2 };
    }

    private static Map<String, Object> calculateUserSatisfactionMetrics(Date startDate) {
        Map<String, Object> satisfaction = new Map<String, Object>();
        try {
            // Completion metrics via queries
            List<AggregateResult> completionMetrics = [
                SELECT COUNT(Id) totalCompleted, AVG(Time_To_Complete_Hours__c) avgCompletionTime
                FROM Signature_Request__c
                WHERE Status__c = 'Completed'
                AND CreatedDate >= :startDate
            ];
            Integer totalCompleted = 0;
            Decimal avgCompletionTime = 0;
            if (!completionMetrics.isEmpty()) {
                AggregateResult ar = completionMetrics[0];
                totalCompleted = (Integer) ar.get('totalCompleted') != null ? (Integer) ar.get('totalCompleted') : 0;
                avgCompletionTime = (Decimal) ar.get('avgCompletionTime') != null ? (Decimal) ar.get('avgCompletionTime') : 0;
            }
            Map<String, Object> completionSatisfaction = new Map<String, Object>();
            completionSatisfaction.put('averageCompletionTime', avgCompletionTime);
            Integer fastCompletions = [ SELECT COUNT() FROM Signature_Request__c WHERE Status__c = 'Completed' AND CreatedDate >= :startDate AND Time_To_Complete_Hours__c <= 1 ];
            completionSatisfaction.put('fastCompletionRate', totalCompleted > 0 ? (fastCompletions * 100.0) / totalCompleted : 0);
            completionSatisfaction.put('satisfactionScore', calculateCompletionSatisfactionScore(avgCompletionTime));
            satisfaction.put('completionSatisfaction', completionSatisfaction);

            // Error rate impact
            List<AggregateResult> groupedErrors = [
                SELECT COUNT(Id) cnt, Status__c status
                FROM Signature_Request__c
                WHERE CreatedDate >= :startDate
                GROUP BY Status__c
            ];
            Integer totalAttemptsLocal = 0;
            Integer errorCountLocal = 0;
            for (AggregateResult gr : groupedErrors) {
                Integer cnt = (Integer) gr.get('cnt');
                totalAttemptsLocal += cnt;
                if ((String) gr.get('status') == 'Error') errorCountLocal = cnt;
            }
            Map<String, Object> errorMetrics = new Map<String, Object>();
            errorMetrics.put('totalAttempts', totalAttemptsLocal);
            errorMetrics.put('errorCount', errorCountLocal);
            errorMetrics.put('errorRate', totalAttemptsLocal > 0 ? (errorCountLocal * 100.0) / totalAttemptsLocal : 0);
            satisfaction.put('errorMetrics', errorMetrics);

            satisfaction.put('journeySatisfaction', analyzeUserJourneySatisfaction(startDate));
            satisfaction.put('deviceSatisfaction', analyzeDeviceExperienceSatisfaction(startDate));

            Decimal overallScore = calculateOverallSatisfactionScore(satisfaction);
            satisfaction.put('overallSatisfactionScore', overallScore);
            satisfaction.put('satisfactionGrade', getGradeFromScore(overallScore));

        } catch (Exception e) {
            satisfaction.put('error', 'User satisfaction metrics calculation failed: ' + e.getMessage());
        }
        return satisfaction;
    }

    private static Decimal calculateCompletionSatisfactionScore(Decimal avgCompletionTime) {
        if (avgCompletionTime == null) return 40.0;
        if (avgCompletionTime <= 1) return 100.0;
        if (avgCompletionTime <= 2) return 80.0;
        if (avgCompletionTime <= 4) return 60.0;
        return 40.0;
    }

    private static Map<String, Object> analyzeUserJourneySatisfaction(Date startDate) {
        Map<String, Object> journey = new Map<String, Object>();
        journey.put('stepsCompleted', 85.0);
        journey.put('dropOffRate', 15.0);
        journey.put('recommendations', new List<String>{'Simplify signature steps', 'Improve in-app guidance'});
        return journey;
    }

    private static Map<String, Object> analyzeDeviceExperienceSatisfaction(Date startDate) {
        Map<String, Object> deviceExp = new Map<String, Object>();
        deviceExp.put('mobileCompletionRate', 70.0);
        deviceExp.put('desktopCompletionRate', 90.0);
        deviceExp.put('recommendations', new List<String>{'Optimize mobile UI', 'Improve mobile loading times'});
        return deviceExp;
    }

    private static String getGradeFromScore(Decimal score) {
        if (score == null) return 'C';
        if (score >= 90) return 'A';
        if (score >= 75) return 'B';
        if (score >= 60) return 'C';
        if (score >= 40) return 'D';
        return 'F';
    }

    private static Decimal calculateOverallSatisfactionScore(Map<String, Object> satisfaction) {
        Decimal totalScore = 0;
        Integer count = 0;
        for (String key : satisfaction.keySet()) {
            Object value = satisfaction.get(key);
            if (value instanceof Map<String, Object>) {
                Map<String, Object> sub = (Map<String, Object>) value;
                if (sub.containsKey('satisfactionScore')) {
                    totalScore += (Decimal) sub.get('satisfactionScore');
                    count++;
                }
            }
        }
        return count > 0 ? (totalScore / count) : 80.0;
    }

    private static Map<String, Object> analyzeSeasonalTrends(Date startDate) {
        Map<String, Object> trends = new Map<String, Object>();
        trends.put('season', 'Winter');
        trends.put('trendScore', 0.85);
        trends.put('recommendations', new List<String>{'Increase marketing in winter', 'Monitor usage spikes'});
        return trends;
    }

    private static List<UserSegment> performUserSegmentation(Date startDate) {
        List<UserSegment> segments = new List<UserSegment>();
        UserSegment seg = new UserSegment();
        seg.segmentId = 'SEG-001';
        seg.segmentName = 'Active Users';
        seg.description = 'Users with high engagement';
        seg.userCount = 100;
        seg.characteristics.add('High login frequency');
        seg.recommendedActions.add('Send rewards');
        seg.avgEngagementScore = 95.0;
        segments.add(seg);
        return segments;
    }

} // end class AIAnalyticsEngine