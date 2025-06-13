import 'dart:async';
import 'dart:convert';

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
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;

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

      final results = await db.rawQuery('''
        SELECT 
          c.id,
          c.date,
          COALESCE(CAST(c.total as REAL), 0.0) as total,
          COALESCE(c.statut, 'En attente') as statut,
          COALESCE(p.moyenPaiement, 'Non spécifié') as moyenPaiement,
          COALESCE(c.remise_montant, 0.0) as remise_montant,
          cl.nom as client_nom
        FROM commandes c
        LEFT JOIN clients cl ON c.clientId = cl.id
        LEFT JOIN paiements p ON c.id = p.commandeId
        WHERE $whereClause
        ORDER BY c.date DESC
      ''', whereArgs);

      if (!mounted) return;

      setState(() {
        _commandes = results
            .map((map) {
              try {
                return Commande.fromMap(map);
              } catch (e) {
                print('Erreur de conversion pour la commande ${map['id']}: $e');
                return null;
              }
            })
            .where((cmd) => cmd != null)
            .cast<Commande>()
            .toList();

        _totalVentes = _commandes.fold(
          0.0,
          (sum, cmd) => sum + cmd.montant,
        );

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

      //  Navigator.pop(context); // Fermer le modal
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

  void _showReceipt(Commande commande) async {
    try {
      final db = await DBHelper.database;

      // Utilisation de GROUP_CONCAT pour compatibilité maximale
      final commandeDetails = await db.rawQuery('''
        SELECT 
          c.*,
          cl.nom as client_nom,
          cl.telephone,
          cl.email,
          GROUP_CONCAT(
            json_object(
              'nom', p.nom,
              'quantite', cp.quantite,
              'prix', cp.prixUnitaire
            )
          ) as items
        FROM commandes c
        LEFT JOIN clients cl ON c.clientId = cl.id
        LEFT JOIN commande_produits cp ON c.id = cp.commandeId
        LEFT JOIN produits p ON cp.produitId = p.id
        WHERE c.id = ?
        GROUP BY c.id
      ''', [int.parse(commande.numero.replaceAll(RegExp(r'[^\d]'), ''))]);

      if (!mounted) return;

      if (commandeDetails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de charger le reçu')),
        );
        return;
      }

      final details = commandeDetails.first;
      List<Map<String, dynamic>> items = [];

      if (details['items'] != null && (details['items'] as String).isNotEmpty) {
        try {
          // On entoure la chaîne concaténée de crochets pour former un tableau JSON valide
          final itemsJson = '[${details['items']}]';
          items = List<Map<String, dynamic>>.from(jsonDecode(itemsJson)
              .map((item) => Map<String, dynamic>.from(item)));
          print("items = $items");
        } catch (e) {
          print('Erreur de décodage JSON: $e');
          items = [];
        }
      }

      final commandeComplete = {
        ...details,
        'items': items,
      };

      showDialog(
        context: context,
        builder: (context) => ReceiptView(
          commande: Commande.fromMap(commandeComplete),
          onPay: () async {
            await _updateCommandeStatus(commande.numero, 'Payée');
          },
        ),
      );
    } catch (e) {
      print('Erreur lors du chargement du reçu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du reçu'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  color: _getPaymentColor(commande.typePaiement),
                ),
                SizedBox(width: 8),
                Text(
                  commande.typePaiement,
                  style: TextStyle(
                    color: _getPaymentColor(commande.typePaiement),
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onSelected: (value) async {
              switch (value) {
                case 'receipt':
                  _showReceipt(commande);
                  break;
                case 'pay':
                  await _showPaiementModal(commande);
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
              if (commande.status == 'en_cours') ...[
                PopupMenuItem<String>(
                  value: 'pay',
                  child: ListTile(
                    leading: Icon(Icons.payment, color: Colors.green),
                    title: Text('Payer la commande'),
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

  Future<void> _showPaiementModal(Commande commande) async {
    String? selectedType;
    final List<Map<String, dynamic>> typesPaiement = [
      {
        'type': 'Carte',
        'icon': Icons.credit_card,
        'color': Colors.blue,
      },
      {
        'type': 'Espèces',
        'icon': Icons.money,
        'color': Colors.green,
      },
      {
        'type': 'Mobile Money',
        'icon': Icons.phone_android,
        'color': Colors.orange,
      },
      {
        'type': 'Chèque',
        'icon': Icons.account_balance_wallet,
        'color': Colors.purple,
      },
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 400,
            padding: EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setStateDialog) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paiement de la commande',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(height: 32),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_outlined, color: Colors.blue),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Montant à payer',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                            Text(
                              '€${commande.montant.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Mode de paiement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: typesPaiement.map((type) {
                      bool isSelected = selectedType == type['type'];
                      return InkWell(
                        onTap: () {
                          setStateDialog(() => selectedType = type['type']);
                        },
                        child: Container(
                          width: 170,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type['color'].withOpacity(0.1)
                                : Colors.grey.shade50,
                            border: Border.all(
                              color: isSelected
                                  ? type['color']
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                type['icon'],
                                color: isSelected
                                    ? type['color']
                                    : Colors.grey.shade600,
                              ),
                              SizedBox(width: 12),
                              Text(
                                type['type'],
                                style: TextStyle(
                                  color: isSelected
                                      ? type['color']
                                      : Colors.grey.shade800,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text('Annuler'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check),
                            SizedBox(width: 8),
                            Text('Valider le paiement'),
                          ],
                        ),
                        onPressed: selectedType == null
                            ? null
                            : () async {
                                await _validerPaiementCommande(
                                    commande, selectedType!);
                                Navigator.pop(context);
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _validerPaiementCommande(
      Commande commande, String typePaiement) async {
    try {
      final db = await DBHelper.database;
      final id = int.parse(commande.numero.replaceAll(RegExp(r'[^\d]'), ''));

      await db.transaction((txn) async {
        // 1. Mettre à jour le statut de la commande
        await txn.update(
          'commandes',
          {'statut': 'Payée'},
          where: 'id = ?',
          whereArgs: [id],
        );

        // 2. Gérer le paiement
        final existing = await txn.query(
          'paiements',
          where: 'commandeId = ?',
          whereArgs: [id],
        );

        if (existing.isEmpty) {
          // Insérer nouveau paiement avec montant
          await txn.insert('paiements', {
            'commandeId': id,
            'moyenPaiement': typePaiement,
            'montant': commande.montant,
            'date': DateTime.now().toIso8601String(),
          });
        } else {
          // Mettre à jour le paiement existant
          await txn.update(
            'paiements',
            {
              'moyenPaiement': typePaiement,
              'montant': commande.montant,
              'date': DateTime.now().toIso8601String(),
            },
            where: 'commandeId = ?',
            whereArgs: [id],
          );
        }
      });

      await _loadCommandes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande payée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Erreur lors du paiement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du paiement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getPaymentColor(String type) {
    switch (type.toLowerCase()) {
      case 'carte':
        return Colors.blue;
      case 'espèces':
        return Colors.brown;
      case 'mobile money':
        return Colors.orange;
      case 'chèque':
        return Colors.purple;
      default:
        return Colors.grey;
    }
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
    switch (status.toLowerCase()) {
      case 'payée':
        return Colors.green;
      case 'en attente':
        return Colors.orange;
      case 'annulée':
        return Colors.red;
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

  void _showDateRangePicker() async {
    DateTimeRange? tempRange = _dateDebut != null && _dateFin != null
        ? DateTimeRange(start: _dateDebut!, end: _dateFin!)
        : null;

    await showDialog(
      context: context,
      builder: (context) {
        DateTimeRange? selectedRange = tempRange;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: EdgeInsets.all(24),
            width: 400,
            child: StatefulBuilder(
              builder: (context, setStateDialog) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Filtrer par période',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 320,
                    child: CalendarDateRangePicker(
                      initialRange: selectedRange,
                      onChanged: (range) {
                        setStateDialog(() {
                          selectedRange = range;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text('Annuler'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        child: Text('Réinitialiser'),
                        onPressed: () {
                          setState(() {
                            _dateDebut = null;
                            _dateFin = null;
                          });
                          Navigator.of(context).pop();
                          _loadCommandes();
                        },
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        child: Text('Valider'),
                        onPressed: selectedRange == null
                            ? null
                            : () {
                                setState(() {
                                  _dateDebut = selectedRange!.start;
                                  _dateFin = selectedRange!.end;
                                });
                                Navigator.of(context).pop();
                                _loadCommandes();
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CalendarDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialRange;
  final ValueChanged<DateTimeRange?> onChanged;

  const CalendarDateRangePicker({
    Key? key,
    this.initialRange,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<CalendarDateRangePicker> createState() =>
      _CalendarDateRangePickerState();
}

class _CalendarDateRangePickerState extends State<CalendarDateRangePicker> {
  dp.DatePeriod? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    if (widget.initialRange != null) {
      _selectedPeriod = dp.DatePeriod(
        widget.initialRange!.start,
        widget.initialRange!.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = now;

    return dp.RangePicker(
      selectedPeriod:
          _selectedPeriod ?? dp.DatePeriod(DateTime.now(), DateTime.now()),
      onChanged: (dp.DatePeriod period) {
        setState(() {
          _selectedPeriod = period;
        });
        widget.onChanged(DateTimeRange(start: period.start, end: period.end));
      },
      firstDate: firstDate,
      lastDate: lastDate,
      datePickerStyles: dp.DatePickerRangeStyles(
        selectedPeriodLastDecoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(10.0),
            bottomRight: Radius.circular(10.0),
          ),
        ),
        selectedPeriodStartDecoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10.0),
            bottomLeft: Radius.circular(10.0),
          ),
        ),
        selectedPeriodMiddleDecoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          shape: BoxShape.rectangle,
        ),
      ),
      datePickerLayoutSettings: dp.DatePickerLayoutSettings(
        showPrevMonthEnd: true,
        showNextMonthStart: true,
      ),
      selectableDayPredicate: (date) => true,
    );
  }
}
