public with sharing class FacePlusPlusService {

    @AuraEnabled(cacheable=false)
    public static FaceDetectionResult detectFaces(String imageBase64) {
        // Securely fetch credentials from the Custom Metadata Type
        FacePlusPlus_Credential__mdt credential = [
            SELECT API_Key__c, API_Secret__c 
            FROM FacePlusPlus_Credential__mdt 
            WHERE DeveloperName = 'Default' LIMIT 1
        ];

        HttpRequest req = new HttpRequest();
        // The endpoint uses the Named Credential you created in Step 2
        req.setEndpoint('callout:FacePlusPlus_API/facepp/v3/detect');
        req.setMethod('POST');
        req.setTimeout(60000); // 60-second timeout

        // Build the request body using the securely fetched credentials
        String body = '';
        body += 'api_key=' + EncodingUtil.urlEncode(credential.API_Key__c, 'UTF-8');
        body += '&api_secret=' + EncodingUtil.urlEncode(credential.API_Secret__c, 'UTF-8');
        body += '&image_base64=' + EncodingUtil.urlEncode(imageBase64, 'UTF-8');
        
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Deserialize the successful response into our wrapper class
                FaceDetectionResult result = (FaceDetectionResult) JSON.deserialize(res.getBody(), FaceDetectionResult.class);
                return result;
            } else {
                // Handle API errors
                throw new AuraHandledException('Face++ API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred during the Face++ callout: ' + e.getMessage());
        }
    }


    @AuraEnabled(cacheable=false)
public static FaceCompareResult compareFaces(String faceToken1, String faceToken2) {

    FacePlusPlus_Credential__mdt credential = [
        SELECT API_Key__c, API_Secret__c
        FROM FacePlusPlus_Credential__mdt
        WHERE DeveloperName = 'Default'
        LIMIT 1
    ];

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:FacePlusPlus_API/facepp/v3/compare');
    req.setMethod('POST');
    req.setTimeout(60000);

    String body = '';
    body += 'api_key=' + EncodingUtil.urlEncode(credential.API_Key__c, 'UTF-8');
    body += '&api_secret=' + EncodingUtil.urlEncode(credential.API_Secret__c, 'UTF-8');
    body += '&face_token1=' + EncodingUtil.urlEncode(faceToken1, 'UTF-8');
    body += '&face_token2=' + EncodingUtil.urlEncode(faceToken2, 'UTF-8');

    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setBody(body);

    Http http = new Http();
    HttpResponse res = http.send(req);

    if (res.getStatusCode() == 200) {
        return (FaceCompareResult) JSON.deserialize(res.getBody(), FaceCompareResult.class);
    } else {
        throw new AuraHandledException('Face++ Compare Error: ' + res.getBody());
    }
}
@AuraEnabled
public static Id saveVerifiedFaceImage(String imageBase64) {
    Blob imageBlob = EncodingUtil.base64Decode(imageBase64);

    ContentVersion cv = new ContentVersion();
    cv.Title = 'Verified_Face_' + Datetime.now().getTime();
    cv.PathOnClient = 'verified_face.jpg';
    cv.VersionData = imageBlob;
    cv.IsMajorVersion = true;

    insert cv;
    return cv.Id;
}

// Wrapper classes
public class FaceCompareResult {
    @AuraEnabled public Decimal confidence;
    @AuraEnabled public Thresholds thresholds;
}
public class Thresholds {
    @AuraEnabled public Decimal e3;
    @AuraEnabled public Decimal e4;
    @AuraEnabled public Decimal e5;
}

    // Wrapper class to cleanly deserialize the JSON response from Face++
    public class FaceDetectionResult {
        @AuraEnabled public List<Face> faces;
        @AuraEnabled public String image_id;
        @AuraEnabled public Integer face_num;
    }
    public class Face {
        @AuraEnabled public FaceRectangle face_rectangle;
        @AuraEnabled public String face_token;
    }
    public class FaceRectangle {
        @AuraEnabled public Integer top;
        @AuraEnabled public Integer left;
        @AuraEnabled public Integer width;
        @AuraEnabled public Integer height;
    }
}
