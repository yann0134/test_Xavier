import 'package:sqflite/sqflite.dart';
import '../ai_tool.dart';
import '../../services/db_helper.dart';

class InventoryTool implements AITool {
  @override
  String get name => 'inventory';

  @override
  String get description => '''
    Permet d'obtenir des informations sur l'inventaire des produits.
    Capacités:
    - Compter le nombre total de produits
    - Lister les produits par catégorie
    - Vérifier les stocks bas
    - Analyser les ventes
  ''';

  @override
  bool canHandle(String query) {
    final normalized = query.toLowerCase();
    final keywords = [
      'produit',
      'stock',
      'inventaire',
      'catégorie',
      'vente',
      'combien',
      'liste'
    ];
    return keywords.any((k) => normalized.contains(k));
  }

  @override
  Future<String> handle(String query) async {
    final normalized = query.toLowerCase().trim();
    final db = await DBHelper.database;

    // Amélioration de la détection pour le comptage des produits
    if (normalized.contains('nombre') ||
        normalized.contains('combien') ||
        (normalized.contains('produit') && normalized.contains('enregistr'))) {
      return await _getProductCount(db);
    }

    // Gestion plus flexible des requêtes sur les stocks bas
    if (normalized.contains('stock') &&
            (normalized.contains('bas') || normalized.contains('faible')) ||
        normalized.contains('alerte')) {
      return await _getLowStockProducts(db);
    }

    // Meilleure détection des requêtes par catégorie
    if ((normalized.contains('liste') ||
            normalized.contains('voir') ||
            normalized.contains('affiche')) &&
        normalized.contains('catégorie')) {
      return await _getProductsByCategory(db);
    }

    // Si aucune correspondance n'est trouvée, suggérer des commandes
    return '''Je n'ai pas bien compris votre demande. Voici ce que je peux faire :

1. Compter les produits (ex: "combien y a-t-il de produits?")
2. Vérifier les stocks bas (ex: "montre les stocks bas")
3. Lister par catégorie (ex: "liste des produits par catégorie")

Essayez une de ces formulations.''';
  }

  Future<String> _getProductCount(Database db) async {
    try {
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN stock > 0 THEN 1 ELSE 0 END) as in_stock,
          SUM(CASE WHEN stock = 0 THEN 1 ELSE 0 END) as out_of_stock,
          COUNT(DISTINCT categorieId) as categories_count
        FROM produits 
        WHERE actif = 1
      ''');

      final total = result.first['total'] as int;
      final inStock = result.first['in_stock'] as int;
      final outOfStock = result.first['out_of_stock'] as int;
      final categoriesCount = result.first['categories_count'] as int;

      return '''
📊 État de l'inventaire :

Il y a actuellement $total produits enregistrés, répartis dans $categoriesCount catégories :
- $inStock produits en stock
- $outOfStock produits en rupture de stock

| État | Nombre |
|------|--------|
| Total produits | $total |
| Produits en stock | $inStock |
| Produits en rupture | $outOfStock |
| Nombre de catégories | $categoriesCount |

Voulez-vous plus de détails sur une catégorie spécifique ou voir les produits en stock bas ?
''';
    } catch (e) {
      print('Erreur lors du comptage des produits: $e');
      return "Désolé, je n'ai pas pu compter les produits. Une erreur est survenue.";
    }
  }

  Future<String> _getLowStockProducts(Database db) async {
    final products = await db.rawQuery('''
      SELECT p.nom, p.stock, p.seuilAlerte, c.nom as categorie
      FROM produits p
      LEFT JOIN categories c ON p.categorieId = c.id
      WHERE p.stock <= p.seuilAlerte AND p.actif = 1
      ORDER BY p.stock ASC
    ''');

    if (products.isEmpty) {
      return 'Aucun produit n\'est actuellement en stock bas.';
    }

    String table =
        '| Produit | Catégorie | Stock | Seuil |\n|----------|-----------|--------|--------|\n';
    for (var p in products) {
      table +=
          '| ${p['nom']} | ${p['categorie'] ?? 'Non catégorisé'} | ${p['stock']} | ${p['seuilAlerte']} |\n';
    }

    return 'Voici la liste des produits en stock bas:\n\n$table';
  }

  Future<String> _getProductsByCategory(Database db) async {
    final categories = await db.rawQuery('''
      SELECT 
        c.nom as categorie,
        COUNT(p.id) as count,
        SUM(p.stock) as total_stock
      FROM categories c
      LEFT JOIN produits p ON c.id = p.categorieId AND p.actif = 1
      GROUP BY c.id
      ORDER BY count DESC
    ''');

    String table =
        '| Catégorie | Nombre de produits | Stock total |\n|------------|------------------|-------------|\n';
    for (var c in categories) {
      table += '| ${c['categorie']} | ${c['count']} | ${c['total_stock']} |\n';
    }

    return 'Voici la répartition des produits par catégorie:\n\n$table';
  }
}
