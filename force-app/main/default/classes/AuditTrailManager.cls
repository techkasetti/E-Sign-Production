// // force-app/main/default/classes/AuditTrailManager.cls
// public with sharing class AuditTrailManager {

//     /**
//      * @description Logs a general activity related to a specific document record.
//      * @param documentId The ID of the DocumentLifecycleConfiguration__c record.
//      * @param action The action being performed (e.g., 'Document Generated').
//      * @param details A description of the activity.
//      */
//     public static void logDocumentActivity(String documentId, String action, String details) {
//         System.debug('Logging document activity: ' + action + ' for Document ID: ' + documentId);
//         createAuditEntry(documentId, action, 'SUCCESS', details);
//     }

//     /**
//      * @description A convenience method for logging signature request activities.
//      * @param documentId The ID of the parent document record.
//      * @param action The action being performed (e.g., 'Signature Request Created').
//      * @param details A description of the activity.
//      */
//     public static void logSignatureRequest(String documentId, String action, String details) {
//         createAuditEntry(documentId, action, 'SUCCESS', details);
//     }
    
//     /**
//      * @description Logs a system-level event that isn't tied to a specific document record.
//      * @param action The system action being performed (e.g., 'SIGNATURE_REQUEST_ERROR').
//      * @param details A description of the event or error message.
//      */

//     // public static void logSystemActivity(String action, String details) {
//     //     // For system events, the recordId can be null.
//     //     createAuditEntry(null, action, 'SYSTEM_EVENT', details);
//     // }

//     /**
//      * @description Private helper method to create and insert the AuditTrail__c record.
//      * @param recordId The ID of the related document (can be null for system events).
//      * @param action The action being performed.
//      * @param status The status of the action.
//      * @param details A description of the event.
//      */
//     private static void createAuditEntry(String recordId, String action, String status, String details) {
//         try {
//             AuditTrail__c audit = new AuditTrail__c(
//                // DocumentId__c = recordId,
//                 Action__c = action,
//                 Status__c = status,
//                 Details__c = details,
//                 Timestamp__c = System.now(),
//                 UserId__c = UserInfo.getUserId()
//             );
//             insert audit;
//         } catch (Exception e) {
//             // Log to the debug log but do not throw an exception, as auditing should not
//             // block the primary business process.
//             System.debug('Failed to create audit trail entry. Action: ' + action + '. Details: ' + e.getMessage());
//         }
//     }



// // FEATURE 1 CODE IS IMPLEMENTED IN THE ABOVE






    

//     /**
//      * @description Logs a generic system-level activity not tied to a specific document.
//      * @param action The action being performed (e.g., 'SIGNATURE_SUBMISSION_ERROR').
//      * @param details A detailed message about the event.
//      */
//     public static void logSystemActivity(String action, String details) {
//         try {
//             AuditTrail__c audit = new AuditTrail__c(
//                 Action__c = action,
//                 Status__c = 'SYSTEM',
//                 Details__c = details,
//                 Timestamp__c = Datetime.now(),
//                 UserId__c = UserInfo.getUserId()
//             );
//             insert audit;
//         } catch (Exception e) {
//             // Fails silently to prevent critical processes from stopping due to logging failure
//             System.debug('FATAL: Could not create audit trail entry. Reason: ' + e.getMessage());
//         }
//     }

//     /**
//      * @description Logs the successful completion of a signature.
//      * @param requestId The ID of the Signature_Request__c record.
//      * @param signatureMethod The method used for signing.
//      */
//     public static void logSignatureCompletion(String requestId, String signatureMethod) {
//         try {
//             // Query for context to make the log more descriptive
//             Signature_Request__c request = [
//                 SELECT DocumentId__c, SignerName__c 
//                 FROM Signature_Request__c 
//                 WHERE Id = :requestId LIMIT 1
//             ];

//             String details = 'Document signed by ' + request.SignerName__c + ' using method: ' + signatureMethod;

//             AuditTrail__c audit = new AuditTrail__c(
//                 DocumentId__c = request.DocumentId__c,
//                 RecordId__c = requestId,
//                 Action__c = 'Signature Completed',
//                 Status__c = 'Success',
//                 Details__c = details,
//                 Timestamp__c = Datetime.now(),
//                 UserId__c = UserInfo.getUserId()
//             );
//             insert audit;
//         } catch (Exception e) {
//             logSystemActivity('AUDIT_TRAIL_ERROR', 'Failed to log signature completion: ' + e.getMessage());
//         }
//     }



// // feature 2 code is implemented in the above






  
// }

public with sharing class AuditTrailManager {

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
    public static void logSignatureActivity(String signatureRequestId, String action, String status, String details) {
        try {
            AuditTrail__c audit = new AuditTrail__c(
                RecordId__c = signatureRequestId, // Use generic RecordId for flexibility
                Action__c = action,
                Status__c = status,
                Details__c = details,
                Timestamp__c = System.now(),
                UserId__c = UserInfo.getUserId()
            );
            insert audit;
        } catch (Exception e) {
            System.debug('Failed to log signature activity: ' + e.getMessage());
        }
    }


  public static void logSignatureCompletion(String requestId, String signatureMethod) {
        try {
            // Query for context to make the log more descriptive
            Signature_Request__c request = [
                SELECT DocumentId__c, SignerName__c 
                FROM Signature_Request__c 
                WHERE Id = :requestId LIMIT 1
            ];

            String details = 'Document signed by ' + request.SignerName__c + ' using method: ' + signatureMethod;

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
            logSystemActivity('AUDIT_TRAIL_ERROR', 'Failed to log signature completion: ' + e.getMessage());
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
    public static List<AuditTrail__c> getAuditTrail(String recordId, Integer limitCount) {
        try {
            String query = 'SELECT Id, Action__c, Status__c, Details__c, Timestamp__c, UserId__c, User__r.Name ' +
                           'FROM AuditTrail__c ' +
                           'WHERE DocumentId__c = :recordId ' +
                           'ORDER BY Timestamp__c DESC';

            if (limitCount != null && limitCount > 0) {
                query += ' LIMIT ' + limitCount;
            }

            return Database.query(query);
        } catch (Exception e) {
            System.debug('GetAuditTrail Error: ' + e.getMessage());
            // In a component, it's better to throw the exception to handle it in the LWC's catch block.
            throw new AuraHandledException('Failed to retrieve audit trail: ' + e.getMessage());
        }
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