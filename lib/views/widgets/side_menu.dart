import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import '../../scoped_models/main_model.dart';
import '../../services/db_helper.dart';
import '../../services/page_state_service.dart';

class SideMenu extends StatelessWidget {
  final _pageStateService = PageStateService();

  // Fonction pour rafraîchir les données selon la page
  Future<void> _refreshPageData(BuildContext context, int index) async {
    try {
      final db = await DBHelper.database;

      switch (index) {
        case 0: // Accueil
          // Notification pour rafraîchir la page d'accueil
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Actualisation du tableau de bord...'),
              duration: Duration(seconds: 1),
            ),
          );
          break;

        case 1: // Commande
          // Rafraîchir les catégories et produits
          await db.rawQuery('SELECT * FROM categories');
          await db.rawQuery('SELECT * FROM produits WHERE actif = 1');
          break;

        case 2: // Historique
          // Rafraîchir l'historique des commandes
          await db.rawQuery('''
            SELECT c.*, cl.nom as client_nom, p.moyenPaiement
            FROM commandes c
            LEFT JOIN clients cl ON c.clientId = cl.id
            LEFT JOIN paiements p ON c.id = p.commandeId
            ORDER BY c.date DESC
          ''');
          break;

        case 3: // Produits / Stock
          // Rafraîchir les produits et leur stock
          await db.rawQuery('''
            SELECT p.*, c.nom as categorie_nom 
            FROM produits p 
            LEFT JOIN categories c ON p.categorieId = c.id 
            WHERE p.actif = 1
          ''');
          break;

        case 4: // Rapports
          // Rafraîchir les données des rapports
          final today = DateTime.now().toIso8601String().split('T')[0];
          await db.rawQuery('''
            SELECT COUNT(*) as count, SUM(total) as total
            FROM commandes 
            WHERE date = ?
          ''', [today]);
          break;

        case 5: // Gestion
          // Rafraîchir les données de gestion
          await db.rawQuery('SELECT * FROM categories');
          await db.rawQuery('SELECT * FROM parametres');
          break;
      }

      // Notification de succès
      if (index > 0) {
        // Ne pas montrer pour l'accueil qui a sa propre notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Données actualisées'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du rafraîchissement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'actualisation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<MainModel>(
      builder: (context, child, model) {
        return SizedBox(
          width: 250,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    children: [
                      Image.asset('assets/images/logo.png', height: 32),
                      SizedBox(width: 12),
                      Text(
                        'CaissePro',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem(
                        context: context,
                        icon: Icons.home,
                        title: 'Accueil',
                        index: 0,
                        isSelected: model.currentIndex == 0,
                        model: model,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.shopping_cart,
                        title: 'Commande',
                        index: 1,
                        isSelected: model.currentIndex == 1,
                        model: model,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.history,
                        title: 'Historique',
                        index: 2,
                        isSelected: model.currentIndex == 2,
                        model: model,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.inventory,
                        title: 'Produits / Stock',
                        index: 3,
                        isSelected: model.currentIndex == 3,
                        model: model,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.bar_chart,
                        title: 'Rapports',
                        index: 4,
                        isSelected: model.currentIndex == 4,
                        model: model,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.settings,
                        title: 'Gestion',
                        index: 5,
                        isSelected: model.currentIndex == 5,
                        model: model,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.settings,
                        title: 'Paramètres',
                        index: 6,
                        isSelected: model.currentIndex == 6,
                        model: model,
                      ),
                      Divider(height: 32),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.brightness_4,
                        title: 'Mode sombre',
                        index: 7,
                        isSelected: model.currentIndex == 7,
                        model: model,
                      ),
                    ],
                  ),
                ),
                // Ajouter le bouton IA en bas
                Container(
                  padding: EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () {
                      model.setIndex(7); // Nouvel index pour la page IA
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Assistant IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        );
      },
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required bool isSelected,
    required MainModel model,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey[700],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () {
          model.setIndex(index);
          _pageStateService.refreshPage(index); // Déclenche l'initialisation
        },
      ),
    );
  }
}
