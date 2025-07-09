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
        model: 'gemini-1.5-pro', // Mis à jour vers 2.0 Flash-Lite
        apiKey: ApiKeys.geminiApiKey,
      );
      _initialized = true;
    }
    return _instance;
  }

  GeminiService._internal();

  Future<Map<String, dynamic>> decideTool(
      String query, List<String> availableTools) async {
    final prompt = '''
    Tu es un assistant pour une application de caisse enregistreuse. Analyse cette requête utilisateur: "$query"
    
    Tu as accès à ces outils: ${availableTools.join(', ')}
    
    IMPORTANT: Ta réponse doit être uniquement un objet JSON valide, rien d'autre.
    
    RÈGLES:
    1. Pour les questions sur l'inventaire/produits: {"tool": "inventory", "toolQuery": "la_requête"}
    2. Pour les questions sur les ventes: {"tool": "sales", "toolQuery": "la_requête"}
    3. Pour les autres questions: {"answer": "ta_réponse"}
    
    Exemple 1: Si l'utilisateur demande "combien j'ai de produits", réponds:
    {"tool": "inventory", "toolQuery": "combien produit"}
    
    Exemple 2: Si l'utilisateur demande "bonjour", réponds:
    {"answer": "Bonjour, comment puis-je vous aider ?"}
    ''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      // Nettoyage du texte pour s'assurer qu'il ne contient que du JSON
      String jsonStr = text.replaceAll(RegExp(r'^```json\s*|\s*```$'), '');
      if (!jsonStr.startsWith('{')) {
        final start = jsonStr.indexOf('{');
        if (start >= 0) {
          jsonStr = jsonStr.substring(start);
        }
      }
      if (!jsonStr.endsWith('}')) {
        final end = jsonStr.lastIndexOf('}');
        if (end >= 0) {
          jsonStr = jsonStr.substring(0, end + 1);
        }
      }

      try {
        final result = json.decode(jsonStr);
        if (result is Map<String, dynamic>) {
          print('Réponse JSON valide: $result'); // Debug
          return result;
        }
      } catch (e) {
        print('Erreur parsing JSON: $e\nTexte reçu: $jsonStr'); // Debug
      }

      // Fallback pour les questions sur l'inventaire
      if (query.toLowerCase().contains('combien') &&
          query.toLowerCase().contains('produit')) {
        return {'tool': 'inventory', 'toolQuery': 'combien produit'};
      }

      return {
        'answer':
            "Je n'ai pas bien compris votre demande. Pouvez-vous la reformuler ?"
      };
    } catch (e) {
      print('Erreur Gemini: $e');
      return {
        'answer':
            "Désolé, je rencontre des difficultés techniques. Réessayez plus tard."
      };
    }
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
