public with sharing class SignatureRequestController {
    @AuraEnabled(cacheable=false)
    public static String initiateSignatureRequest(String documentId, String signerEmail, String signerName) {
        if (String.isBlank(documentId) || String.isBlank(signerEmail) || String.isBlank(signerName)) {
            throw new AuraHandledException('Document ID, Signer Email, and Signer Name are required.');
        }
        try {
            Signature_Request__c request = new Signature_Request__c(
                DocumentId__c = documentId,
                SignerEmail__c = signerEmail,
                SignerName__c = signerName,
                Status__c = 'Pending'
            );
            insert request;
            
// Corrected line
EmailNotificationService.sendSignatureRequest(request.Id);
            AuditTrailManager.logSignatureRequest(documentId, 'Signature Request Created', 'Signature request sent to: ' + signerEmail);
            return request.Id;
        } catch (Exception e) {
            AuditTrailManager.logSystemActivity('SIGNATURE_REQUEST_ERROR', 'Failed to initiate signature request: ' + e.getMessage());
            throw new AuraHandledException('Failed to initiate signature request: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Signature_Request__c getSignatureRequest(String requestId) {
        try {
            return [
                SELECT Id, SignerName__c, Status__c, CompletedDate__c, DocumentId__c,
                       DocumentId__r.DocumentTitle__c, DocumentId__r.GeneratedClause__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve signature request: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean submitSignature(String requestId, String signatureData, String signatureMethod, String userContextJSON) {
        try {
            // --- START: REAL-TIME THREAT ASSESSMENT ---
            System.debug('Calling Threat Assessment Engine...');
            String systemContext = '{"os":"WebApp","browser":"Chrome"}';
            String networkContext = '{"ipAddress":"8.8.8.8","isp":"Google LLC"}';
            ThreatAssessmentEngine.assessComprehensiveThreat(requestId, userContextJSON, systemContext, networkContext);
            System.debug('Threat Assessment Engine call complete.');
            // --- END: REAL-TIME THREAT ASSESSMENT ---

            Signature_Request__c request = [
                SELECT Id, Status__c, DocumentId__c, SignerEmail__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            if (request.Status__c == 'Signed' | request.Status__c == 'Completed') {
                throw new AuraHandledException('This document has already been signed.');
            }
            request.Status__c = 'Signed';
            request.CompletedDate__c = System.now();
            request.SignatureMethod__c = signatureMethod;
            update request;
            
            AuditTrailManager.logDocumentActivity(request.DocumentId__c, 'DOCUMENT_SIGNED', 'Document signed by ' + request.SignerEmail__c);
            return true;
        } catch (Exception e) {
            System.debug('Error submitting signature: ' + e.getMessage());
            throw new AuraHandledException('Failed to submit signature: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static DocumentData getDocumentData(String documentId) {
        try {
            DocumentData data = new DocumentData();
            data.document = [
                SELECT Id, DocumentTitle__c, GeneratedClause__c, Region__c, Role__c, ContractType__c, ComplianceStatus__c, CreatedDate
                FROM DocumentLifecycleConfiguration__c
                WHERE Id = :documentId
                LIMIT 1
            ];
            data.signatureRequests = [
                SELECT Id, SignerName__c, SignerEmail__c, Status__c, CreatedDate, CompletedDate__c
                FROM Signature_Request__c
                WHERE DocumentId__c = :documentId
                ORDER BY CreatedDate DESC
            ];
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve document data: ' + e.getMessage());
        }
    }

    public class DocumentData {
        @AuraEnabled public DocumentLifecycleConfiguration__c document { get; set; }
        @AuraEnabled public List<Signature_Request__c> signatureRequests { get; set; }
    }
}

