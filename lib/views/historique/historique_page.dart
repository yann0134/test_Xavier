import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/commande.dart';
import '../../services/db_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:excel/excel.dart' hide Border; // Fix Border conflict
import '../../services/page_state_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import '../widgets/receipt_view.dart';

class HistoriquePage extends StatefulWidget {
  @override
  _HistoriquePageState createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  final _dbHelper = DBHelper();
  List<Commande> _commandes = [];
  double _totalVentes = 0;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String? _statusFiltre;
  String _searchQuery = '';
  final _pageStateService = PageStateService();
  StreamSubscription? _pageSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageSubscription = _pageStateService.pageStream.listen((index) {
      if (index == 2) {
        // 2 est l'index de la page historique
        _initializeData();
      }
    });
    _initializeData(); // Initialisation au démarrage
  }

  Future<void> _initializeData() async {
    await _loadCommandes();
    // Autres initialisations nécessaires...
  }

  @override
  void dispose() {
    _pageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCommandes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DBHelper.database;

      // Construire la requête avec les filtres
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (_dateDebut != null) {
        whereClause += ' AND c.date >= ?';
        whereArgs.add(_dateDebut!.toIso8601String());
      }
      if (_dateFin != null) {
        whereClause += ' AND c.date <= ?';
        whereArgs.add(_dateFin!.toIso8601String());
      }
      if (_statusFiltre != null && _statusFiltre!.isNotEmpty) {
        whereClause += ' AND c.statut = ?';
        whereArgs.add(_statusFiltre);
      }
      if (_searchQuery.isNotEmpty) {
        whereClause += ' AND (c.id LIKE ? OR cl.nom LIKE ?)';
        whereArgs.addAll(['%$_searchQuery%', '%$_searchQuery%']);
      }

      // Requête modifiée pour inclure toutes les colonnes nécessaires
      final results = await db.rawQuery('''
        SELECT 
          c.id,
          c.date,
          c.total,
          c.statut,
          p.moyenPaiement,
          cl.nom as client_nom
        FROM commandes c
        LEFT JOIN clients cl ON c.clientId = cl.id
        LEFT JOIN paiements p ON c.id = p.commandeId
        WHERE $whereClause
        ORDER BY c.date DESC
      ''', whereArgs);

      print("Résultats de la requête: $results"); // Debug

      if (!mounted) return;

      setState(() {
        _commandes = results.map((map) => Commande.fromMap(map)).toList();
        _totalVentes = results.fold(
            0, (sum, item) => sum + (item['total'] as num).toDouble());
        _isLoading = false;
      });
    } catch (e, stack) {
      print('Erreur lors du chargement des commandes: $e');
      print('Stack trace: $stack');
      setState(() {
        _isLoading = false;
        _commandes = [];
        _totalVentes = 0;
      });
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final pdf = pw.Document();

      // Charger la police
      final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      final ttf = pw.Font.ttf(font);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('Historique des commandes',
                      style: pw.TextStyle(font: ttf, fontSize: 20)),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // En-têtes
                    pw.TableRow(
                      children: ['N°', 'Date', 'Montant', 'Status', 'Paiement']
                          .map((e) => pw.Container(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(e,
                                    style: pw.TextStyle(
                                        font: ttf,
                                        fontWeight: pw.FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                    // Données
                    ..._commandes.map((c) => pw.TableRow(
                          children: [
                            pw.Text(c.numero, style: pw.TextStyle(font: ttf)),
                            pw.Text(
                                '${c.date.day}/${c.date.month}/${c.date.year}',
                                style: pw.TextStyle(font: ttf)),
                            pw.Text('${c.montant.toStringAsFixed(2)} EUR',
                                style: pw.TextStyle(font: ttf)),
                            pw.Text(c.status, style: pw.TextStyle(font: ttf)),
                            pw.Text(c.typePaiement,
                                style: pw.TextStyle(font: ttf)),
                          ]
                              .map((e) => pw.Container(
                                    padding: pw.EdgeInsets.all(8),
                                    child: e,
                                  ))
                              .toList(),
                        )),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Demander où sauvegarder le fichier
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Sauvegarder le rapport PDF',
        fileName: 'historique_commandes.pdf',
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(await pdf.save());
        await OpenFile.open(outputFile);
      }
    } catch (e) {
      print('Erreur lors de la génération du PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du PDF'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Commandes'];

      // En-têtes
      sheet.appendRow(['N°', 'Date', 'Montant', 'Status', 'Paiement']
          .map((e) => TextCellValue(e))
          .toList());

      // Données
      for (var commande in _commandes) {
        sheet.appendRow([
          TextCellValue(commande.numero),
          TextCellValue(
              '${commande.date.day}/${commande.date.month}/${commande.date.year}'),
          DoubleCellValue(commande.montant),
          TextCellValue(commande.status),
          TextCellValue(commande.typePaiement),
        ]);
      }

      // Demander où sauvegarder le fichier
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Sauvegarder le fichier Excel',
        fileName: 'historique_commandes.xlsx',
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(excel.encode()!);
        await OpenFile.open(outputFile);
      }
    } catch (e) {
      print('Erreur lors de la génération Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération Excel'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _dateDebut ?? DateTime.now().subtract(Duration(days: 7)),
        end: _dateFin ?? DateTime.now(),
      ),
      saveText: 'Appliquer',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
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
      _loadCommandes();
    }
  }

  Future<void> _showStatusFilter() async {
    try {
      final db = await DBHelper.database;
      // Récupérer tous les statuts distincts
      final statuts = await db.rawQuery('''
        SELECT DISTINCT statut 
        FROM commandes 
        WHERE statut IS NOT NULL
        ORDER BY statut
      ''');

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Filtrer par status'),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Tous les statuts'),
                  selected: _statusFiltre == null,
                  onTap: () {
                    setState(() => _statusFiltre = null);
                    Navigator.pop(context);
                    _loadCommandes();
                  },
                  leading: Icon(Icons.clear_all),
                ),
                Divider(),
                ...statuts.map((status) {
                  final statusValue = status['statut'] as String;
                  return ListTile(
                    leading: Icon(_getStatusIcon(statusValue)),
                    title: Text(statusValue),
                    selected: _statusFiltre == statusValue,
                    trailing: _statusFiltre == statusValue
                        ? Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _statusFiltre = statusValue);
                      Navigator.pop(context);
                      _loadCommandes();
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Erreur lors du chargement des statuts: $e');
    }
  }

  void _showMontantFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trier par montant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Plus élevé d\'abord'),
              onTap: () {
                setState(() {
                  _commandes.sort((a, b) => b.montant.compareTo(a.montant));
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Plus bas d\'abord'),
              onTap: () {
                setState(() {
                  _commandes.sort((a, b) => a.montant.compareTo(b.montant));
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCommandeStatus(String numero, String newStatus) async {
    try {
      final db = await DBHelper.database;
      await db.update(
        'commandes',
        {'statut': newStatus},
        where: 'id = ?',
        whereArgs: [int.parse(numero.replaceAll(RegExp(r'[^\d]'), ''))],
      );

      Navigator.pop(context); // Fermer le modal
      _loadCommandes(); // Recharger les données

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status mis à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  void _showReceipt(Commande commande) {
    showDialog(
      context: context,
      builder: (context) => ReceiptView(
        commande: commande,
        onPay: () async {
          // Mettre à jour le statut de la commande
          await _updateCommandeStatus(commande.numero, 'Payée');
          Navigator.of(context).pop(); // Fermer le modal
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                title: Text('Historique des commandes'),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total des ventes avec données réelles
                      Container(
                        margin: EdgeInsets.only(bottom: 24),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.euro, color: Colors.blue),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total ventes sur la période:',
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                                Text(
                                  '€${_totalVentes.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Filtres et recherche avec callbacks
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Rechercher une commande...',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _loadCommandes();
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          _buildFilterButton('Date', Icons.calendar_today,
                              onPressed: _showDateRangePicker),
                          SizedBox(width: 8),
                          _buildFilterButton('Status', Icons.filter_list,
                              onPressed: _showStatusFilter),
                          SizedBox(width: 8),
                          _buildFilterButton('Montant', Icons.euro,
                              onPressed: _showMontantFilter),
                          SizedBox(width: 8),
                          _buildExportButton(
                              'Actualiser', Icons.refresh, Colors.blue,
                              onPressed: () {
                            _loadCommandes();
                          }),
                          Spacer(),
                          _buildExportButton(
                              'PDF', Icons.picture_as_pdf, Colors.red,
                              onPressed: _exportToPdf),
                          SizedBox(width: 8),
                          _buildExportButton(
                              'Excel', Icons.table_chart, Colors.green,
                              onPressed: _exportToExcel),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Nombre de résultats
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${_commandes.length} résultats',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Tableau des commandes avec données réelles
                      Expanded(
                        child: Container(
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
                            children: [
                              _buildTableHeader(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _commandes.length,
                                  itemBuilder: (context, index) =>
                                      _buildTableRow(_commandes[index]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement des commandes...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterButton(String label, IconData icon,
      {required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 2,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildExportButton(String label, IconData icon, Color color,
      {required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text('Commande',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child:
                  Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Montant',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Paiement',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(Commande commande) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('#${commande.numero}')),
          Expanded(
            flex: 2,
            child: Text(
                '${commande.date.hour}:${commande.date.minute.toString().padLeft(2, '0')}'),
          ),
          Expanded(
              flex: 1, child: Text('€${commande.montant.toStringAsFixed(2)}')),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Icon(
                  _getPaymentIcon(commande.typePaiement),
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Text(commande.typePaiement),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(commande.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                commande.status,
                style: TextStyle(
                  color: _getStatusColor(commande.status),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onSelected: (value) {
              switch (value) {
                case 'receipt':
                  _showReceipt(commande);
                  break;
                case 'pay':
                  _updateCommandeStatus(commande.numero, 'Payée');
                  break;
                case 'cancel':
                  _updateCommandeStatus(commande.numero, 'Annulée');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'receipt',
                child: ListTile(
                  leading: Icon(Icons.receipt_long, color: Colors.blue),
                  title: Text('Voir le reçu'),
                  dense: true,
                ),
              ),
              if (commande.status == 'En attente') ...[
                PopupMenuItem<String>(
                  value: 'pay',
                  child: ListTile(
                    leading:
                        Icon(Icons.check_circle_outline, color: Colors.green),
                    title: Text('Marquer comme payée'),
                    dense: true,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined, color: Colors.red),
                    title: Text('Annuler la commande'),
                    dense: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'Carte':
        return Icons.credit_card;
      case 'Espèces':
        return Icons.money;
      case 'Mobile Money':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Payée':
        return Colors.green;
      case 'Annulée':
        return Colors.red;
      case 'En attente':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'payée':
        return Icons.check_circle_outline;
      case 'en attente':
        return Icons.pending_outlined;
      case 'annulée':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
