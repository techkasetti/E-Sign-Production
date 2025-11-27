public with sharing class DocumentAnalysisService {

    // Main entry point used by the LWC
    @AuraEnabled(cacheable=false)
    public static AnalysisResult analyzeDocumentById(String documentId) {
        if (String.isBlank(documentId)) {
            throw new AuraHandledException('Document Id is required for analysis.');
        }

        // Load the document
        DocumentLifecycleConfiguration__c doc = [
            SELECT Id, Region__c, Role__c, ContractType__c, GeneratedClause__c
            FROM DocumentLifecycleConfiguration__c
            WHERE Id = :documentId
            LIMIT 1
        ];

        String content = doc.GeneratedClause__c;

        // If content is missing, regenerate using your existing ClauseGenerator
        if (String.isBlank(content)) {
            content = ClauseGenerator.generateClause(
                doc.Region__c,
                doc.Role__c,
                doc.ContractType__c
            );
            doc.GeneratedClause__c = content;
            update doc;

            // Log that content was regenerated
            try {
                AuditTrailManager.logDocumentActivity(
                    doc.Id,
                    'CONTENT_REGENERATED',
                    'GeneratedClause__c was empty and regenerated for AI analysis.'
                );
            } catch (Exception logEx) {
                System.debug('Failed to log content regeneration: ' + logEx.getMessage());
            }
        }

        // Analyze the content
        AnalysisResult result = analyzeContent(documentId, content);

        // Log AI analysis
        try {
            AuditTrailManager.logDocumentActivity(
                documentId,
                'AI_DOCUMENT_INTELLIGENCE',
                'AI-powered document intelligence analysis executed.'
            );
        } catch (Exception logEx) {
            System.debug('Failed to log AI analysis activity: ' + logEx.getMessage());
        }

        return result;
    }

    // Core analysis logic (mocked / simplified AI)
    private static AnalysisResult analyzeContent(String documentId, String content) {
        if (String.isBlank(content)) {
            throw new AuraHandledException('Document content is empty, cannot analyze.');
        }

        AnalysisResult res = new AnalysisResult();

        // You can replace this with a real AI call later
        res.summary = 'AI analysis summary based on the current document content. ' +
            'Key clauses relate to confidentiality, termination, and liability. ' +
            'The contract appears formal and business-oriented.';
        res.risks = 'Potential risk identified in the termination and liability sections. ' +
            'They appear one-sided and may require legal review for better balance.';
        res.sentiment = 'Neutral to slightly negative from the signer’s perspective.';
        res.sentimentScore = 0.45;       // 45% neutral / negative
        res.confidenceScore = 0.92;      // 92% confidence in this analysis
        res.model = 'doc-intel-v1.0-mock';

        return res;
    }

    // DTO returned to LWC
    public class AnalysisResult {
        @AuraEnabled public String summary      { get; set; }
        @AuraEnabled public String risks        { get; set; }
        @AuraEnabled public String sentiment    { get; set; }
        @AuraEnabled public Decimal sentimentScore   { get; set; }
        @AuraEnabled public Decimal confidenceScore  { get; set; }
        @AuraEnabled public String model        { get; set; }
    }
}