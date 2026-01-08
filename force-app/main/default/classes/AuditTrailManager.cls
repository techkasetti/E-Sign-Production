

public with sharing class AuditTrailManager {
    @AuraEnabled
    
public static String getPdfDownloadUrl(Id documentId) {
    // Example VF page name: DocumentPdf
    return '/apex/DocumentPdf?id=' + documentId;
}


    /**
     * @description Logs a generic document-related activity.
     * @param documentId The ID of the DocumentLifecycleConfiguration__c record.
     * @param action The action being performed (e.g., 'DOCUMENT_VIEWED').
     * @param details Additional details about the event.
     */
    @AuraEnabled
    public static void logDocumentActivity(String documentId, String action, String details) {
        try {
            AuditTrail__c audit = new AuditTrail__c(
                DocumentId__c = documentId,
                Action__c = action,
                Status__c = 'SUCCESS',
                Details__c = details,
                Timestamp__c = System.now(),
                UserId__c = UserInfo.getUserId()
            );
            insert audit;
        } catch (Exception e) {
            System.debug('Failed to log document activity: ' + e.getMessage());
        }
    }

    /**
     * @description Logs a signature-related activity.
     * @param signatureRequestId The ID of the Signature_Request__c record.
     * @param action The signature action (e.g., 'SIGNATURE_REQUEST_SENT').
     * @param status The status of the action ('SUCCESS', 'FAILED').
     * @param details Additional details.
     */
    public static void logSignatureActivity(
    String signatureRequestId,
    String action,
    String status,
    String details
) {
    Signature_Request__c req = [
        SELECT DocumentId__c
        FROM Signature_Request__c
        WHERE Id = :signatureRequestId
        LIMIT 1
    ];

    AuditTrail__c audit = new AuditTrail__c(
        DocumentId__c = req.DocumentId__c,   // 🔥 THIS IS THE KEY
        RecordId__c = signatureRequestId,
        Action__c = action,
        Status__c = status,
        Details__c = details,
        Timestamp__c = System.now(),
        UserId__c = UserInfo.getUserId()
    );
    insert audit;
}



  public static void logSignatureCompletion(String requestId, String signatureMethod) {
    try {
        // 🔥 QUERY NAME + EMAIL
        Signature_Request__c request = [
            SELECT DocumentId__c, SignerName__c, SignerEmail__c
            FROM Signature_Request__c 
            WHERE Id = :requestId
            LIMIT 1
        ];

        // 🔥 BUILD PROFESSIONAL SIGNER TEXT
        String signerInfo = '';

        if (String.isNotBlank(request.SignerName__c)) {
            signerInfo += request.SignerName__c;
        }

        if (String.isNotBlank(request.SignerEmail__c)) {
            signerInfo += ' <' + request.SignerEmail__c + '>';
        }

        if (String.isBlank(signerInfo)) {
            signerInfo = 'Unknown Signer';
        }

        String details =
            'Document signed by ' + signerInfo +
            ' using method: ' + signatureMethod;

        AuditTrail__c audit = new AuditTrail__c(
            DocumentId__c = request.DocumentId__c,
            RecordId__c = requestId,
            Action__c = 'Signature Completed',
            Status__c = 'Success',
            Details__c = details,
            Timestamp__c = Datetime.now(),
            UserId__c = UserInfo.getUserId()
        );

        insert audit;

    } catch (Exception e) {
        logSystemActivity(
            'AUDIT_TRAIL_ERROR',
            'Failed to log signature completion: ' + e.getMessage()
        );
    }
}


     private static void createAuditEntry(String recordId, String action, String status, String details) {
        try {
            AuditTrail__c audit = new AuditTrail__c(
               // DocumentId__c = recordId,
                Action__c = action,
                Status__c = status,
                Details__c = details,
                Timestamp__c = System.now(),
                UserId__c = UserInfo.getUserId()
            );
            insert audit;
        } catch (Exception e) {
            // Log to the debug log but do not throw an exception, as auditing should not
            // block the primary business process.
            System.debug('Failed to create audit trail entry. Action: ' + action + '. Details: ' + e.getMessage());
        }
    }

    public static void logSignatureRequest(String documentId, String action, String details) {
      createAuditEntry(documentId, action, 'SUCCESS', details);
    }
    /**
     * @description Retrieves the audit trail for a specific DocumentLifecycleConfiguration__c record.
     * @param recordId The ID of the DocumentLifecycleConfiguration__c record.
     * @param limitCount The maximum number of audit records to return.
     * @return A list of AuditTrail__c records.
     */
 @AuraEnabled(cacheable=true)
public static List<AuditTrail__c> getAuditTrail(Integer limitCount) {
    return [
        SELECT Id, Action__c, Status__c, Details__c,
               Timestamp__c, UserId__c, User__r.Name
        FROM AuditTrail__c
        ORDER BY Timestamp__c DESC
        LIMIT :limitCount
    ];
}



    /**
     * @description Logs a system-level activity not tied to a specific record.
     * @param action The system action (e.g., 'SYSTEM_INITIALIZATION').
     * @param details Additional details about the event.
     */
    public static void logSystemActivity(String action, String details) {
        try {
            AuditTrail__c audit = new AuditTrail__c(
                Action__c = action,
                Status__c = 'SUCCESS',
                Details__c = details,
                Timestamp__c = System.now(),
                UserId__c = UserInfo.getUserId()
            );
            insert audit;
        } catch (Exception e) {
            System.debug('Failed to log system activity: ' + e.getMessage());
        }
    }
}