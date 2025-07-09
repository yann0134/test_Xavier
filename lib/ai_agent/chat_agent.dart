import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';
import 'db_service.dart';

class ChatAgent {
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-pro', // Mis à jour vers 2.0 Flash-Lite
    apiKey: ApiKeys.geminiApiKey,
  );
  final DbService _db = DbService();
  late final ChatSession _chat;

  ChatAgent() {
    _initChat();
  }

  void _initChat() {
    _chat = _model.startChat(history: [
      Content.multi([
        TextPart(
            '''Tu es un assistant pour une application de caisse enregistreuse appelée CaissePro.
Tu as accès à la structure de base de données suivante:
${DbService.dbSchema}

Tu peux:
1. Répondre aux questions générales sur l'application
2. Générer et exécuter des requêtes SQL pour obtenir des informations
3. Analyser les données et fournir des insights

Règles:
1. Pour les questions nécessitant des données, génère une requête SQL appropriée
2. Sois concis et précis dans tes réponses
3. Utilise le format markdown pour présenter les données tabulaires
4. N'expose jamais de détails techniques sensibles'''),
      ])
    ]);
  }

  Future<String> processMessage(String message) async {
    try {
      // Si la question semble nécessiter des données
      if (_needsDatabaseQuery(message)) {
        final query = await _generateQuery(message);
        if (query != null) {
          final result = await _db.executeQuery(query);
          if (result['success']) {
            return await _analyzeResults(message, query, result['data']);
          } else {
            return "Désolé, je n'ai pas pu obtenir ces informations. Erreur: ${result['error']}";
          }
        }
      }

      // Pour une conversation normale
      final response = await _chat.sendMessage(Content.text(message));
      return response.text ?? "Désolé, je n'ai pas pu traiter votre demande.";
    } catch (e) {
      return "Une erreur est survenue: $e";
    }
  }

  bool _needsDatabaseQuery(String message) {
    final keywords = [
      'combien',
      'nombre',
      'liste',
      'stock',
      'produit',
      'vente',
      'catégorie',
      'statistique',
      'total',
      'montant'
    ];
    return keywords.any((k) => message.toLowerCase().contains(k));
  }

  Future<String?> _generateQuery(String message) async {
    final prompt = '''
    En fonction de cette question: "$message"
    Et de ce schéma de base de données:
    ${DbService.dbSchema}
    
    Génère une requête SQL appropriée. Réponds uniquement avec la requête SQL, rien d'autre.
    ''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text?.trim();
  }

  Future<String> _analyzeResults(
      String question, String query, List<Map<String, dynamic>> results) async {
    final prompt = '''
    Analyse ces résultats pour répondre à la question: "$question"
    
    Requête exécutée: $query
    Résultats: ${results.toString()}
    
    Fournis une réponse naturelle et concise, avec un tableau markdown si pertinent.
    ''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? "Désolé, je n'ai pas pu analyser les résultats.";
  }
}
