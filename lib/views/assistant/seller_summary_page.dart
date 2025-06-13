import 'package:caissepro/config/api_keys.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  final gemini = GeminiService(apiKey: ApiKeys.geminiApiKey);

  @override
  void initState() {
    super.initState();
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Tableau de bord intelligent',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue.shade700),
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyse des données en cours...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : summary == null
              ? Center(child: Text('Aucune donnée disponible'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewSection(),
                      SizedBox(height: 24),
                      _buildChartSection(),
                      SizedBox(height: 24),
                      _buildProductAnalysisSection(),
                      SizedBox(height: 24),
                      _buildSuggestionsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverviewSection() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          'Ventes Totales',
          currencyFormat.format(summary!.totalSales),
          Icons.euro,
          Colors.green.shade100,
          Colors.green,
          '+${summary!.variationSinceYesterday}% vs hier',
        ),
        _buildMetricCard(
          'Commandes',
          summary!.totalOrders.toString(),
          Icons.shopping_cart,
          Colors.blue.shade100,
          Colors.blue,
          'Panier moyen: ${currencyFormat.format(summary!.averageBasket)}',
        ),
        _buildMetricCard(
          'Clients',
          summary!.totalClients.toString(),
          Icons.people,
          Colors.purple.shade100,
          Colors.purple,
          'Heure de pic: ${summary!.peakHour}',
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color bgColor, Color iconColor, String subtitle) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: Colors.grey[700], fontWeight: FontWeight.w500)),
            ],
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800]),
          ),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tendance des ventes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          Container(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 3),
                      FlSpot(2.6, 2),
                      FlSpot(4.9, 5),
                      FlSpot(6.8, 3.1),
                      FlSpot(8, 4),
                      FlSpot(9.5, 3),
                      FlSpot(11, 4),
                    ],
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade300, Colors.blue.shade900],
                    ),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade200.withOpacity(0.3),
                          Colors.blue.shade900.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductAnalysisSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analyse des produits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildProductMetric(
                  'Plus vendu',
                  summary!.topProductByQuantity,
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: _buildProductMetric(
                  'Meilleur CA',
                  summary!.topProductByRevenue,
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductMetric(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommandations IA',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          ...summary!.suggestions.map((suggestion) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(suggestion,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14)),
                    ),
                  ],
                ),
              )),
          if (summary!.stockAlerts.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Alertes stock',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red)),
            SizedBox(height: 8),
            ...summary!.stockAlerts.map((alert) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(alert,
                            style: TextStyle(color: Colors.red[700])),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
