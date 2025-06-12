import '../../services/db_helper.dart';
import '../ai_tool.dart';

class DatabaseTool implements AITool {
  @override
  String get name => 'database';

  @override
  String get description => 'Query local database for simple information';

  @override
  bool canHandle(String query) {
    final lower = query.toLowerCase();
    return lower.startsWith('count ') || lower.startsWith('list ');
  }

  @override
  Future<String> handle(String query) async {
    final db = await DBHelper.database;
    final lower = query.toLowerCase();
    if (lower.startsWith('count products')) {
      final result = await db.rawQuery('SELECT COUNT(*) as c FROM produits');
      final c = result.first['c'];
      return 'Total products: $c';
    } else if (lower.startsWith('count users')) {
      final result = await db.rawQuery('SELECT COUNT(*) as c FROM utilisateurs');
      final c = result.first['c'];
      return 'Total users: $c';
    } else if (lower.startsWith('list products')) {
      final rows = await db.query('produits', columns: ['nom'], limit: 5);
      if (rows.isEmpty) return 'No products found';
      return rows.map((e) => e['nom']).join(', ');
    }
    return 'Query not supported';
  }
}
