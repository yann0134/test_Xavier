import 'package:intl/intl.dart';
import 'db_helper.dart';

class ObjectiveService {
  static Future<void> createObjectiveIfNeeded({required int sellerId}) async {
    final db = await DBHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = await db.query('objectives',
        where: 'seller_id = ? AND target_date = ?',
        whereArgs: [sellerId, today]);
    if (existing.isNotEmpty) return;

    // Simple AI logic placeholder: 10% more than average of last 7 days
    final avg = await db.rawQuery('''
      SELECT AVG(total) as avg_total FROM commandes
      WHERE date(date) >= date('now','-7 day')
    ''');
    final avgTotal = (avg.first['avg_total'] as num?)?.toDouble() ?? 0.0;
    final targetAmount = avgTotal * 1.1; // +10%

    await db.insert('objectives', {
      'seller_id': sellerId,
      'target_date': today,
      'target_sales_amount': targetAmount,
      'target_sales_count': 20,
      'generated_by_ai': 1,
      'generated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getTodayObjective(int sellerId) async {
    final db = await DBHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.query('objectives',
        where: 'seller_id = ? AND target_date = ?',
        whereArgs: [sellerId, today]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<double> getTodaySales() async {
    final db = await DBHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await db.rawQuery(
        'SELECT SUM(total) as sum FROM commandes WHERE date(date) = date(?)',
        [today]);
    return (res.first['sum'] as num?)?.toDouble() ?? 0.0;
  }
}
