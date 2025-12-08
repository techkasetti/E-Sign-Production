public with sharing class SignatureRequestController {
    // Fetches a single signature request for the signaturePad component
    @AuraEnabled(cacheable=true)
    public static Signature_Request__c getSignatureRequest(String requestId) {
        System.debug('getSignatureRequest called with requestId: ' + requestId);
        try {
            Signature_Request__c req = [
                SELECT Id, Status__c, SignerName__c, DocumentId__r.DocumentTitle__c, DocumentId__r.GeneratedClause__c
                FROM Signature_Request__c
                WHERE Id = :requestId
            ];
            System.debug('Fetched Signature Request: ' + req);
            return req;
        } catch (Exception e) {
            System.debug('Error fetching Signature Request: ' + e.getMessage());
            throw new AuraHandledException('Error fetching signature request.');
        }
    }

    // Creates a new signature request and stores the selected fraud rules
    @AuraEnabled
    public static String initiateSignatureRequest(
        String documentId,
        String signerEmail,
        String signerName,
        List<String> activeToggles
    ) {
        // --- DEBUGGER ADDITION ---
        // STEP 1: VERIFY WHAT THE LWC IS SENDING
        System.debug('DEBUG 1 (Controller): LWC payload received -> ' + activeToggles);
        // --- END OF ADDITION ---

        System.debug('initiateSignatureRequest called');
        System.debug('DocumentId: ' + documentId);
        System.debug('Signer Email: ' + signerEmail);
        System.debug('Signer Name: ' + signerName);
        System.debug('Selected Fraud Toggles: ' + activeToggles);

        try {
            Signature_Request__c newRequest = new Signature_Request__c(
                DocumentId__c = documentId,
                SignerEmail__c = signerEmail,
                SignerName__c = signerName,
                Status__c = 'Pending',
                Fraud_Rules_To_Run__c = String.join(activeToggles, ';')
            );
            insert newRequest;

            // --- DEBUGGER ADDITION ---
            // STEP 2: VERIFY WHAT WAS SAVED TO THE DATABASE FIELD
            System.debug('DEBUG 2 (Controller): Value saved to Fraud_Rules_To_Run__c -> ' + newRequest.Fraud_Rules_To_Run__c);
            // --- END OF ADDITION ---

            System.debug('New Signature Request Inserted: ' + newRequest.Id);
            return newRequest.Id;
        } catch (Exception e) {
            System.debug('Error creating signature request: ' + e.getMessage());
            throw new AuraHandledException('Failed to create signature request: ' + e.getMessage());
        }
    }

//     @AuraEnabled
//     public static String submitSignature(
//         String requestId,
//         String signatureData,
//         String signatureMethod,
//         String userContextJSON
//     ) {
//         System.debug('submitSignature called');
//         System.debug('RequestId: ' + requestId);
//         System.debug('Signature Method: ' + signatureMethod);
//         System.debug('User Context JSON: ' + userContextJSON);
//         try {
//             Signature_Request__c request = [
//                 SELECT Id, SignerEmail__c, Fraud_Rules_To_Run__c, Status__c
//                 FROM Signature_Request__c
//                 WHERE Id = :requestId FOR UPDATE
//             ];
//             System.debug('Fetched Signature Request for Submit: ' + request);
//             if (request.Status__c == 'Signed' || request.Status__c == 'Completed') {
//                 System.debug('Signature already completed');
//                 throw new AuraHandledException('This document has already been signed.');
//             }
//           // === REPLACE WITH THIS NEW, CORRECTED BLOCK ===
// // === REPLACE WITH THIS NEW, CORRECTED BLOCK ===
// Map<String, Object> contextMap = (Map<String, Object>) JSON.deserializeUntyped(userContextJSON);
// System.debug('Deserialized Context Map: ' + contextMap);

// // First, get the list of rules that were selected when the request was created.
// String rulesToRun = request.Fraud_Rules_To_Run__c;
// System.debug('Rules to run for this request: ' + rulesToRun);

// // --- CONDITIONAL DATA SAVING ---

// // Block 1: Handle IP Anomaly Data
// // This block ONLY saves the IP address and ONLY runs if the IP_ANOMALY toggle is on.
// if (rulesToRun != null && rulesToRun.contains('IP_ANOMALY')) {
//     String clientIp = (String) contextMap.get('ip');
//     request.IPAddress__c = clientIp;
//     System.debug('IP Anomaly toggle ON. IP Address saved: ' + clientIp);
// } else {
//     System.debug('IP Anomaly toggle OFF. IP Address will not be saved.');
// }

// // Block 2: Handle Location Anomaly Data
// // This block saves location data and ONLY runs if the LOCATION_ANOMALY toggle is on.
// if (rulesToRun != null && rulesToRun.contains('LOCATION_ANOMALY')) {
//     // Part A: Save browser-based location (e.g., from GPS). This is independent.
//     request.SigningLocation__c = (String) contextMap.get('location');
//     System.debug('Location Anomaly toggle ON. Browser location saved: ' + request.SigningLocation__c);

//     // Part B: Save IP-based geolocation (country, city). This requires the IP address for the lookup,
//     // but we will NOT save the IP address to the record itself here.
//     String ipForLocationLookup = (String) contextMap.get('ip');
//     if (String.isNotBlank(ipForLocationLookup)) {
//         Map<String, String> geoInfo = getGeoFromIp(ipForLocationLookup);
//         if (geoInfo != null) {
//             request.IP_Country__c = geoInfo.get('country');
//             request.IP_Country_Code__c = geoInfo.get('countryCode');
//             request.IP_Region_Code__c = geoInfo.get('region');
//             request.IP_Region_Name__c = geoInfo.get('regionName');
//             request.IP_City__c = geoInfo.get('city');
//             System.debug('Location Anomaly toggle ON. IP-based geo data (country, city, etc.) saved.');
//         }
//     }
// } else {
//     System.debug('Location Anomaly toggle OFF. Location data will not be saved.');
// }

// // Block 3: Handle Time Anomaly Data
// // This block ONLY saves the signing time and ONLY runs if the TIME_ANOMALY toggle is on.
// if (rulesToRun != null && rulesToRun.contains('TIME_ANOMALY')) {
//     if (contextMap.containsKey('timeToSign')) {
//         request.Time_To_Complete_Seconds__c = (Decimal) contextMap.get('timeToSign');
//         System.debug('Time Anomaly toggle ON. Time to sign saved.');
//     }
// } else {
//     System.debug('Time Anomaly toggle OFF. Time to sign will not be saved.');
// }

// System.debug('Updated Request Before Fraud Check: ' + request);
// FraudDetectionRulesEngine.FraudAnalysisResult fraudResult = FraudDetectionRulesEngine.runSelectedChecks(request);


//             System.debug('Fraud Result: ' + fraudResult);
//             if (fraudResult!= null) {
//                 request.Fraud_Risk_Level__c = fraudResult.riskLevel;
//                 request.Fraud_Score__c = fraudResult.overallRiskScore;
//                 request.Fraud_Analysis_Details__c = String.join(fraudResult.reasons, '\n\n');
//             }
//             request.Status__c = 'Signed';
//             request.CompletedDate__c = System.now();
//             request.SignatureData__c = signatureData;
//             request.SignatureMethod__c = signatureMethod;
//             System.debug('Final Request Before Update: ' + request);
//             update request;
//             System.debug('Signature Request Successfully Updated');
//             return 'SUCCESS';
//         } catch (Exception e) {
//             System.debug('Error during signature submission: ' + e.getMessage());
//             throw new AuraHandledException('Signature submission failed: ' + e.getMessage());
//         }
//     }

// In SignatureRequestController.cls
@AuraEnabled
public static String submitSignature( String requestId, String signatureData, String signatureMethod, String userContextJSON ) {
    System.debug('submitSignature called');
    try {
        Signature_Request__c request = [
            SELECT Id, SignerEmail__c, Fraud_Rules_To_Run__c, Status__c
            FROM Signature_Request__c
            WHERE Id = :requestId FOR UPDATE
        ];

        if (request.Status__c == 'Signed' || request.Status__c == 'Completed') {
            throw new AuraHandledException('This document has already been signed.');
        }

        Map<String, Object> contextMap = (Map<String, Object>) JSON.deserializeUntyped(userContextJSON);
        String rulesToRun = request.Fraud_Rules_To_Run__c;

        // --- CONDITIONAL DATA SAVING (Your original code - NO CHANGES HERE) ---
        if (rulesToRun != null && rulesToRun.contains('IP_ANOMALY')) {
            String clientIp = (String) contextMap.get('ip');
            request.IPAddress__c = clientIp;
        }

        if (rulesToRun != null && rulesToRun.contains('LOCATION_ANOMALY')) {
            request.SigningLocation__c = (String) contextMap.get('location');
            String ipForLocationLookup = (String) contextMap.get('ip');
            if (String.isNotBlank(ipForLocationLookup)) {
                Map<String, String> geoInfo = getGeoFromIp(ipForLocationLookup);
                if (geoInfo != null) {
                    request.IP_Country__c = geoInfo.get('country');
                    request.IP_Country_Code__c = geoInfo.get('countryCode');
                    request.IP_Region_Code__c = geoInfo.get('region');
                    request.IP_Region_Name__c = geoInfo.get('regionName');
                    request.IP_City__c = geoInfo.get('city');
                }
            }
        }

       if (rulesToRun != null && 
    (rulesToRun.contains('TIME_ANOMALY') || rulesToRun.contains('BEHAVIORAL_ANOMALY'))) {
    if (contextMap.containsKey('timeToSign')) {
        request.Time_To_Complete_Seconds__c = 
            (Decimal) contextMap.get('timeToSign');
    }
}

        
        // --- START OF REQUIRED CHANGES ---

        // Set final status fields before the first save
        request.Status__c = 'Signed';
        request.CompletedDate__c = System.now();
        request.SignatureData__c = signatureData;
        request.SignatureMethod__c = signatureMethod;

        // STEP 1: First update. This saves all the raw data (IP, location, signature, etc.).
        // This is necessary so the fraud engine can query this record for its analysis.
        update request;
        System.debug('STEP 1 COMPLETE: Raw data saved for request Id: ' + request.Id);

        // STEP 2: Now that the data is saved, call the advanced engine to analyze it.
        AdvancedSecurityEngine.SecurityAssessmentResult securityResult;
        if (String.isNotBlank(rulesToRun)) {
            // We pass the ID, not the whole object, so the engine can query the fresh data
            securityResult = AdvancedSecurityEngine.performSecurityAssessment(request.Id);
        }

        // STEP 3: Create a new instance for the second update with only the fraud fields.
        Signature_Request__c fraudUpdate = new Signature_Request__c(Id = request.Id);
        
        if (securityResult != null && securityResult.success) {
            fraudUpdate.Fraud_Risk_Level__c = securityResult.riskLevel;
            fraudUpdate.Fraud_Score__c = securityResult.totalRiskScore;
            
            List<String> reasons = new List<String>();
            for (AdvancedSecurityEngine.RiskFactor factor : securityResult.riskFactors) {
                reasons.add(factor.description);
            }
            fraudUpdate.Fraud_Analysis_Details__c = String.join(reasons, '; ');
            System.debug('STEP 2 COMPLETE: Fraud analysis finished. Risk Level: ' + securityResult.riskLevel);
        } else {
            // Set default values if no rules were run or if the engine failed
            fraudUpdate.Fraud_Risk_Level__c = 'Not Analyzed';
            fraudUpdate.Fraud_Analysis_Details__c = 'No fraud rules were selected to run.';
        }

        // STEP 4: Second update. This saves only the fraud analysis results onto the record.
        update fraudUpdate;
        System.debug('STEP 3 COMPLETE: Signature Request updated with fraud analysis.');

        // --- END OF REQUIRED CHANGES ---

        return 'SUCCESS';

    } catch (Exception e) {
        System.debug('Error during signature submission: ' + e.getMessage());
        throw new AuraHandledException('Signature submission failed: ' + e.getMessage());
    }
}



    // Fetch document and signature request data
    @AuraEnabled(cacheable=true)
    public static DocumentData getDocumentData(String documentId) {
        System.debug('getDocumentData called with documentId: ' + documentId);
        try {
            DocumentData data = new DocumentData();
            data.document = [
                SELECT Id, DocumentTitle__c, GeneratedClause__c, Region__c, Role__c, ContractType__c, ComplianceStatus__c, CreatedDate
                FROM DocumentLifecycleConfiguration__c
                WHERE Id = :documentId LIMIT 1
            ];
            System.debug('Fetched Document: ' + data.document);
            data.signatureRequests = [
                SELECT Id, SignerName__c, SignerEmail__c, Status__c, CreatedDate, CompletedDate__c
                FROM Signature_Request__c
                WHERE DocumentId__c = :documentId
                ORDER BY CreatedDate DESC
            ];
            System.debug('Fetched Signature Requests: ' + data.signatureRequests);
            return data;
        } catch (Exception e) {
            System.debug('GetDocumentData Error: ' + e.getMessage());
            return null;
        }
    }

    private static String getClientIPAddress() {
        String ip = RestContext.request!= null? RestContext.request.headers.get('X-Forwarded-For') : null;
        if (String.isBlank(ip) && RestContext.request!= null) {
            ip = RestContext.request.remoteAddress;
        }
        System.debug('Captured IP Address: ' + ip);
        return ip;
    }

    private static Map<String, String> getGeoFromIp(String ip) {
        System.debug('getGeoFromIp called with IP: ' + ip);
        // Initialize the map with default values
        Map<String, String> geoInfo = new Map<String, String>{
            'country' => 'Unknown',
            'countryCode' => null,
            'region' => null,
            'regionName' => null,
            'city' => null
        };
        if (String.isBlank(ip) || ip == '127.0.0.1') {
            System.debug('Invalid or Localhost IP detected');
            return geoInfo;
        }
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:IP_Geolocation_Service/json/' + ip);
        req.setMethod('GET');
        req.setTimeout(4000);
        try {
            HttpResponse res = http.send(req);
            System.debug('Geo API Status Code: ' + res.getStatusCode());
            System.debug('Geo API Response: ' + res.getBody());
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                // --- THIS IS THE UPDATED PART ---
                // Extract all the new fields from the response
                geoInfo.put('country', (String) response.get('country'));
                geoInfo.put('countryCode', (String) response.get('countryCode'));
                geoInfo.put('region', (String) response.get('region')); // This is the code, e.g., "KA"
                geoInfo.put('regionName', (String) response.get('regionName')); // e.g., "Karnataka"
                geoInfo.put('city', (String) response.get('city')); // e.g., "Bengaluru"
                // --- END OF UPDATE ---
            }
        } catch (Exception e) {
            System.debug('IP Geolocation callout failed: ' + e.getMessage());
        }
        return geoInfo;
    }

    // Wrapper class for getDocumentData method
    public class DocumentData {
        @AuraEnabled public DocumentLifecycleConfiguration__c document;
        @AuraEnabled public List<Signature_Request__c> signatureRequests;
    }
}

