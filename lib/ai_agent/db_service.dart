import 'package:sqflite/sqflite.dart';
import '../services/db_helper.dart';

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  static const dbSchema = '''
Tables disponibles:
- produits (id, nom, prix, stock, seuilAlerte, categorieId, uniteId, actif)
- categories (id, nom)
- ventes (id, date, montantTotal, userId)
- vente_details (id, venteId, produitId, quantite, prixUnitaire)
- users (id, nom, role)
''';

  Future<Map<String, dynamic>> executeQuery(String query) async {
    try {
      final db = await DBHelper.database;
      final results = await db.rawQuery(query);
      return {'success': true, 'data': results, 'error': null};
    } catch (e) {
      return {'success': false, 'data': null, 'error': e.toString()};
    }
  }
}
