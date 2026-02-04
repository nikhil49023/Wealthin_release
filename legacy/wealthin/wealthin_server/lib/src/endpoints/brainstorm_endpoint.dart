import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../services/zoho_service.dart';
import '../generated/protocol.dart';

class BrainstormEndpoint extends Endpoint {
  Future<BusinessIdea> analyzeIdea(Session session, String ideaDescription) async {
    try {
       const systemPrompt = 'You are a specialized financial mentor. Your response MUST be ONLY a valid JSON object with "title", "summary", "score" (int), "strengths" (list), "weaknesses" (list), "suggestions" (list), "estimatedInvestment", and "timeToBreakeven" keys. Do NOT include any other text.';
       
       final userPrompt = 'Analyze this business idea: "$ideaDescription". Return JSON.';
       
       final jsonString = await ZohoService().chat(systemPrompt, userPrompt);
       
       // Clean JSON string if it contains markdown code blocks
       final cleanJson = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
       final Map<String, dynamic> data = jsonDecode(cleanJson);

       return BusinessIdea(
        title: data['title'] ?? ideaDescription,
        score: int.tryParse(data['score']?.toString() ?? '0') ?? 75,
        strengths:List<String>.from(data['strengths'] ?? []),
        weaknesses: List<String>.from(data['weaknesses'] ?? []),
        suggestions: List<String>.from(data['suggestions'] ?? []),
        estimatedInvestment: data['estimatedInvestment'] ?? 'Unknown',
        timeToBreakeven: data['timeToBreakeven'] ?? 'Unknown',
      );

    } catch (e) {
      session.log('Brainstorm Error: $e', level: LogLevel.error);
      // Fallback for demo if AI fails
      return BusinessIdea(
        title: ideaDescription,
        score: 0,
        strengths: ['Error analyzing idea'],
        weaknesses: [e.toString()],
        suggestions: [],
        estimatedInvestment: 'N/A',
        timeToBreakeven: 'N/A',
      );
    }
  }
}
