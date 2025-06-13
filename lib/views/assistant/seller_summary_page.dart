import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ai_agent/gemini_service.dart';
import '../../services/seller_summary_service.dart';
import '../../models/seller_summary.dart';

class SellerSummaryPage extends StatefulWidget {
  const SellerSummaryPage({super.key});

  @override
  State<SellerSummaryPage> createState() => _SellerSummaryPageState();
}

class _SellerSummaryPageState extends State<SellerSummaryPage> {
  late SellerSummaryService service;
  SellerSummary? summary;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final gemini = GeminiService(apiKey: 'AIzaSyCCVre0MdH35vty9lRbqQ0FglYKPt8KQ9c');
    service = SellerSummaryService(gemini);
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final result = await service.generateSummary(DateTime.now());
    setState(() {
      summary = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Résumé intelligent de votre journée')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          setState(() => loading = true);
          await _loadSummary();
        },
        child: const Icon(Icons.refresh),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : summary == null
              ? const Center(child: Text('Aucune donnée'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      _buildAnalysisCard(),
                      const SizedBox(height: 16),
                      _buildSuggestionsCard(),
                      const SizedBox(height: 16),
                      _buildMotivationCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistiques journalières',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Total ventes: ${summary!.totalSales.toStringAsFixed(2)} €',
                style: const TextStyle(fontSize: 16)),
            Text('Nombre de commandes: ${summary!.totalOrders}',
                style: const TextStyle(fontSize: 16)),
            Text('Nombre de clients: ${summary!.totalClients}',
                style: const TextStyle(fontSize: 16)),
            Text('Panier moyen: ${summary!.averageBasket.toStringAsFixed(2)} €',
                style: const TextStyle(fontSize: 16)),
            Text('Heure de pic: ${summary!.peakHour}',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analyse IA de performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Produit le plus vendu: ${summary!.topProductByQuantity}'),
            Text(
                'Produit ayant généré le plus de CA: ${summary!.topProductByRevenue}'),
            Text(
                'Variation vs hier: ${summary!.variationSinceYesterday.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommandations IA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...summary!.suggestions.map((s) => Text('• $s')),
            if (summary!.stockAlerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Alertes stock:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...summary!.stockAlerts.map((s) => Text('- $s')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Message de motivation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(summary!.motivationalMessage),
          ],
        ),
      ),
    );
  }
}
