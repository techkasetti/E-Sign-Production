// force-app/main/default/classes/DocumentLifecycleDeploymentManager.cls
public with sharing class DocumentLifecycleDeploymentManager {
    
    @AuraEnabled(cacheable=false)
    public static String generateDocument(String region, String role, String contractType, String documentTitle) {
        try {
            String generatedClause = ClauseGenerator.generateClause(region, role, contractType);
            
            DocumentLifecycleConfiguration__c doc = new DocumentLifecycleConfiguration__c(
                Region__c = region,
                Role__c = role,
                ContractType__c = contractType,
                DocumentTitle__c = documentTitle,
                GeneratedClause__c = generatedClause,
                ProcessingStatus__c = 'Generated'
            );
            insert doc;
            System.debug('Document generated with ID: ' + doc);  
            
            AuditTrailManager.logDocumentActivity(doc.Id, 'Document Generated', 'Document record created successfully.');
            return doc.Id;
        } catch (Exception e) {
            AuditTrailManager.logSystemActivity('DOCUMENT_GENERATION_ERROR', e.getMessage());
            throw new AuraHandledException('Document generation failed: ' + e.getMessage());
        }
    }


   



}