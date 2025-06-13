import 'dart:async';

import 'package:caissepro/services/auth_service.dart';
import 'package:caissepro/services/db_helper.dart';
import 'package:flutter/material.dart';
import '../widgets/side_menu.dart';
import '../widgets/stats_card.dart';
import '../widgets/order_list_item.dart';
import '../widgets/low_stock_notification.dart';
import '../stock/low_stock_page.dart';
import 'package:fl_chart/fl_chart.dart';
import '../commandes/commande_page.dart';
import '../factures/receipt_modal.dart';
import '../paiements/paiement_rapide_modal.dart';
import '../../services/page_state_service.dart';
import '../../scoped_models/main_model.dart';
import 'package:scoped_model/scoped_model.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _dbHelper = DBHelper();
  final _pageStateService = PageStateService();
  StreamSubscription? _pageSubscription;

  double _totalVentesJour = 0;
  int _nombreCommandes = 0;
  int _stockBasCount = 0;
  List<Map<String, dynamic>> _dernieresCommandes = [];
  List<FlSpot> _ventesData = [];
  late AnimationController _alertController;
  late Animation<Offset> _alertAnimation;
  bool _showStockAlert = false;

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _alertAnimation =
        Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _alertController, curve: Curves.easeOut),
    );
    _pageSubscription = _pageStateService.pageStream.listen((index) {
      if (index == 0) {
        // 0 est l'index de la page d'accueil
        _initializeData();
      }
    });
    _initializeData(); // Initialisation au démarrage
  }

  Future<void> _initializeDatabase() async {
    try {
      await DBHelper.database;
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  Future<void> _initializeData() async {
    await _loadData();
    // Autres initialisations nécessaires...
  }

  Future<void> _loadData() async {
    try {
      final db = await DBHelper.database;

      // Modification de la requête des ventes du jour pour prendre en compte la date correctement
      final today = DateTime.now().toIso8601String().split('T')[0];
      final ventesJour = await db.rawQuery('''
        SELECT 
          COALESCE(CAST(SUM(total) as REAL), 0.0) as total, 
          COUNT(*) as count_today,
          (SELECT COUNT(*) FROM commandes) as total_commandes
        FROM commandes 
        WHERE date LIKE ?
      ''', ['$today%']); // Utilisation de LIKE pour matcher toute la journée

      print('Résultats ventes jour: $ventesJour'); // Debug

      // Charger le nombre de produits en stock bas
      final stockBas = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM produits 
        WHERE stock <= seuilAlerte
      ''');

      // Charger les dernières commandes
      final commandes = await db.rawQuery('''
        SELECT c.id, c.date, CAST(c.total as REAL) as total, cl.nom as client_nom
        FROM commandes c
        LEFT JOIN clients cl ON c.clientId = cl.id
        ORDER BY c.date DESC LIMIT 5
      ''');

      // Charger les données des ventes sur 7 jours
      final ventesHebdo = await db.rawQuery('''
        SELECT date, COALESCE(CAST(SUM(total) as REAL), 0.0) as total
        FROM commandes
        WHERE date >= date('now', '-7 days')
        GROUP BY date
        ORDER BY date
      ''');

      if (!mounted) return;

      setState(() {
        // Vérification explicite des valeurs
        final totalVentes = ventesJour.first['total'];
        _totalVentesJour = totalVentes == null
            ? 0.0
            : totalVentes is int
                ? totalVentes.toDouble()
                : totalVentes is double
                    ? totalVentes
                    : double.tryParse(totalVentes.toString()) ?? 0.0;

        print('Total ventes jour: $_totalVentesJour'); // Debug

        _nombreCommandes = _safeParseInt(ventesJour.first[
            'total_commandes']); // Mise à jour avec le total des commandes
        _stockBasCount = _safeParseInt(stockBas.first['count']);
        _dernieresCommandes = commandes;

        // Conversion sécurisée pour les données du graphique
        _ventesData = ventesHebdo.asMap().entries.map((entry) {
          return FlSpot(
            entry.key.toDouble(),
            _safeParseDouble(entry.value['total']),
          );
        }).toList();

        if (_ventesData.isEmpty) {
          _ventesData = [FlSpot(0, 0)];
        }
        if (_stockBasCount > 0) {
          _showStockAlert = true;
          _alertController.forward(from: 0);
        }
      });
    } catch (e, stackTrace) {
      print('Erreur lors du chargement des données: $e');
      print('Stack trace: $stackTrace');
      _setDefaultValues();
    }
  }

  // Méthodes utilitaires pour la conversion sécurisée des types
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
      _totalVentesJour = 0.0;
      _nombreCommandes = 0;
      _stockBasCount = 0;
      _dernieresCommandes = [];
      _ventesData = [FlSpot(0, 0)];
    });
  }

  Future<void> _showPaiementRapideModal() async {
    final db = await DBHelper.database;
    final commandesEnCours = await db.rawQuery('''
      SELECT c.*, cl.nom as client_nom 
      FROM commandes c
      LEFT JOIN clients cl ON c.clientId = cl.id
      WHERE c.statut = 'en_cours'
      ORDER BY c.date DESC
    ''');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => PaiementRapideModal(commandes: commandesEnCours),
    );
  }

  Future<void> _showDernierRecu() async {
    final db = await DBHelper.database;
    final derniereCommande = await db.rawQuery('''
      SELECT c.*, cl.nom as client_nom, cl.telephone, cl.email,
             GROUP_CONCAT(cp.quantite || 'x ' || p.nom || ' @ ' || cp.prixUnitaire) as items
      FROM commandes c
      LEFT JOIN clients cl ON c.clientId = cl.id
      LEFT JOIN commande_produits cp ON c.id = cp.commandeId
      LEFT JOIN produits p ON cp.produitId = p.id
      WHERE c.statut = 'payée'
      GROUP BY c.id
      ORDER BY c.date DESC
      LIMIT 1
    ''');

    if (derniereCommande.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune facture disponible')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ReceiptModal(commande: derniereCommande.first),
    );
  }

  void _goToNewCommande(BuildContext context) {
    // Récupérer le MainModel
    final model = ScopedModel.of<MainModel>(context);
    // Changer l'index pour aller à la page commande
    model.setIndex(1);
    // Notifier le changement de page
    _pageStateService.refreshPage(1);
  }

  void _openStockPage() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LowStockPage()));
  }

  Future<Map<String, dynamic>> _getCurrentUser() async {
    return await AuthService().getCurrentUser();
  }

  void _handleLogout() async {
    await AuthService().logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
              children: [
                AppBar(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  actions: [
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.warning_amber_outlined,
                              color: Colors.orange),
                          onPressed: _openStockPage,
                        ),
                        if (_stockBasCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints:
                                  const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$_stockBasCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getCurrentUser(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return SizedBox();

                        return Row(
                          children: [
                            Text(
                              snapshot.data?['name'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            PopupMenuButton(
                              icon: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.blue.shade800,
                                child: Text(
                                  (snapshot.data?['name'] as String?)
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      'U',
                                ),
                              ),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: ListTile(
                                    leading: Icon(Icons.logout),
                                    title: Text('Déconnexion'),
                                  ),
                                  onTap: _handleLogout,
                                ),
                              ],
                            ),
                            SizedBox(width: 16),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 24),
                            child: Row(
                              children: [
                                _buildStatsCardWrapper(
                                  child: StatsCard(
                                    title: 'Ventes du jour',
                                    value:
                                        '€${_totalVentesJour.toStringAsFixed(2)}',
                                    icon: Icons.euro,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(width: 24),
                                _buildStatsCardWrapper(
                                  child: StatsCard(
                                    title: 'Commandes',
                                    value: _nombreCommandes.toString(),
                                    icon: Icons.receipt_long,
                                    color: Colors.blue,
                                    subtitle:
                                        'Total des commandes', // Ajout d'un sous-titre explicatif
                                  ),
                                ),
                                SizedBox(width: 24),
                                _buildStatsCardWrapper(
                                  child: StatsCard(
                                    title: 'Stock bas',
                                    value: '$_stockBasCount alertes',
                                    icon: Icons.warning,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(bottom: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildActionButton(
                                  'Nouvelle commande',
                                  Icons.add_shopping_cart,
                                  Colors.blue,
                                  onPressed: () => _goToNewCommande(context),
                                ),
                                SizedBox(width: 16),
                                _buildActionButton(
                                  'Paiement rapide',
                                  Icons.payment,
                                  Colors.green,
                                  onPressed: _showPaiementRapideModal,
                                ),
                                SizedBox(width: 16),
                                _buildActionButton(
                                  'Dernière facture',
                                  Icons.receipt,
                                  Colors.orange,
                                  onPressed: _showDernierRecu,
                                ),
                              ],
                            ),
                          ),
                          if (_ventesData.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(bottom: 24),
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
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ventes (7 derniers jours)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    SizedBox(height: 24),
                                    Container(
                                      height: 200,
                                      child: LineChart(
                                        LineChartData(
                                          minY: 0,
                                          gridData: FlGridData(show: true),
                                          titlesData: FlTitlesData(
                                            show: true,
                                            rightTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
                                            topTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
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
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_dernieresCommandes.isNotEmpty)
                            Container(
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
                                  Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Dernières commandes',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            // Navigation vers la page des commandes
                                          },
                                          child: Text('Voir tout'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._dernieresCommandes.map((commande) {
                                    // Formatage sécurisé de la date
                                    String formattedTime;
                                    try {
                                      final dateTime = DateTime.parse(
                                          commande['date'].toString());
                                      formattedTime =
                                          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                                    } catch (e) {
                                      formattedTime = 'N/A';
                                    }

                                    return OrderListItem(
                                      orderNumber:
                                          'CMD${commande['id'].toString().padLeft(6, '0')}',
                                      time: formattedTime,
                                      amount:
                                          (commande['total'] as num).toDouble(),
                                      clientName:
                                          commande['client_nom'] as String?,
                                    );
                                  }),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (_showStockAlert)
        Positioned(
          top: 16,
          right: 16,
          child: SlideTransition(
            position: _alertAnimation,
            child: LowStockNotification(
              count: _stockBasCount,
              onClose: () => setState(() => _showStockAlert = false),
              onTap: _openStockPage,
            ),
          ),
        ),
    ],
  ),
);
  }

  Widget _buildStatsCardWrapper({required Widget child}) {
    return Expanded(
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
        child: child,
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color,
      {required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageSubscription?.cancel();
    _alertController.dispose();
    super.dispose();
  }
}
