// force-app/main/default/classes/EmailNotificationService.cls
public with sharing class EmailNotificationService {

    public static void sendSignatureRequest(String signatureRequestId) {
        Signature_Request__c request = [
            SELECT Id, SignerEmail__c, SignerName__c, DocumentId__r.DocumentTitle__c 
            FROM Signature_Request__c 
            WHERE Id = :signatureRequestId
        ];

        String subject = 'Action Required: Signature Request for ' + request.DocumentId__r.DocumentTitle__c;
        String body = buildSignatureRequestEmailBody(request);

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{request.SignerEmail__c});
        email.setSubject(subject);
        email.setHtmlBody(body);
        email.setSaveAsActivity(false); // Set to true if you want to log it as an activity

        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            AuditTrailManager.logDocumentActivity(request.DocumentId__c, 'Email Sent', 'Signature request email sent to: ' + request.SignerEmail__c);
        } catch (Exception e) {
            System.debug('Email sending failed: ' + e.getMessage());
            AuditTrailManager.logSystemActivity('EMAIL_ERROR', 'Failed to send signature request email: ' + e.getMessage());
        }
    }

    private static String buildSignatureRequestEmailBody(Signature_Request__c request) {
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        // NOTE: Replace 'c__signaturePad' with the actual name of your signature component if it's different.
        String signatureUrl = baseUrl + '/lightning/n/SignaturePad?c__recordId=' + request.Id;
        
        return '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">' +
            '<h2 style="color: #005fb2;">Electronic Signature Required</h2>' +
            '<p>Dear ' + request.SignerName__c + ',</p>' +
            '<p>You have been requested to electronically sign the document: <strong>' + request.DocumentId__r.DocumentTitle__c + '</strong>.</p>' +
            '<p>Please click the button below to review and sign the document:</p>' +
            '<div style="text-align: center; margin: 30px 0;">' +
                '<a href="' + signatureUrl + '" style="background-color: #0070d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px;">Sign Document Now</a>' +
            '</div>' +
            '<hr style="border: none; border-top: 1px solid #dddbda;">' +
            '<p style="color: #5c5c5c; font-size: 12px;">This is an automated message. Please do not reply.</p>' +
        '</div>';
    }



// feature 1 code is implemented in the above






    /**
     * @description Sends an email notification to the signer after they have successfully signed a document.
     * @param requestId The ID of the Signature_Request__c record.
     */
    public static void sendSignatureCompletion(String requestId) {
        try {
            Signature_Request__c request = [
                SELECT SignerEmail__c, SignerName__c, DocumentId__r.DocumentTitle__c, CompletedDate__c 
                FROM Signature_Request__c 
                WHERE Id = :requestId
            ];
            System.debug('request::'+request);

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{request.SignerEmail__c});
            email.setSubject('Document Signed Successfully: ' + request.DocumentId__r.DocumentTitle__c);

            String emailBody = buildCompletionEmail(request);
            email.setHtmlBody(emailBody);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});

        } catch (Exception e) {
            AuditTrailManager.logSystemActivity('EMAIL_ERROR', 'Failed to send completion email: ' + e.getMessage());
        }
    }

    /**
     * @description Private helper method to build a formatted HTML email body for the completion notification.
     * @param request The Signature_Request__c record.
     * @return A string containing the HTML body.
     */
    private static String buildCompletionEmail(Signature_Request__c request) {
        String formattedDate = request.CompletedDate__c.format('MMMM dd, yyyy \'at\' h:mm a');
        return '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">' +
            '<h2 style="color: #28a745;">Document Successfully Signed</h2>' +
            '<p>Dear ' + request.SignerName__c + ',</p>' +
            '<p>Thank you for signing the following document:</p>' +
            '<div style="background-color: #f8f9fa; padding: 15px; border-left: 4px solid #28a745; margin: 20px 0;">' +
                '<h3>' + request.DocumentId__r.DocumentTitle__c + '</h3>' +
                '<p><strong>Signed on:</strong> ' + formattedDate + '</p>' +
            '</div>' +
            '<p>Your signature has been recorded and the document is now complete. You can now close the window.</p>' +
            '<hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">' +
            '<p style="color: #666; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>' +
        '</div>';
    }













}