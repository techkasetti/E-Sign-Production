// force-app/main/default/classes/ComplianceChecker.cls
public with sharing class ComplianceChecker {

    // Wrapper class for returning structured compliance results
    public class ComplianceValidationResult {
        @AuraEnabled public Boolean isCompliant { get; set; }
        @AuraEnabled public Integer complianceScore { get; set; }
        @AuraEnabled public List<String> violations { get; set; }
        @AuraEnabled public String recommendation { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static ComplianceValidationResult validateCompliance(String clause, String region, String contractType) {
        ComplianceValidationResult result = new ComplianceValidationResult();
        result.violations = new List<String>();
        Integer score = 100;

        // Rule 1: Clause must contain a signature statement
        if (!clause.toLowerCase().contains('electronic signature')) {
            result.violations.add('Clause is missing an electronic signature statement.');
            score -= 40;
        }

        // Rule 2: Region-specific checks
        if (region == 'US' && !clause.contains('E-SIGN')) {
            result.violations.add('US documents must reference the E-SIGN Act.');
            score -= 30;
        }
        if (region == 'EU' && !clause.contains('GDPR')) {
            result.violations.add('EU documents must reference GDPR.');
            score -= 30;
        }
        if (region == 'EU' && !clause.contains('eIDAS')) {
            result.violations.add('EU documents should reference the eIDAS Regulation.');
            score -= 15;
        }

        // Rule 3: Minimum length
        if (clause.length() < 150) {
            result.violations.add('Document content is too short and may be incomplete.');
            score -= 20;
        }
        
        result.complianceScore = Math.max(0, score);
        result.isCompliant = result.violations.isEmpty();

        if(result.isCompliant) {
            result.recommendation = 'Document passes all compliance checks.';
        } else {
            result.recommendation = 'Document requires review. Address the violations listed above.';
        }

        return result;
    }
}