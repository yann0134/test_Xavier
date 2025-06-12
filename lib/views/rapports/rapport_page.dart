import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';

class RapportPage extends StatefulWidget {
  @override
  _RapportPageState createState() => _RapportPageState();
}

class _RapportPageState extends State<RapportPage> {
  final _dbHelper = DBHelper();

  Map<String, dynamic> _stats = {
    'chiffreAffaires': 0.0,
    'pourcentageCA': 0.0,
    'nombreCommandes': 0,
    'pourcentageCommandes': 0.0,
    'panierMoyen': 0.0,
    'pourcentagePanier': 0.0,
  };
  List<FlSpot> _ventesData = [];
  List<Map<String, dynamic>> _topProduits = [];
  List<Map<String, dynamic>> _paiements = [];
  Map<String, int> _stockStatus = {};
  DateTime _dateDebut = DateTime.now().subtract(Duration(days: 7));
  DateTime _dateFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DBHelper.database;

      // Chargement des statistiques générales avec CAST explicite
      final currentPeriod = await db.rawQuery('''
        SELECT 
          COUNT(*) as nb_commandes,
          COALESCE(CAST(SUM(total) as REAL), 0.0) as ca_total,
          COALESCE(CAST(AVG(total) as REAL), 0.0) as panier_moyen
        FROM commandes
        WHERE date BETWEEN ? AND ?
      ''', [_dateDebut.toIso8601String(), _dateFin.toIso8601String()]);

      final previousPeriod = await db.rawQuery('''
        SELECT 
          COUNT(*) as nb_commandes,
          COALESCE(CAST(SUM(total) as REAL), 0.0) as ca_total,
          COALESCE(CAST(AVG(total) as REAL), 0.0) as panier_moyen
        FROM commandes
        WHERE date BETWEEN ? AND ?
      ''', [
        _dateDebut.subtract(Duration(days: 7)).toIso8601String(),
        _dateFin.subtract(Duration(days: 7)).toIso8601String()
      ]);

      // Ventes journalières avec CAST
      final ventesJournalieres = await db.rawQuery('''
        SELECT date, COALESCE(CAST(SUM(total) as REAL), 0.0) as total
        FROM commandes
        WHERE date BETWEEN ? AND ?
        GROUP BY date
        ORDER BY date
      ''', [_dateDebut.toIso8601String(), _dateFin.toIso8601String()]);

      // Reste des requêtes avec conversions sécurisées
      final topProduits = await db.rawQuery('''
        SELECT 
          p.nom,
          COUNT(cp.id) as nb_ventes
        FROM produits p
        JOIN commande_produits cp ON p.id = cp.produitId
        JOIN commandes c ON cp.commandeId = c.id
        WHERE c.date BETWEEN ? AND ?
        GROUP BY p.id, p.nom
        ORDER BY nb_ventes DESC
        LIMIT 5
      ''', [_dateDebut.toIso8601String(), _dateFin.toIso8601String()]);

      final paiements = await db.rawQuery('''
        SELECT 
          moyenPaiement,
          COUNT(*) as nb_paiements,
          COALESCE(CAST(SUM(montant) as REAL), 0.0) as montant_total
        FROM paiements
        JOIN commandes c ON paiements.commandeId = c.id
        WHERE c.date BETWEEN ? AND ?
        GROUP BY moyenPaiement
      ''', [_dateDebut.toIso8601String(), _dateFin.toIso8601String()]);

      // Ajout du chargement des statuts de stock
      final stockStats = await Future.wait([
        db.rawQuery('''
          SELECT COUNT(*) as count 
          FROM produits 
          WHERE stock = 0 AND actif = 1
        '''),
        db.rawQuery('''
          SELECT COUNT(*) as count 
          FROM produits 
          WHERE stock <= seuilAlerte AND stock > 0 AND actif = 1
        '''),
        db.rawQuery('''
          SELECT COUNT(*) as count 
          FROM produits 
          WHERE stock > seuilAlerte AND actif = 1
        '''),
      ]);

      if (mounted) {
        setState(() {
          // Conversion sécurisée des valeurs
          final currentCA = _safeParseDouble(currentPeriod.first['ca_total']);
          final previousCA = _safeParseDouble(previousPeriod.first['ca_total']);
          final currentCmd = _safeParseInt(currentPeriod.first['nb_commandes']);
          final previousCmd =
              _safeParseInt(previousPeriod.first['nb_commandes']);
          final currentPanier =
              _safeParseDouble(currentPeriod.first['panier_moyen']);
          final previousPanier =
              _safeParseDouble(previousPeriod.first['panier_moyen']);

          _stats = {
            'chiffreAffaires': currentCA,
            'pourcentageCA': _calculatePercentage(currentCA, previousCA),
            'nombreCommandes': currentCmd,
            'pourcentageCommandes': _calculatePercentage(
                currentCmd.toDouble(), previousCmd.toDouble()),
            'panierMoyen': currentPanier,
            'pourcentagePanier':
                _calculatePercentage(currentPanier, previousPanier),
          };

          // Conversion sécurisée pour le graphique
          _ventesData = ventesJournalieres.asMap().entries.map((e) {
            return FlSpot(
              e.key.toDouble(),
              _safeParseDouble(e.value['total']),
            );
          }).toList();

          _topProduits = topProduits;
          _paiements = paiements;

          // Mise à jour du statut du stock
          _stockStatus = {
            'Rupture': _safeParseInt(stockStats[0].first['count']),
            'Stock bas': _safeParseInt(stockStats[1].first['count']),
            'Stock normal': _safeParseInt(stockStats[2].first['count']),
          };
        });
      }
    } catch (e, stack) {
      print('Erreur lors du chargement des données: $e');
      print('Stack trace: $stack');
      _setDefaultValues();
    }
  }

  // Méthodes utilitaires pour la conversion sécurisée
  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _setDefaultValues() {
    if (!mounted) return;
    setState(() {
      _stats = {
        'chiffreAffaires': 0.0,
        'pourcentageCA': 0.0,
        'nombreCommandes': 0,
        'pourcentageCommandes': 0.0,
        'panierMoyen': 0.0,
        'pourcentagePanier': 0.0,
      };
      _ventesData = [FlSpot(0, 0)];
      _topProduits = [];
      _paiements = [];
      // Ajout des valeurs par défaut pour le stock
      _stockStatus = {
        'Rupture': 0,
        'Stock bas': 0,
        'Stock normal': 0,
      };
    });
  }

  double _calculatePercentage(double current, double previous) {
    if (previous == 0) return 0;
    return ((current - previous) / previous * 100);
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _dateDebut,
        end: _dateFin,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: Colors.blue,
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateDebut = picked.start;
        _dateFin = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _generateAndOpenPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
                'Rapport du ${_formatDate(_dateDebut)} au ${_formatDate(_dateFin)}'),
          ),
          pw.SizedBox(height: 20),
          // Statistiques principales
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfStatBox('Chiffre d\'affaires',
                  '€${_stats['chiffreAffaires'].toStringAsFixed(2)}'),
              _buildPdfStatBox('Commandes', '${_stats['nombreCommandes']}'),
              _buildPdfStatBox('Panier moyen',
                  '€${_stats['panierMoyen'].toStringAsFixed(2)}'),
            ],
          ),
          pw.SizedBox(height: 20),
          // Top produits
          pw.Header(level: 1, text: 'Top 5 produits'),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: ['Produit', 'Ventes']
                    .map((e) => pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(e,
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ))
                    .toList(),
              ),
              ..._topProduits.map(
                (p) => pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(p['nom'])),
                    pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('${p['nb_ventes']}')),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Moyens de paiement
          pw.Header(level: 1, text: 'Moyens de paiement'),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: ['Méthode', 'Nombre', 'Montant']
                    .map((e) => pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(e,
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ))
                    .toList(),
              ),
              ..._paiements.map(
                (p) => pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(p['moyenPaiement'])),
                    pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('${p['nb_paiements']}')),
                    pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '€${p['montant_total'].toStringAsFixed(2)}')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/rapport_${DateTime.now().millisecondsSinceEpoch}.pdf');

    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  Future<void> _generateAndOpenExcel() async {
    var excel = Excel.createExcel();

    // Feuille Statistiques
    var statsSheet = excel['Statistiques'];
    statsSheet.appendRow([
      TextCellValue('Période'),
      TextCellValue('${_formatDate(_dateDebut)} au ${_formatDate(_dateFin)}')
    ]);
    statsSheet.appendRow([TextCellValue('')]);
    statsSheet.appendRow([
      TextCellValue('Métrique'),
      TextCellValue('Valeur'),
      TextCellValue('Variation')
    ]);
    statsSheet.appendRow([
      TextCellValue('Chiffre d\'affaires'),
      TextCellValue(_stats['chiffreAffaires'].toStringAsFixed(2)),
      TextCellValue('${_stats['pourcentageCA'].toStringAsFixed(1)}%')
    ]);
    statsSheet.appendRow([
      TextCellValue('Nombre de commandes'),
      TextCellValue(_stats['nombreCommandes'].toString()),
      TextCellValue('${_stats['pourcentageCommandes'].toStringAsFixed(1)}%')
    ]);
    statsSheet.appendRow([
      TextCellValue('Panier moyen'),
      TextCellValue(_stats['panierMoyen'].toStringAsFixed(2)),
      TextCellValue('${_stats['pourcentagePanier'].toStringAsFixed(1)}%')
    ]);

    // Feuille Top Produits
    var produitsSheet = excel['Top Produits'];
    produitsSheet.appendRow(
        [TextCellValue('Produit'), TextCellValue('Nombre de ventes')]);
    for (var produit in _topProduits) {
      produitsSheet.appendRow(
          [TextCellValue(produit['nom']), IntCellValue(produit['nb_ventes'])]);
    }

    // Feuille Paiements
    var paiementsSheet = excel['Paiements'];
    paiementsSheet.appendRow([
      TextCellValue('Méthode'),
      TextCellValue('Nombre'),
      TextCellValue('Montant total')
    ]);
    for (var paiement in _paiements) {
      paiementsSheet.appendRow([
        TextCellValue(paiement['moyenPaiement']),
        IntCellValue(paiement['nb_paiements']),
        DoubleCellValue(paiement['montant_total'])
      ]);
    }

    // Feuille Stock
    var stockSheet = excel['Stock'];
    stockSheet.appendRow(
        [TextCellValue('Statut'), TextCellValue('Nombre de produits')]);
    _stockStatus.forEach((status, count) {
      stockSheet.appendRow([TextCellValue(status), IntCellValue(count)]);
    });

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/rapport_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  pw.Widget _buildPdfStatBox(String title, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text('Rapports & Statistiques'),
          actions: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: Icon(Icons.calendar_today, size: 18),
              label: Text(
                '${_formatDate(_dateDebut)} - ${_formatDate(_dateFin)}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[800],
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _generateAndOpenPdf,
              icon: Icon(Icons.picture_as_pdf, size: 18),
              label: Text('PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _generateAndOpenExcel,
              icon: Icon(Icons.table_chart, size: 18),
              label: Text('Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.1),
                foregroundColor: Colors.green,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(width: 16),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cartes de statistiques
                Row(
                  children: [
                    _buildStatCard(
                      'Chiffre d\'affaires',
                      '€${_stats['chiffreAffaires'].toStringAsFixed(2)}',
                      '${_stats['pourcentageCA'].toStringAsFixed(1)}%',
                      Icons.euro,
                      Colors.blue,
                      _stats['pourcentageCA'] >= 0,
                    ),
                    SizedBox(width: 24),
                    _buildStatCard(
                      'Commandes',
                      '${_stats['nombreCommandes']}',
                      '${_stats['pourcentageCommandes'].toStringAsFixed(1)}%',
                      Icons.receipt_long,
                      Colors.green,
                      _stats['pourcentageCommandes'] >= 0,
                    ),
                    SizedBox(width: 24),
                    _buildStatCard(
                      'Panier moyen',
                      '€${_stats['panierMoyen'].toStringAsFixed(2)}',
                      '${_stats['pourcentagePanier'].toStringAsFixed(1)}%',
                      Icons.shopping_cart,
                      Colors.orange,
                      _stats['pourcentagePanier'] >= 0,
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Graphiques et stats
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Graphique des ventes
                    Expanded(
                      flex: 2,
                      child: _buildChartCard(
                        'Ventes par jour',
                        SizedBox(
                          height: 300,
                          child: LineChart(_createLineChartData()),
                        ),
                      ),
                    ),
                    SizedBox(width: 24),
                    // Colonne de droite avec les stats
                    Expanded(
                      child: Column(
                        children: [
                          _buildChartCard(
                            'Top 5 produits vendus',
                            Column(
                              children: _topProduits.map((produit) {
                                return _buildTopProductItem(
                                  produit['nom'],
                                  produit['nb_ventes'],
                                  Colors.blue,
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 24),
                          _buildChartCard(
                            'Moyens de paiement',
                            Column(
                              children: _paiements.map((paiement) {
                                return _buildPaymentMethodItem(
                                  paiement['moyenPaiement'],
                                  paiement['nb_paiements'],
                                  Colors.blue,
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 24),
                          _buildChartCard(
                            'Statut du stock',
                            Column(
                              children: _stockStatus.entries.map((entry) {
                                Color color;
                                switch (entry.key) {
                                  case 'Rupture':
                                    color = Colors.red;
                                    break;
                                  case 'Stock bas':
                                    color = Colors.orange;
                                    break;
                                  default:
                                    color = Colors.green;
                                }
                                return _buildStockStatusItem(
                                  entry.key,
                                  entry.value,
                                  color,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeButton() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(Icons.calendar_today, size: 18),
      label: Text('Cette semaine'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey[800],
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildExportButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String percentage,
    IconData icon,
    Color color,
    bool isPositive,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    percentage,
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }

  Widget _buildTopProductItem(String name, int sales, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(name),
          ),
          Text(
            '$sales ventes',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem(String method, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(method),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${(count / 367 * 100).round()}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatusItem(String status, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(status),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count produits',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _createLineChartData() {
    if (_ventesData.isEmpty) {
      return LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [FlSpot(0, 0)],
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        ],
      );
    }

    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < _ventesData.length) {
                return Text(value.toInt().toString());
              }
              return Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text('€${value.toInt()}');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        LineChartBarData(
          spots: _ventesData,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          dotData: FlDotData(show: true),
        ),
      ],
    );
  }
}
