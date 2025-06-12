import 'package:scoped_model/scoped_model.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/database_tools.dart';
import 'package:http/http.dart' as http;
import 'message_types.dart';

class LLMAgentModel extends Model {
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  List<Map<String, dynamic>> get messages => _messages;
  bool get isTyping => _isTyping;

  // Initialiser l'API Gemini
  final model = GenerativeModel(
    model: 'gemini-1.5-flash-latest',
    apiKey:
        'AIzaSyCCVre0MdH35vty9lRbqQ0FglYKPt8KQ9c', // À remplacer par votre clé API
  );

  Future<void> sendMessage(String message) async {
    _messages.add({
      'contents': jsonEncode([MessageData.text(message).toJson()]),
      'isUser': true
    });
    _isTyping = true;
    notifyListeners();

    try {
      final response = await _processWithLLM(message);
      _messages.add({
        'contents': jsonEncode(response.map((m) => m.toJson()).toList()),
        'isUser': false
      });
    } catch (e) {
      _messages.add({
        'contents': jsonEncode(
            [MessageData.text("Erreur lors du traitement: $e").toJson()]),
        'isUser': false
      });
    }

    _isTyping = false;
    notifyListeners();
  }

  Future<List<MessageData>> _processWithLLM(String userQuestion) async {
    try {
      // Améliorer le prompt pour la détection des demandes de graphiques
      if (userQuestion.toLowerCase().contains('graphe') ||
          userQuestion.toLowerCase().contains('graphique') ||
          userQuestion.toLowerCase().contains('visualisation')) {
        final chartPrompt = """
Analyse cette demande de visualisation et génère une requête SQL appropriée.
Question: $userQuestion

Structure de la base de données:
${DatabaseTools.getSchemaDescription()}

Génère une réponse au format JSON avec:
{
  "needsVisualization": true,
  "visualType": "chart",
  "chartType": "bar",  // "bar", "line", "pie"
  "dataQuery": "REQUETE_SQL",
  "dataLabels": ["colonne_label", "colonne_valeur"],
  "title": "Titre du graphique"
}

Exemple pour les ventes par catégorie:
{
  "needsVisualization": true,
  "visualType": "chart",
  "chartType": "bar",
  "dataQuery": "SELECT c.nom, COUNT(p.id) as total FROM categories c LEFT JOIN produits p ON c.id = p.categorieId GROUP BY c.id, c.nom",
  "dataLabels": ["nom", "total"],
  "title": "Nombre de produits par catégorie"
}
""";

        final analysisResponse =
            await model.generateContent([Content.text(chartPrompt)]);
        print(
            "Réponse de l'agent pour le graphique: ${analysisResponse.text}"); // Debug

        final chartConfig = extractAndParseJson(analysisResponse.text ?? "");
        if (chartConfig != null && chartConfig['dataQuery'] != null) {
          final results =
              await DatabaseTools.executeQuery(chartConfig['dataQuery'], []);

          if (results.isNotEmpty) {
            final chartUrl = await _generateChart(
                results,
                chartConfig['chartType'],
                chartConfig['title'] ?? userQuestion,
                chartConfig['dataLabels'][0],
                chartConfig['dataLabels'][1]);

            if (chartUrl.isNotEmpty) {
              return [
                MessageData(
                  type: MessageType.chart,
                  content: chartUrl,
                  metadata: {'chartType': chartConfig['chartType']},
                ),
                MessageData.text(
                    "Voici le graphique demandé. Les données sont basées sur ${results.length} enregistrements."),
              ];
            }
          }
        }
      }

      // Vérifie d'abord si c'est une conversation générale
      final isConversational = await _isConversationalQuery(userQuestion);
      if (isConversational) {
        return await _handleConversation(userQuestion);
      }

      // Amélioration du prompt d'analyse avec des exemples plus spécifiques
      final analysisPrompt = """
Tu es un expert en analyse de données. Examine cette demande et détermine si une visualisation serait pertinente.
Question: $userQuestion

Structure complète de la base de données:
${DatabaseTools.getSchemaDescription()}

Si la demande concerne des statistiques, des tendances ou des comparaisons, génère une requête SQL appropriée.
Utilise UNIQUEMENT les tables et colonnes définies ci-dessus.

Exemples de requêtes valides pour les visualisations:
1. Pour les ventes journalières:
   {
     "needsVisualization": true,
     "visualType": "chart",
     "chartType": "line",
     "dataQuery": "SELECT date, SUM(total) as montant_total FROM commandes GROUP BY date ORDER BY date DESC LIMIT 7",
     "dataLabels": ["date", "montant_total"]
   }

2. Pour les produits populaires:
   {
     "needsVisualization": true,
     "visualType": "chart",
     "chartType": "bar",
     "dataQuery": "SELECT p.nom, COUNT(cp.id) as nombre_ventes FROM produits p JOIN commande_produits cp ON p.id = cp.produitId GROUP BY p.id, p.nom ORDER BY nombre_ventes DESC LIMIT 5",
     "dataLabels": ["nom", "nombre_ventes"]
   }

3. Pour l'analyse du stock:
   {
     "needsVisualization": true,
     "visualType": "chart",
     "chartType": "bar",
     "dataQuery": "SELECT nom, stock FROM produits WHERE stock <= seuilAlerte ORDER BY stock ASC",
     "dataLabels": ["nom", "stock"]
   }

Génère une réponse similaire pour la question posée.
""";

      final analysisResponse =
          await model.generateContent([Content.text(analysisPrompt)]);
      final analysisJson = extractAndParseJson(analysisResponse.text ?? "");

      print("Réponse de l'analyse: ${analysisResponse.text}"); // Debug log

      if (analysisJson == null) {
        print("Échec du parsing JSON de l'analyse"); // Debug log
        return await _processSQLQuery(userQuestion);
      }

      // Si une visualisation est nécessaire
      if (analysisJson['needsVisualization'] == true) {
        print("Requête SQL générée: ${analysisJson['dataQuery']}"); // Debug log

        final results = await DatabaseTools.executeQuery(
            analysisJson['dataQuery'] ?? "", []);
        print("Résultats de la requête: $results"); // Debug log

        if (results.isEmpty) {
          return [MessageData.text("Aucune donnée trouvée.")];
        }

        // Gérer différents types de visualisation
        switch (analysisJson['visualType']) {
          case 'table':
            // Formater les résultats en tableau
            return _formatTableResults(results);

          case 'chart':
            if (analysisJson['chartType'] == null) {
              return _formatTableResults(results);
            }

            // Reste du code existant pour les graphiques
            final dataLabels = analysisJson['dataLabels'] as List;
            final labels = dataLabels[0].toString();
            final values = dataLabels[1].toString();

            print("Colonnes attendues: $labels, $values"); // Debug log
            print("Colonnes disponibles: ${results.first.keys}"); // Debug log

            // Si les colonnes n'existent pas, afficher les données brutes
            if (!results.first.containsKey(labels) ||
                !results.first.containsKey(values)) {
              return [
                MessageData.text(results.map((row) {
                  return row.entries
                      .map((e) => "${e.key}: ${e.value ?? 'Non renseigné'}")
                      .join(' | ');
                }).join('\n'))
              ];
            }

            final chartUrl = await _generateChart(results,
                analysisJson['chartType'], userQuestion, labels, values);

            if (chartUrl.isNotEmpty) {
              final chartData = MessageData(
                type: MessageType.chart,
                content: chartUrl,
                metadata: {'chartType': analysisJson['chartType']},
              );

              final interpretation = await _getInterpretation(results);
              return [chartData, interpretation];
            }
            return [MessageData.text("Impossible de générer le graphique.")];

          default:
            // Fallback to simple formatting
            return _formatTableResults(results);
        }
      }

      // Si pas de visualisation nécessaire
      return await _processSQLQuery(userQuestion);
    } catch (e, stackTrace) {
      print("Erreur de traitement: $e"); // Debug log
      print("Stack trace: $stackTrace"); // Debug log
      return [
        MessageData.text(
            "Une erreur s'est produite lors de l'analyse. Veuillez reformuler votre demande.")
      ];
    }
  }

  Future<bool> _isConversationalQuery(String query) async {
    final conversationPrompt = """
Analyse cette entrée et détermine si c'est une question conversationnelle ou une requête liée aux données.
Entrée: "$query"

Réponds uniquement avec un JSON au format:
{
  "isConversational": true/false,
  "reason": "explication courte"
}

Exemples de questions conversationnelles:
- "Bonjour, comment allez-vous?"
- "Qu'est-ce que cette application peut faire?"
- "Au revoir"
- "Merci"
- "Qui êtes-vous?"

Exemples de requêtes de données:
- "Montre-moi les ventes d'aujourd'hui"
- "Combien de produits sont en stock?"
- "Liste des clients"
- "Affiche le tableau des ventes"
""";

    final response =
        await model.generateContent([Content.text(conversationPrompt)]);
    final json = extractAndParseJson(response.text ?? "");
    return json?['isConversational'] ?? false;
  }

  Future<List<MessageData>> _handleConversation(String query) async {
    final conversationPrompt = """
Tu es l'assistant IA de CaissePro, un logiciel de gestion de caisse et d'inventaire.
Contexte: Tu peux aider avec la gestion des produits, des ventes, des clients et des statistiques.

Question de l'utilisateur: "$query"

Instructions:
1. Reste professionnel et courtois
2. Explique brièvement tes capacités si on te le demande
3. Ne donne pas d'informations sur ta mise en œuvre technique
4. Pour les questions techniques, suggère d'utiliser les fonctions de l'application
5. Limite ta réponse à 2-3 phrases maximum

Réponse:
""";

    final response =
        await model.generateContent([Content.text(conversationPrompt)]);
    final answer =
        response.text ?? "Je ne comprends pas. Pouvez-vous reformuler ?";

    return [MessageData.text(answer)];
  }

  Future<List<MessageData>> _processSQLQuery(String userQuestion) async {
    try {
      // Modifier le prompt pour forcer une visualisation
      final analysisPrompt = """
Analyse cette demande et génère une visualisation appropriée.
Question: "$userQuestion"

Structure de la base de données:
${DatabaseTools.getSchemaDescription()}

Tu DOIS répondre avec un JSON au format suivant:
{
  "visualType": "table/chart",  // Choisis le type approprié
  "chartType": "bar/pie/line",  // Si visualType est "chart"
  "dataQuery": "REQUETE_SQL",
  "dataLabels": ["colonne1", "colonne2"],
  "title": "Titre du rapport"
}

Exemples de réponses:
1. Pour un rapport de produits:
{
  "visualType": "table",
  "dataQuery": "SELECT p.nom, c.nom as categorie, p.prix, p.stock, p.seuilAlerte FROM produits p LEFT JOIN categories c ON p.categorieId = c.id WHERE p.actif = 1",
  "dataLabels": ["Produit", "Catégorie", "Prix", "Stock", "Seuil"],
  "title": "Liste des produits"
}

2. Pour une vue des stocks:
{
  "visualType": "chart",
  "chartType": "bar",
  "dataQuery": "SELECT nom, stock FROM produits WHERE actif = 1 ORDER BY stock DESC LIMIT 10",
  "dataLabels": ["nom", "stock"],
  "title": "Niveau des stocks par produit"
}
""";

      final analysisResponse =
          await model.generateContent([Content.text(analysisPrompt)]);
      final config = extractAndParseJson(analysisResponse.text ?? "");

      if (config == null) {
        return [MessageData.text("Erreur d'analyse de la demande.")];
      }

      final results = await DatabaseTools.executeQuery(config['dataQuery'], []);

      if (results.isEmpty) {
        return [MessageData.text("Aucune donnée trouvée.")];
      }

      if (config['visualType'] == 'table') {
        final headers = results.first.keys.toList();
        final rows = results
            .map((row) => headers.map((h) => row[h]?.toString() ?? '').toList())
            .toList();

        return [MessageData.table(rows, headers)];
      } else if (config['visualType'] == 'chart') {
        final chartUrl = await _generateChart(results, config['chartType'],
            config['title'], config['dataLabels'][0], config['dataLabels'][1]);

        if (chartUrl.isNotEmpty) {
          return [
            MessageData(
              type: MessageType.chart,
              content: chartUrl,
              metadata: {
                'chartType': config['chartType'],
                'title': config['title']
              },
            )
          ];
        }
      }

      // Fallback en cas d'échec de visualisation
      return [MessageData.text("Erreur lors de la génération du rapport.")];
    } catch (e) {
      print('Erreur de traitement: $e');
      return [MessageData.text("Une erreur est survenue lors de l'analyse.")];
    }
  }

  Future<String> _generateChart(
      List<Map<String, dynamic>> data,
      String chartType,
      String question,
      String labelKey,
      String valueKey) async {
    final baseUrl = 'https://quickchart.io/chart';

    try {
      // Determine the effective chart type
      String effectiveChartType;
      switch (chartType.toLowerCase()) {
        case 'bar':
          effectiveChartType = 'bar';
          break;
        case 'line':
          effectiveChartType = 'line';
          break;
        case 'area':
          effectiveChartType = 'line'; // Line with fill
          break;
        case 'pie':
          effectiveChartType = 'pie';
          break;
        case 'doughnut':
          effectiveChartType = 'doughnut';
          break;
        case 'financial':
          effectiveChartType = 'candlestick';
          break;
        default:
          effectiveChartType = 'bar'; // Default to bar
      }

      // Prepare data based on chart type
      final labels = data.map((e) => e[labelKey]?.toString() ?? '').toList();
      List<dynamic> values;

      if (effectiveChartType == 'candlestick') {
        // Format for financial charts (OHLC data)
        values = data
            .map((e) => {
                  'o': double.tryParse(e['open']?.toString() ?? '0') ?? 0,
                  'h': double.tryParse(e['high']?.toString() ?? '0') ?? 0,
                  'l': double.tryParse(e['low']?.toString() ?? '0') ?? 0,
                  'c': double.tryParse(e['close']?.toString() ?? '0') ?? 0,
                })
            .toList();
      } else {
        // Format for regular charts
        values = data.map((e) {
          final val = e[valueKey];
          if (val is num) return val.toDouble();
          if (val is String) return double.tryParse(val) ?? 0.0;
          return 0.0;
        }).toList();
      }

      // Configuration du graphique
      final config = {
        'type': effectiveChartType,
        'data': {
          'labels': labels,
          'datasets': [
            {
              'label': question,
              'data': values,
              'backgroundColor': [
                'rgba(255, 99, 132, 0.5)',
                'rgba(54, 162, 235, 0.5)',
                'rgba(255, 206, 86, 0.5)',
                'rgba(75, 192, 192, 0.5)',
                'rgba(153, 102, 255, 0.5)',
                'rgba(255, 159, 64, 0.5)',
                'rgba(201, 203, 207, 0.5)',
                'rgba(255, 205, 86, 0.5)',
                'rgba(75, 192, 192, 0.5)',
              ],
              if (effectiveChartType == 'line') ..._getLineChartConfig(),
              if (effectiveChartType == 'area') ..._getAreaChartConfig(),
              if (effectiveChartType == 'candlestick')
                ..._getFinancialChartConfig(),
            }
          ]
        },
        'options': {
          'responsive': true,
          'maintainAspectRatio': false,
          'plugins': {
            'title': {'display': true, 'text': question},
            'legend': {'display': true, 'position': 'right'},
          },
          if (['bar', 'line', 'area'].contains(effectiveChartType)) ...{
            'scales': {
              'y': {
                'beginAtZero': true,
                'title': {'display': true, 'text': valueKey}
              },
              'x': {
                'title': {'display': true, 'text': labelKey}
              }
            }
          }
        }
      };

      final url =
          '$baseUrl?c=${Uri.encodeComponent(jsonEncode(config))}&w=600&h=400';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return url;
      }
      throw Exception('Erreur HTTP: ${response.statusCode}');
    } catch (e) {
      print('Erreur lors de la génération du graphique: $e');
      return '';
    }
  }

  Map<String, dynamic> _getLineChartConfig() {
    return {
      'borderColor': 'rgba(54, 162, 235, 1)',
      'borderWidth': 2,
      'pointRadius': 4,
      'pointBackgroundColor': 'rgba(54, 162, 235, 1)',
      'tension': 0.4,
    };
  }

  Map<String, dynamic> _getAreaChartConfig() {
    return {
      'borderColor': 'rgba(54, 162, 235, 1)',
      'borderWidth': 2,
      'pointRadius': 4,
      'pointBackgroundColor': 'rgba(54, 162, 235, 1)',
      'fill': true,
      'backgroundColor': 'rgba(54, 162, 235, 0.2)',
      'tension': 0.4,
    };
  }

  Map<String, dynamic> _getFinancialChartConfig() {
    return {
      'color': {
        'up': 'rgba(75, 192, 192, 1)',
        'down': 'rgba(255, 99, 132, 1)',
      },
      'borderColor': {
        'up': 'rgba(75, 192, 192, 1)',
        'down': 'rgba(255, 99, 132, 1)',
      },
    };
  }

  Map<String, dynamic>? extractAndParseJson(String text) {
    try {
      // Chercher le premier { et le dernier }
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}') + 1;

      if (start >= 0 && end > start) {
        final jsonStr = text.substring(start, end);
        return jsonDecode(jsonStr);
      }
      return null;
    } catch (e) {
      print("Erreur de parsing JSON: $e");
      return null;
    }
  }

  Future<List<MessageData>> _executeToolAndFormatResponse(
      Map<String, dynamic> toolRequest) async {
    print(
        "Exécution de l'outil: ${toolRequest['tool']} avec args: ${toolRequest['args']}"); // Debug

    try {
      String response = "";

      switch (toolRequest['tool']) {
        case 'fetchProduits':
          final data = await DatabaseTools.fetchData(
              whereClause: toolRequest['args']['whereClause']);
          response =
              "Voici les résultats: ${data.take(3)}... (${data.length} produits trouvés)";
          break;

        case 'countProduits':
          final count =
              await DatabaseTools.countRecords(toolRequest['args']['table']);
          response = "Il y a $count produits au total.";
          break;

        case 'getVentesParPeriode':
          final data = await DatabaseTools.getVentesParPeriode(
              toolRequest['args']['dateDebut'], toolRequest['args']['dateFin']);
          response = "Voici les ventes pour la période: ${_formatVentes(data)}";
          break;

        case 'getProduitsPopulaires':
          final data = await DatabaseTools.getProduitsPopulaires();
          response =
              "Top 5 des produits les plus vendus: ${_formatProduits(data)}";
          break;

        case 'getStockBas':
          final data = await DatabaseTools.getStockBas();
          response = "Produits en stock bas: ${_formatStockBas(data)}";
          break;

        case 'getStatistiquesJour':
          final data = await DatabaseTools.getStatistiquesJour(
              toolRequest['args']['date']);
          response = "Statistiques du jour: ${_formatStats(data)}";
          break;

        case 'searchProduits':
          final data =
              await DatabaseTools.searchProduits(toolRequest['args']['query']);
          response = "Résultats de la recherche: ${_formatProduits(data)}";
          break;

        case 'insertProduit':
          try {
            final Map<String, dynamic> productData = {
              'nom': toolRequest['args']['nom'],
              'prix': toolRequest['args']['prix'],
              'stock': toolRequest['args']['stock'] ?? 0,
              'actif': toolRequest['args']['actif'] ?? 1,
              'seuilAlerte': toolRequest['args']['seuilAlerte'] ?? 10,
            };

            final id = await DatabaseTools.insertProduit(productData);
            response =
                "✅ Produit '${productData['nom']}' ajouté avec succès (ID: $id)";
          } catch (e) {
            response = "❌ Erreur lors de l'ajout du produit: $e";
          }
          break;

        case 'updateProduit':
          final count = await DatabaseTools.updateProduit(
              toolRequest['args']['id'], toolRequest['args']['data']);
          response = count > 0
              ? "Produit mis à jour avec succès"
              : "Aucun produit mis à jour";
          break;

        case 'insertClient':
          final id = await DatabaseTools.insertClient(toolRequest['args']);
          response = "Client ajouté avec l'ID: $id";
          break;

        case 'insertCommande':
          final id = await DatabaseTools.insertCommande(toolRequest['args']);
          response = "Commande créée avec l'ID: $id";
          break;

        default:
          response = "Je ne peux pas exécuter cette commande.";
      }

      return [MessageData.text(response)];
    } catch (e) {
      return [MessageData.text("Erreur: $e")];
    }
  }

  String _formatVentes(List<Map<String, dynamic>> data) {
    return data
        .map((v) =>
            "${v['date']}: €${v['total_ventes']} (${v['nombre_commandes']} commandes)")
        .join("\n");
  }

  String _formatProduits(List<Map<String, dynamic>> data) {
    return data.map((p) => "${p['nom']}: €${p['prix']}").join("\n");
  }

  String _formatStockBas(List<Map<String, dynamic>> data) {
    return data
        .map((p) => "${p['nom']}: ${p['stock']}/${p['seuilAlerte']}")
        .join("\n");
  }

  String _formatStats(Map<String, dynamic> stats) {
    return """
    Commandes: ${stats['nombre_commandes']}
    Ventes: €${stats['total_ventes']}
    Clients: ${stats['nombre_clients']}
    """;
  }

  List<MessageData> _formatTableResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return [MessageData.text("Aucun résultat trouvé.")];

    final headers = results.first.keys.toList();
    final tableData = results.map((row) {
      return headers
          .map((header) => row[header]?.toString() ?? 'Non renseigné')
          .toList();
    }).toList();

    // Return only table view, PDF will be generated on demand
    return [MessageData.table(tableData, headers)];
  }

  Future<MessageData> _getInterpretation(
      List<Map<String, dynamic>> results) async {
    final interpretationPrompt = """
Analyse ces résultats:
${jsonEncode(results)}

Affiche uniquement les données sans analyse ni interprétation.
Présente les chiffres et informations de manière directe.
Ne fais aucun commentaire ni résumé supplémentaire.
""";

    final interpretation =
        await model.generateContent([Content.text(interpretationPrompt)]);
    return MessageData.text(interpretation.text ?? "Analyse effectuée.");
  }
}
