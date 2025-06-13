import 'package:intl/intl.dart';
import '../ai_agent/gemini_service.dart';
import 'database_tools.dart';
import '../models/seller_summary.dart';

class SellerSummaryService {
  final GeminiService gemini;

  SellerSummaryService(this.gemini);

  Future<SellerSummary> generateSummary(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final stats = await DatabaseTools.getStatistiquesJour(dateStr);

    final totalOrders = stats['nombre_commandes'] as int? ?? 0;
    final totalSales = (stats['total_ventes'] as num?)?.toDouble() ?? 0.0;
    final totalClients = stats['nombre_clients'] as int? ?? 0;

    final previousStats = await DatabaseTools.getStatistiquesJour(
        DateFormat('yyyy-MM-dd')
            .format(date.subtract(const Duration(days: 1))));
    final prevSales =
        (previousStats['total_ventes'] as num?)?.toDouble() ?? 0.0;
    final variation =
        prevSales == 0 ? 0 : ((totalSales - prevSales) / prevSales) * 100;

    final bestSeller = await DatabaseTools.executeQuery('''
      SELECT p.nom, SUM(cp.quantite) as qty
      FROM commande_produits cp
      JOIN produits p ON cp.produitId = p.id
      JOIN commandes c ON cp.commandeId = c.id
      WHERE date(c.date) = date(?)
      GROUP BY p.id
      ORDER BY qty DESC
      LIMIT 1
    ''', [dateStr]);
    final topProductByQuantity =
        bestSeller.isNotEmpty ? bestSeller.first['nom'] as String : '-';

    final bestRevenue = await DatabaseTools.executeQuery('''
      SELECT p.nom, SUM(cp.quantite * cp.prixUnitaire) as total
      FROM commande_produits cp
      JOIN produits p ON cp.produitId = p.id
      JOIN commandes c ON cp.commandeId = c.id
      WHERE date(c.date) = date(?)
      GROUP BY p.id
      ORDER BY total DESC
      LIMIT 1
    ''', [dateStr]);
    final topProductByRevenue =
        bestRevenue.isNotEmpty ? bestRevenue.first['nom'] as String : '-';

    final hours = await DatabaseTools.executeQuery('''
      SELECT strftime('%H', c.date) as hour, COUNT(*) as cnt
      FROM commandes c
      WHERE date(c.date) = date(?)
      GROUP BY hour
      ORDER BY cnt DESC
      LIMIT 1
    ''', [dateStr]);
    final peakHour = hours.isNotEmpty ? '${hours.first['hour']}h' : '-';

    final averageBasket = totalOrders == 0 ? 0 : totalSales / totalOrders;

    final lowStock = await DatabaseTools.executeQuery('''
      SELECT nom FROM produits WHERE stock <= seuilAlerte AND actif = 1
    ''');
    final stockAlerts =
        lowStock.map((e) => e['nom'] as String).take(3).toList();

    final prompt = '''
Génère des conseils pour améliorer les ventes demain en te basant sur :
- Produit le plus vendu: $topProductByQuantity
- Produit avec le plus de chiffre d'affaires: $topProductByRevenue
- Variation par rapport à hier: ${variation.toStringAsFixed(1)}%
Réponds par une liste de 2 à 3 phrases courtes.
''';
    final suggestionResp = await gemini.decideTool(prompt, []);
    final suggestions =
        (suggestionResp['answer'] as String?)?.split('\n') ?? [];

    final motivPrompt = '''
Écris un court message de motivation pour un vendeur.
Chiffre d'affaires du jour: ${totalSales.toStringAsFixed(2)} €.
Variation par rapport à hier: ${variation.toStringAsFixed(1)}%.
''';
    final motivResp = await gemini.decideTool(motivPrompt, []);
    final motivational = motivResp['answer'] as String? ?? '';

    return SellerSummary(
      totalOrders: totalOrders,
      totalSales: totalSales,
      totalClients: totalClients,
      peakHour: peakHour,
      topProductByQuantity: topProductByQuantity,
      topProductByRevenue: topProductByRevenue,
      averageBasket: averageBasket.toDouble(),
      variationSinceYesterday: variation.toDouble(),
      suggestions: suggestions,
      stockAlerts: stockAlerts,
      motivationalMessage: motivational,
    );
  }
}
