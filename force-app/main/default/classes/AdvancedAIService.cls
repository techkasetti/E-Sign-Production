// force-app/main/default/classes/AdvancedAIService.cls
public with sharing class AdvancedAIService {
    private static final String AI_ENDPOINT = 'callout:Groq_API';
    // CORRECTED LINE: Updated to a current, supported model from Groq
    private static final String AI_MODEL = 'llama-3.1-8b-instant';

    /**
     * @description Generates an enhanced legal clause by calling an external AI service.
     * @param region The geographic region for the contract.
     * @param role The role of the person involved.
     * @param contractType The type of contract being generated.
     * @param documentTitle The title of the document for context.
     * @return An AIInsight__c record containing the generated clause and analysis.
     */
    @AuraEnabled(cacheable=false)
    public static AIInsight__c generateEnhancedClause(String region, String role, String contractType, String documentTitle) {
        String prompt = buildPrompt(region, role, contractType, documentTitle);
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(AI_ENDPOINT + '/openai/v1/chat/completions');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');

            Map<String, Object> body = new Map<String, Object>{
                'model' => AI_MODEL,
                'messages' => new List<Map<String, String>>{
                    new Map<String, String>{
                        'role' => 'system',
                        'content' => 'You are a legal assistant specializing in contract clause generation.'
                    },
                    new Map<String, String>{
                        'role' => 'user',
                        'content' => prompt
                    }
                },
                'temperature' => 0.5
            };
            request.setBody(JSON.serialize(body));
            request.setTimeout(60000);

            // --- DEBUGGING BLOCK ---
            System.debug('Request Body Sent: ' + request.getBody());
            Http http = new Http();
            HttpResponse response = http.send(request);
            System.debug('Response Status Code: ' + response.getStatusCode());
            System.debug('Full Response Body: ' + response.getBody());
            // --- END DEBUGGING BLOCK ---

            if (response.getStatusCode() == 200) {
                return processAIResponse(response.getBody(), prompt);
            } else {
                throw new CalloutException('AI service returned error: ' + response.getBody());
            }
        } catch (Exception e) {
            AuditTrailManager.logSystemActivity('AI_SERVICE_ERROR', e.getMessage());
            throw new AuraHandledException('AI Service callout failed: ' + e.getMessage());
        }
    }

    /**
     * @description Constructs the prompt to be sent to the AI model.
     */
    private static String buildPrompt(String region, String role, String contractType, String documentTitle) {
        String promptTemplate = 'Generate a legally sound clause for a "{0}" titled "{1}". The agreement is for a {2} in the {3} region. ' +
                                'The response MUST be a JSON object with three keys: "generatedClause" (the clause text), "reasoning" ' +
                                '(explain why you wrote it this way), and "complianceNotes" (list key compliance considerations for the {3} region as a single string).';
        return String.format(promptTemplate, new List<String>{contractType, documentTitle, role, region});
    }

    /**
     * @description Processes the successful JSON response from the AI and creates an AIInsight record.
     */
    private static AIInsight__c processAIResponse(String responseBody, String prompt) {
        AIResponse responseWrapper = (AIResponse)JSON.deserialize(responseBody, AIResponse.class);
        if (responseWrapper == null || responseWrapper.choices.isEmpty()) {
            throw new AuraHandledException('AI response was empty or invalid.');
        }

        String aiContent = responseWrapper.choices[0].message.content;

        if (String.isBlank(aiContent) || !aiContent.trim().startsWith('{')) {
            throw new AuraHandledException('AI did not return a valid JSON response. Content: ' + aiContent);
        }

        AIContentResult contentResult = (AIContentResult)JSON.deserialize(aiContent, AIContentResult.class);

        AIInsight__c insight = new AIInsight__c(
            GeneratedClause__c = contentResult.generatedClause,
            Reasoning__c = contentResult.reasoning,
            ComplianceNotes__c = contentResult.complianceNotes,
            ConfidenceScore__c = 95, // Example static score
            ModelUsed__c = AI_MODEL,
            Prompt__c = prompt
        );
        insert insight;
        return insight;
    }

    // --- Wrapper classes for JSON deserialization ---
    public class AIResponse {
        public List<Choice> choices;
    }

    public class Choice {
        public Message message;
    }

    public class Message {
        public String role;
        public String content;
    }

    public class AIContentResult {
        public String generatedClause;
        public String reasoning;
        public String complianceNotes;
    }
}