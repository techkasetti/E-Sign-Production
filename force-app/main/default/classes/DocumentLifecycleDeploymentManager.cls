// force-app/main/default/classes/DocumentLifecycleDeploymentManager.cls
public with sharing class DocumentLifecycleDeploymentManager {


    // In: DocumentLifecycleDeploymentManager.cls

// Add this entire wrapper class inside your DocumentLifecycleDeploymentManager file
public class DocumentDetailsWrapper {
    @AuraEnabled
    public DocumentLifecycleConfiguration__c document;
    @AuraEnabled
    public List<Signature_Request__c> signatureRequests;

    public DocumentDetailsWrapper() {
        signatureRequests = new List<Signature_Request__c>();
    }
}

// Add this new method to the class
@AuraEnabled(cacheable=true)
public static DocumentDetailsWrapper getDocumentDetails(String documentId) {
    if (String.isBlank(documentId)) {
        throw new AuraHandledException('Document ID cannot be null.');
    }

    DocumentDetailsWrapper result = new DocumentDetailsWrapper();

    try {
        // Query for the main document record
        result.document = [
            SELECT Id, DocumentTitle__c, CreatedDate, ProcessingStatus__c, 
                   ComplianceStatus__c, GeneratedClause__c 
            FROM DocumentLifecycleConfiguration__c 
            WHERE Id = :documentId 
            LIMIT 1
        ];

        // Query for all related signature requests
        result.signatureRequests = [
            SELECT Id, SignerName__c, SignerEmail__c, Status__c, CompletedDate__c
            FROM Signature_Request__c
            WHERE DocumentId__c = :documentId
            ORDER BY CreatedDate DESC
        ];

        return result;

    } catch (Exception e) {
        throw new AuraHandledException('Error fetching document details: ' + e.getMessage());
    }
}

    
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