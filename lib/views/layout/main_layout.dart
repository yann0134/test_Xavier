import 'package:caissepro/views/accueil/home_page.dart';
import 'package:caissepro/views/caisse_ia/caisse_ia_page.dart';
import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import '../widgets/side_menu.dart';
import '../commandes/commande_page.dart';
import '../../scoped_models/main_model.dart';
import '../historique/historique_page.dart';
import '../produits/produits_page.dart';
import '../rapports/rapport_page.dart';
import '../parametres/settings_page.dart';
import '../gestion/gestion_page.dart';

class MainLayout extends StatefulWidget {
  final int selectedIndex;

  MainLayout({this.selectedIndex = 0});

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  bool _isExtended = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isExtended = true),
            onExit: (_) => setState(() => _isExtended = false),
            child: NavigationRail(
              selectedIndex: _currentIndex,
              extended: _isExtended,
              minExtendedWidth: 180,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: Icon(_isExtended ? Icons.menu_open : Icons.menu),
                  onPressed: () => setState(() => _isExtended = !_isExtended),
                ),
              ),
              onDestinationSelected: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Accueil'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: Text('Caisse'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('Historique'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Produits'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Rapports'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_cart_outlined),
                  selectedIcon: Icon(Icons.shopping_cart),
                  label: Text('Gestion'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Paramètres'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy),
                  label: Text('Assistant IA'),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                HomePage(),
                CommandePage(),
                HistoriquePage(),
                ProduitsPage(),
                RapportPage(),
                GestionPage(),
                SettingsPage(),
                CaisseIAPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
