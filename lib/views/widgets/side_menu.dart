import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scoped_model/scoped_model.dart';
import '../../scoped_models/main_model.dart';
import '../../services/db_helper.dart';
import '../../services/page_state_service.dart';
import '../../localization/app_localizations.dart';
import 'dart:io';

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
                      if (model.logoPath != null)
                        Image.file(File(model.logoPath!), height: 32)
                      else
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
                      // Get translations
                      ...[
                        {'icon': Icons.home, 'key': 'home'},
                        {'icon': Icons.shopping_cart, 'key': 'orders'},
                        {'icon': Icons.history, 'key': 'history'},
                        {'icon': Icons.inventory, 'key': 'products'},
                        {'icon': Icons.bar_chart, 'key': 'reports'},
                        {'icon': Icons.settings, 'key': 'management'},
                        {'icon': Icons.settings, 'key': 'settings'},
                      ].asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return _buildMenuItem(
                          context: context,
                          icon: item['icon'] as IconData,
                          title: AppLocalizations.of(context)
                              .translate(item['key'] as String),
                          index: idx,
                          isSelected: model.currentIndex == idx,
                          model: model,
                        );
                      }).toList(),
                      Divider(height: 32),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.brightness_4,
                        title: 'dark_theme'.tr,
                        index: 7,
                        isSelected: model.currentIndex == 7,
                        model: model,
                      ),
                    ],
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
