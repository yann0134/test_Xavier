import 'db_helper.dart';

class DatabaseTools {
  static Future<List<Map<String, dynamic>>> fetchData(
      {String? whereClause}) async {
    final db = await DBHelper.database;
    return db.query('produits', where: whereClause);
  }

  static Future<int> countRecords(String table) async {
    final db = await DBHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    return result.first['count'] as int;
  }

  static Future<List<Map<String, dynamic>>> getVentesParPeriode(
      String dateDebut, String dateFin) async {
    final db = await DBHelper.database;
    return db.rawQuery('''
      SELECT 
        c.date, 
        SUM(c.total) as total_ventes,
        COUNT(*) as nombre_commandes
      FROM commandes c
      WHERE c.date BETWEEN ? AND ?
      GROUP BY c.date
    ''', [dateDebut, dateFin]);
  }

  static Future<List<Map<String, dynamic>>> getProduitsPopulaires() async {
    final db = await DBHelper.database;
    return db.rawQuery('''
      SELECT 
        p.nom,
        p.prix,
        SUM(cp.quantite) as total_vendu
      FROM produits p
      JOIN commande_produits cp ON p.id = cp.produitId
      GROUP BY p.id
      ORDER BY total_vendu DESC
      LIMIT 5
    ''');
  }

  static Future<List<Map<String, dynamic>>> getStockBas() async {
    final db = await DBHelper.database;
    return db.rawQuery('''
      SELECT nom, stock, seuilAlerte
      FROM produits
      WHERE stock <= seuilAlerte AND actif = 1
    ''');
  }

  static Future<Map<String, dynamic>> getStatistiquesJour(String date) async {
    final db = await DBHelper.database;
    final results = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT c.id) as nombre_commandes,
        SUM(c.total) as total_ventes,
        COUNT(DISTINCT c.clientId) as nombre_clients
      FROM commandes c
      WHERE date(c.date) = date(?)
    ''', [date]);
    return results.first;
  }

  static Future<List<Map<String, dynamic>>> searchProduits(String query) async {
    final db = await DBHelper.database;
    return db.query(
      'produits',
      where: 'nom LIKE ? AND actif = 1',
      whereArgs: ['%$query%'],
    );
  }

  // =========== CRUD Produits ===========
  static Future<int> insertProduit(Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.insert('produits', data);
  }

  static Future<int> updateProduit(int id, Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.update('produits', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteProduit(int id) async {
    final db = await DBHelper.database;
    return await db.delete('produits', where: 'id = ?', whereArgs: [id]);
  }

  // =========== CRUD Categories ===========
  static Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await DBHelper.database;
    return await db.query('categories');
  }

  static Future<int> insertCategorie(Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.insert('categories', data);
  }

  static Future<int> updateCategorie(int id, Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db
        .update('categories', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteCategorie(int id) async {
    final db = await DBHelper.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // =========== CRUD Clients ===========
  static Future<List<Map<String, dynamic>>> getAllClients() async {
    final db = await DBHelper.database;
    return await db.query('clients');
  }

  static Future<Map<String, dynamic>?> getClient(int id) async {
    final db = await DBHelper.database;
    final results = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<int> insertClient(Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.insert('clients', data);
  }

  static Future<int> updateClient(int id, Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.update('clients', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteClient(int id) async {
    final db = await DBHelper.database;
    return await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  // =========== CRUD Commandes ===========
  static Future<List<Map<String, dynamic>>> getCommandes(
      {String? whereClause}) async {
    final db = await DBHelper.database;
    return await db.query('commandes', where: whereClause);
  }

  static Future<int> insertCommande(Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.insert('commandes', data);
  }

  static Future<int> updateCommande(int id, Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.update('commandes', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteCommande(int id) async {
    final db = await DBHelper.database;
    return await db.delete('commandes', where: 'id = ?', whereArgs: [id]);
  }

  // =========== CRUD Commande Produits ===========
  static Future<int> insertCommandeProduit(Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.insert('commande_produits', data);
  }

  static Future<int> updateCommandeProduit(
      int id, Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db
        .update('commande_produits', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteCommandeProduit(int id) async {
    final db = await DBHelper.database;
    return await db
        .delete('commande_produits', where: 'id = ?', whereArgs: [id]);
  }

  // =========== CRUD Paiements ===========
  static Future<List<Map<String, dynamic>>> getPaiementsCommande(
      int commandeId) async {
    final db = await DBHelper.database;
    return await db
        .query('paiements', where: 'commandeId = ?', whereArgs: [commandeId]);
  }

  static Future<int> insertPaiement(Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.insert('paiements', data);
  }

  static Future<int> updatePaiement(int id, Map<String, dynamic> data) async {
    final db = await DBHelper.database;
    return await db.update('paiements', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deletePaiement(int id) async {
    final db = await DBHelper.database;
    return await db.delete('paiements', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> executeQuery(String query,
      [List<dynamic>? arguments]) async {
    try {
      final db = await DBHelper.database;
      return await db.rawQuery(query, arguments);
    } catch (e) {
      print('Erreur SQL: $e');
      throw Exception('Erreur lors de l\'exécution de la requête: $e');
    }
  }

  static Future<List<dynamic>> executeMultipleQueries(
      String query, List<dynamic> params) async {
    try {
      final db = await DBHelper.database;

      // Séparer les requêtes
      final queries =
          query.split(';').where((q) => q.trim().isNotEmpty).toList();
      final paramsPerQuery = params.length ~/ queries.length;

      final results = <dynamic>[];

      // Exécuter chaque requête avec ses paramètres
      for (var i = 0; i < queries.length; i++) {
        final start = i * paramsPerQuery;
        final end = start + paramsPerQuery;
        final queryParams = params.sublist(start, end);

        final result = await db.rawQuery(queries[i], queryParams);
        results.add(result);
      }

      return results;
    } catch (e) {
      print('Erreur SQL: $e');
      throw Exception('Erreur lors de l\'exécution des requêtes: $e');
    }
  }

  static String getSchemaDescription() {
    return '''
Tables et leurs structures:

produits:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - nom (TEXT NOT NULL)
  - categorieId (INTEGER, FOREIGN KEY -> categories.id)
  - prix (REAL NOT NULL)
  - stock (INTEGER NOT NULL)
  - seuilAlerte (INTEGER)
  - actif (INTEGER NOT NULL)

categories:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - nom (TEXT NOT NULL)

clients:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - nom (TEXT NOT NULL)
  - telephone (TEXT)
  - email (TEXT)

commandes:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - clientId (INTEGER, FOREIGN KEY -> clients.id)
  - date (TEXT NOT NULL)
  - total (REAL NOT NULL)
  - statut (TEXT NOT NULL)

commande_produits:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - commandeId (INTEGER, FOREIGN KEY -> commandes.id)
  - produitId (INTEGER, FOREIGN KEY -> produits.id)
  - quantite (INTEGER NOT NULL)
  - prixUnitaire (REAL NOT NULL)

recus:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - commandeId (INTEGER, FOREIGN KEY -> commandes.id)
  - date (TEXT NOT NULL)
  - montant (REAL NOT NULL)
  - moyenPaiement (TEXT NOT NULL)
  - numeroRecu (TEXT NOT NULL)

paiements:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - commandeId (INTEGER, FOREIGN KEY -> commandes.id)
  - montant (REAL NOT NULL)
  - moyenPaiement (TEXT NOT NULL)
  - date (TEXT NOT NULL)

utilisateurs:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - nom (TEXT NOT NULL)
  - email (TEXT UNIQUE)
  - motDePasse (TEXT NOT NULL)
  - role (TEXT NOT NULL)

parametres:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - cle (TEXT UNIQUE NOT NULL)
  - valeur (TEXT)

rapports:
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - date (TEXT NOT NULL)
  - totalVentes (REAL)
  - totalCommandes (INTEGER)
  - nombreClients (INTEGER)

Relations principales:
- produits.categorieId -> categories.id
- commandes.clientId -> clients.id
- commande_produits.commandeId -> commandes.id
- commande_produits.produitId -> produits.id
- recus.commandeId -> commandes.id
- paiements.commandeId -> commandes.id
''';
  }
}
