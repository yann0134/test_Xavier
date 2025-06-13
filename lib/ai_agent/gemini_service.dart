import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  static late final GenerativeModel _model;
  static bool _initialized = false;

  factory GeminiService({String? apiKey}) {
    if (!_initialized) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: apiKey ?? ApiKeys.geminiApiKey,
      );
      _initialized = true;
    }
    return _instance;
  }

  GeminiService._internal();

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
    final prompt = '''
Analyse ces données d'activité en te concentrant sur la performance des caissiers.
Données de ventes : ${jsonEncode(data)}

Réponds uniquement avec un objet JSON contenant les champs suivants :
{
  "performance": "Analyse globale de la performance",
  "alerts": "Points importants nécessitant une attention",
  "opportunities": "Opportunités identifiées",
  "recommendations": "Recommandations concrètes",
  "cashierAnalysis": [
    {
      "name": "Nom du caissier",
      "rating": "Note de performance (1-5)",
      "strengths": "Forces de ce caissier",
      "areas_for_improvement": "Points à améliorer",
      "recommendations": "Recommandations spécifiques"
    }
  ]
}

Exprime-toi en français de manière naturelle et professionnelle, sans mentionner l'origine automatique de l'analyse.''';

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
