import 'db_helper.dart';
import '../models/anomaly.dart';

class AnomalyDetectionService {
  Future<List<Anomaly>> detect(DateTime start, DateTime end) async {
    final db = await DBHelper.database;
    final anomalies = <Anomaly>[];

    // Baisse de chiffre d'affaires par rapport à la moyenne des 7 derniers jours
    final currentRes = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) as sum FROM commandes WHERE date BETWEEN ? AND ?',
        [start.toIso8601String(), end.toIso8601String()]);
    final currentTotal = (currentRes.first['sum'] as num?)?.toDouble() ?? 0.0;

    final prevRes = await db.rawQuery(
        "SELECT AVG(total) as avg_total FROM commandes WHERE date BETWEEN ? AND ?",
        [
          start.subtract(const Duration(days: 7)).toIso8601String(),
          end.subtract(const Duration(days: 1)).toIso8601String()
        ]);
    final avgTotal = (prevRes.first['avg_total'] as num?)?.toDouble() ?? 0.0;
    if (avgTotal > 0) {
      final diff = ((currentTotal - avgTotal) / avgTotal) * 100;
      if (diff < -20) {
        anomalies.add(Anomaly(
          sellerName: 'Global',
          detectedAt: DateTime.now(),
          description:
              'Baisse de chiffre d\'affaires de ${diff.abs().toStringAsFixed(1)}%',
          comparison:
              'Moyenne 7 jours: ${avgTotal.toStringAsFixed(2)}€',
          recommendation: 'Analyser les ventes récentes',
          severity: diff < -40 ? 'critical' : 'moderate',
        ));
      }
    }

    // Suppressions de commandes inhabituelles
    final delCount = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM deleted_sales WHERE deleted_at BETWEEN ? AND ?',
        [start.toIso8601String(), end.toIso8601String()]);
    final deletions = delCount.first['cnt'] as int? ?? 0;
    if (deletions > 3) {
      anomalies.add(Anomaly(
        sellerName: 'Global',
        detectedAt: DateTime.now(),
        description:
            'Répétition d\'annulation de commandes ($deletions) sur la période',
        comparison: 'Seuil normal: 3',
        recommendation: 'Vérifier les annulations récentes',
        severity: deletions > 5 ? 'critical' : 'moderate',
      ));
    }

    // Variation du panier moyen
    final curAvg = await db.rawQuery(
        'SELECT AVG(total) as avg_total FROM commandes WHERE date BETWEEN ? AND ?',
        [start.toIso8601String(), end.toIso8601String()]);
    final curBasket = (curAvg.first['avg_total'] as num?)?.toDouble() ?? 0.0;
    final pastAvg = await db.rawQuery(
        'SELECT AVG(total) as avg_total FROM commandes WHERE date BETWEEN ? AND ?',
        [
          start.subtract(const Duration(days: 7)).toIso8601String(),
          end.subtract(const Duration(days: 1)).toIso8601String()
        ]);
    final pastBasket = (pastAvg.first['avg_total'] as num?)?.toDouble() ?? 0.0;
    if (pastBasket > 0) {
      final diff = ((curBasket - pastBasket) / pastBasket) * 100;
      if (diff.abs() > 20) {
        anomalies.add(Anomaly(
          sellerName: 'Global',
          detectedAt: DateTime.now(),
          description:
              'Variation du panier moyen de ${diff.toStringAsFixed(1)}%',
          comparison:
              'Moyenne 7 jours: ${pastBasket.toStringAsFixed(2)}€',
          recommendation: 'Contrôler les remises et promotions',
          severity: diff.abs() > 40 ? 'critical' : 'moderate',
        ));
      }
    }

    return anomalies;
  }
}
