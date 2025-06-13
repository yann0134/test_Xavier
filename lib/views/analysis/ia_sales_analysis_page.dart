import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/db_helper.dart';

class IASalesAnalysisPage extends StatefulWidget {
  const IASalesAnalysisPage({super.key});

  @override
  State<IASalesAnalysisPage> createState() => _IASalesAnalysisPageState();
}

class _IASalesAnalysisPageState extends State<IASalesAnalysisPage> {
  bool _loading = true;
  String _period = 'week';

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _best = [];
  List<Map<String, dynamic>> _worst = [];
  List<String> _anomalies = [];
  List<String> _recommendations = [];
  List<FlSpot> _forecast = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DBHelper.database;
    DateTime now = DateTime.now();
    DateTime start;
    DateTime prevStart;
    DateTime prevEnd;
    if (_period == 'day') {
      start = DateTime(now.year, now.month, now.day);
      prevStart = start.subtract(const Duration(days: 1));
      prevEnd = start.subtract(const Duration(seconds: 1));
    } else if (_period == 'month') {
      start = DateTime(now.year, now.month, 1);
      prevStart = DateTime(now.year, now.month - 1, 1);
      prevEnd = start.subtract(const Duration(days: 1));
    } else {
      start = now.subtract(const Duration(days: 7));
      prevStart = start.subtract(const Duration(days: 7));
      prevEnd = start.subtract(const Duration(seconds: 1));
    }

    final current = await db.rawQuery('''
      SELECT COUNT(*) as c, COALESCE(SUM(total),0) as s, COALESCE(AVG(total),0) as a
      FROM commandes WHERE date BETWEEN ? AND ?
    ''', [start.toIso8601String(), now.toIso8601String()]);

    final previous = await db.rawQuery('''
      SELECT COUNT(*) as c, COALESCE(SUM(total),0) as s, COALESCE(AVG(total),0) as a
      FROM commandes WHERE date BETWEEN ? AND ?
    ''', [prevStart.toIso8601String(), prevEnd.toIso8601String()]);

    final total = _toDouble(current.first['s']);
    final count = _toInt(current.first['c']);
    final avg = _toDouble(current.first['a']);
    final prevTotal = _toDouble(previous.first['s']);
    final prevCount = _toInt(previous.first['c']);
    final prevAvg = _toDouble(previous.first['a']);

    final best = await db.rawQuery('''
      SELECT p.nom, SUM(cp.quantite) as q, SUM(cp.quantite*cp.prixUnitaire) as amount
      FROM commande_produits cp
      JOIN produits p ON cp.produitId = p.id
      JOIN commandes c ON cp.commandeId = c.id
      WHERE c.date BETWEEN ? AND ?
      GROUP BY p.id, p.nom
      ORDER BY q DESC
      LIMIT 5
    ''', [start.toIso8601String(), now.toIso8601String()]);

    final worst = await db.rawQuery('''
      SELECT p.nom, p.stock, COALESCE(SUM(cp.quantite),0) as q
      FROM produits p
      LEFT JOIN commande_produits cp ON p.id = cp.produitId
      LEFT JOIN commandes c ON cp.commandeId = c.id AND c.date BETWEEN ? AND ?
      WHERE p.actif = 1
      GROUP BY p.id, p.nom, p.stock
      ORDER BY q ASC
      LIMIT 5
    ''', [start.toIso8601String(), now.toIso8601String()]);

    final last30 = await db.rawQuery('''
      SELECT date, SUM(total) as t
      FROM commandes
      WHERE date >= ?
      GROUP BY date
      ORDER BY date DESC
      LIMIT 30
    ''', [now.subtract(const Duration(days: 30)).toIso8601String()]);

    double avgDaily = last30.isNotEmpty
        ? last30.map((e) => _toDouble(e['t'])).reduce((a, b) => a + b) /
            last30.length
        : 0;
    _forecast = List.generate(7, (i) => FlSpot(i.toDouble(), avgDaily));

    _anomalies = [];
    if (prevTotal > 0 && ((total - prevTotal) / prevTotal).abs() > 0.1) {
      _anomalies.add(total > prevTotal
          ? "Chiffre d'affaires anormalement élevé"
          : "Baisse significative du chiffre d'affaires");
    }

    _recommendations = worst
        .where((p) => _toInt(p['q']) == 0 && _toInt(p['stock']) > 0)
        .map((p) => 'Déstocker rapidement ${p['nom']}')
        .toList();

    setState(() {
      _summary = {
        'total': total,
        'count': count,
        'avg': avg,
        'pctTotal': _calcPct(total, prevTotal),
        'pctCount': _calcPct(count.toDouble(), prevCount.toDouble()),
        'pctAvg': _calcPct(avg, prevAvg),
      };
      _best = best;
      _worst = worst;
      _loading = false;
    });
  }

  double _calcPct(double current, double prev) {
    if (prev == 0) return 0;
    return ((current - prev) / prev) * 100;
  }

  double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse IA')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Analyse des ventes',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        DropdownButton<String>(
                          value: _period,
                          items: const [
                            DropdownMenuItem(
                                value: 'day', child: Text('Jour')),
                            DropdownMenuItem(
                                value: 'week', child: Text('Semaine')),
                            DropdownMenuItem(
                                value: 'month', child: Text('Mois')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _period = v;
                              _loading = true;
                            });
                            _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSummary(),
                    const SizedBox(height: 24),
                    _buildBestProducts(),
                    const SizedBox(height: 24),
                    _buildWorstProducts(),
                    const SizedBox(height: 24),
                    _buildAnomalies(),
                    const SizedBox(height: 24),
                    _buildRecommendations(),
                    const SizedBox(height: 24),
                    _buildForecast(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Chiffre d\'affaires',
                '€${_summary['total'].toStringAsFixed(2)}', _summary['pctTotal']),
            _buildStat('Commandes', '${_summary['count']}', _summary['pctCount']),
            _buildStat('Panier moyen',
                '€${_summary['avg'].toStringAsFixed(2)}', _summary['pctAvg']),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, double pct) {
    final positive = pct >= 0;
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(color: positive ? Colors.green : Colors.red),
        )
      ],
    );
  }

  Widget _buildBestProducts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top produits',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._best.map((p) => _buildProductItem(p['nom'], _toInt(p['q']),
                _toDouble(p['amount']), Colors.blue)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorstProducts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Produits en difficulté',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._worst.map((p) => _buildProductItem(
                p['nom'], _toInt(p['q']), 0, Colors.orange)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(
      String name, int qty, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text(qty.toString()),
          const SizedBox(width: 8),
          if (amount > 0)
            Text('€${amount.toStringAsFixed(2)}',
                style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildAnomalies() {
    if (_anomalies.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anomalies détectées',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._anomalies.map((a) => Text('- $a')),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommandations',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._recommendations.map((r) => Text('- $r')),
          ],
        ),
      ),
    );
  }

  Widget _buildForecast() {
    if (_forecast.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prévision CA (7 jours)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _forecast,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
