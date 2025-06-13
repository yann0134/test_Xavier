import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:excel/excel.dart' as excel;

class GeminiService {
  final GenerativeModel _model;

  GeminiService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash-latest',
          apiKey: apiKey,
        );

  Future<Map<String, dynamic>> decideTool(
      String query, List<String> availableTools) async {
    final prompt =
        '''You are an assistant that can use tools: ${availableTools.join(', ')}.
Decide the best tool for the user query or answer directly.
Respond only with JSON in one of these formats:
{ "tool": "<tool name>", "toolQuery": "<query>" }
or
{ "answer": "<text>" }
Query: "$query"''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return _extractJson(response.text);
  }

  Future<Map<String, dynamic>> analyzeBusinessDay(
      Map<String, dynamic> data) async {
    final prompt =
        '''Analyze this business data with a focus on cashier performance:
Sales data: ${jsonEncode(data)}

Respond with a JSON object containing these fields:
{
  "performance": "Overall business performance analysis",
  "alerts": "Important points requiring attention",
  "opportunities": "Business opportunities identified",
  "recommendations": "Actionable recommendations",
  "cashierAnalysis": [
    {
      "name": "Cashier name",
      "rating": "Performance rating (1-5)",
      "strengths": "Key strengths of this cashier",
      "areas_for_improvement": "Areas where improvement is needed",
      "recommendations": "Specific recommendations for this cashier"
    }
  ]
}

When analyzing cashiers, consider:
1. Sales volume and average basket
2. Number of unique customers
3. Customer retention patterns
4. Speed and efficiency
5. Compare to team averages

Make it professional and constructive.''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final result = _extractJson(response.text);

      if (result.isEmpty) {
        return {
          "performance": "Analyse en cours...",
          "alerts": "Données insuffisantes pour l'analyse",
          "opportunities": "En attente de plus de données",
          "recommendations": "Collecte de données en cours",
          "cashierAnalysis": []
        };
      }

      return result;
    } catch (e) {
      print('Error generating AI analysis: $e');
      return {
        "performance": "Erreur d'analyse",
        "alerts": "Service temporairement indisponible",
        "opportunities": "Réessayez plus tard",
        "recommendations": "Contactez le support technique",
        "cashierAnalysis": []
      };
    }
  }

  Map<String, dynamic> _extractJson(String? text) {
    if (text == null) return {};
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return {};
    final jsonStr = text.substring(start, end + 1);
    try {
      return jsonDecode(jsonStr);
    } catch (_) {
      return {};
    }
  }
}
