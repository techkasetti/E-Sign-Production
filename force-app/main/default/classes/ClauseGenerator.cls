// force-app/main/default/classes/ClauseGenerator.cls
public with sharing class ClauseGenerator {

    @AuraEnabled(cacheable=true)
    public static String generateClause(String region, String role, String contractType) {
        try {
            // Use standard Apex String concatenation instead of StringBuilder
            String clause = '';

            // Add introductory clause
            clause += 'This ' + contractType + ' agreement is made in the ' + region + ' region for the role of ' + role + '. ';
            clause += '\n\n';

            // Add region-specific terms
            clause += getRegionSpecificTerms(region);
            clause += '\n\n';

            // Add general legal and signature terms
            clause += 'By signing this document, all parties agree to the terms and conditions outlined herein. ';
            clause += 'This agreement requires an electronic signature for legal validity. Your signature confirms your intent to be legally bound by this agreement.';

            return clause;
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to generate clause: ' + e.getMessage());
        }
    }

    private static String getRegionSpecificTerms(String region) {
        switch on region {
            when 'US' {
                return 'This agreement is governed by the laws of the United States and complies with the Electronic Signatures in Global and National Commerce Act (E-SIGN).';
            }
            when 'EU' {
                return 'This agreement complies with the General Data Protection Regulation (GDPR) and the eIDAS Regulation for electronic signatures in the European Union.';
            }
            when 'APAC' {
                return 'This agreement is subject to regional data protection and privacy laws as applicable in the Asia-Pacific region.';
            }
            when else {
                return 'This agreement is governed by local laws and regulations.';
            }
        }
    }
}