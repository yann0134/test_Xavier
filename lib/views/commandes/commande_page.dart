import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../widgets/cart_item.dart';
import '../../services/db_helper.dart';
import '../../services/page_state_service.dart';

class CommandePage extends StatefulWidget {
  @override
  _CommandePageState createState() => _CommandePageState();
}

class _CommandePageState extends State<CommandePage> {
  final _pageStateService = PageStateService();
  StreamSubscription? _pageSubscription;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _produits = [];
  List<Map<String, dynamic>> _panier = [];
  String? _selectedCategory;
  String _searchQuery = '';
  double _total = 0;
  double _remise = 0;

  double _remisePourcentage = 0;
  double _remiseMontant = 0;
  String? _codePromo;
  final Map<String, double> _codesPromo = {
    'BIENVENUE': 10, // 10% de remise
    'ETE2024': 5, // 5% de remise
    'VIP20': 20, // 20% de remise
  };

  double get _totalAvecRemises {
    double total = _total;
    total -= _remiseMontant;
    total = total * (1 - _remisePourcentage / 100);
    return total > 0 ? total : 0;
  }

  Database? _db;

  @override
  void initState() {
    super.initState();
    _pageSubscription = _pageStateService.pageStream.listen((index) {
      if (index == 1) {
        // 1 est l'index de la page commande
        _resetPanier();
        _initializeData();
      }
    });
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _initDatabase();
  }

  @override
  void dispose() {
    _pageSubscription?.cancel();
    super.dispose();
  }

  void _resetPanier() {
    setState(() {
      _panier.clear();
      _total = 0;
      _remiseMontant = 0;
      _remisePourcentage = 0;
      _codePromo = null;
    });
  }

  Future<void> _initDatabase() async {
    _db = await DBHelper
        .database; // Utiliser le getter statique à la place de getDatabase
    await _loadCategories();
    await _loadProduits();
  }

  Future<void> _loadCategories() async {
    try {
      if (_db == null) return;

      final categories = await _db!.query('categories');
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
    }
  }

  Future<void> _loadProduits({String? categoryId}) async {
    try {
      if (_db == null) return;

      List<Map<String, dynamic>> produits;

      if (_searchQuery.isNotEmpty) {
        produits = await _db!.query(
          'produits',
          where: 'nom LIKE ? AND actif = 1',
          whereArgs: ['%$_searchQuery%'],
        );
      } else if (categoryId != null) {
        produits = await _db!.query(
          'produits',
          where: 'categorieId = ? AND actif = 1',
          whereArgs: [categoryId],
        );
      } else {
        produits = await _db!.query(
          'produits',
          where: 'actif = 1',
        );
      }

      if (mounted) {
        setState(() {
          _produits = produits;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des produits: $e');
    }
  }

  void _addToPanier(Map<String, dynamic> produit) {
    setState(() {
      final index = _panier.indexWhere((item) => item['id'] == produit['id']);
      if (index >= 0) {
        _panier[index]['quantite'] = (_panier[index]['quantite'] ?? 1) + 1;
      } else {
        _panier.add({...produit, 'quantite': 1});
      }
      _updateTotal();
    });
  }

  void _removeFromPanier(int productId, {bool all = false}) {
    setState(() {
      final index = _panier.indexWhere((item) => item['id'] == productId);
      if (index >= 0) {
        if (all || _panier[index]['quantite'] <= 1) {
          _panier.removeAt(index);
        } else {
          _panier[index]['quantite']--;
        }
        _updateTotal();
      }
    });
  }

  void _updateTotal() {
    double total = 0;
    for (var item in _panier) {
      total += (item['prix'] as double) * (item['quantite'] as int);
    }
    setState(() {
      _total = total * (1 - _remise / 100);
    });
  }

  void _showRemiseDialog() {
    TextEditingController montantController = TextEditingController();
    TextEditingController pourcentageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter une remise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montantController,
              decoration: InputDecoration(
                labelText: 'Montant (€)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: pourcentageController,
              decoration: InputDecoration(
                labelText: 'Pourcentage (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _remiseMontant = double.tryParse(montantController.text) ?? 0;
                _remisePourcentage =
                    double.tryParse(pourcentageController.text) ?? 0;
              });
              Navigator.pop(context);
            },
            child: Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _showCodePromoDialog() {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Code Promo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Code promo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            SizedBox(height: 8),
            Text(
              'Codes valides: ${_codesPromo.keys.join(", ")}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.toUpperCase();
              if (_codesPromo.containsKey(code)) {
                setState(() {
                  _codePromo = code;
                  _remisePourcentage = _codesPromo[code]!;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Code promo appliqué: $_remisePourcentage% de remise'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Code promo invalide'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _removeRemise() {
    setState(() {
      _remiseMontant = 0;
      _remisePourcentage = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Remise supprimée'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeCodePromo() {
    setState(() {
      _codePromo = null;
      _remisePourcentage = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code promo retiré'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _validerCommande() async {
    if (_panier.isEmpty) return;

    try {
      if (_db == null) return;

      await _db!.transaction((txn) async {
        final commandeId = await txn.insert('commandes', {
          'date': DateTime.now().toIso8601String(),
          'total': _totalAvecRemises,
          'statut': 'en_cours',
          'remise_montant': _remiseMontant,
          'remise_pourcentage': _remisePourcentage,
          'code_promo': _codePromo,
        });

        for (var item in _panier) {
          await txn.insert('commande_produits', {
            'commandeId': commandeId,
            'produitId': item['id'],
            'quantite': item['quantite'],
            'prixUnitaire': item['prix'],
          });

          await txn.rawUpdate('''
            UPDATE produits 
            SET stock = stock - ? 
            WHERE id = ?
          ''', [item['quantite'], item['id']]);
        }
      });

      setState(() {
        _panier.clear();
        _total = 0;
        _remiseMontant = 0;
        _remisePourcentage = 0;
        _codePromo = null;
      });

      // Recharger les produits pour mettre à jour les stocks affichés
      await _loadProduits(categoryId: _selectedCategory);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande validée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la validation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text('Nouvelle Commande'),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Rechercher un produit, code-barres...',
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _loadProduits(categoryId: _selectedCategory);
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        height: 48,
                        margin: EdgeInsets.only(bottom: 24),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _categories
                              .map((category) => _buildCategoryChip(category))
                              .toList(),
                        ),
                      ),
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: GridView.builder(
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _produits.length,
                              itemBuilder: (context, index) =>
                                  _buildProductCard(_produits[index]),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 320,
                margin: EdgeInsets.only(top: 24, right: 24, bottom: 24),
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
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.grey[700]),
                          SizedBox(width: 12),
                          Text(
                            'Panier',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: _panier.length,
                        itemBuilder: (context, index) {
                          final item = _panier[index];
                          return CartItem(
                            nom: item['nom'],
                            quantite: item['quantite'],
                            prix: item['prix'],
                            onAdd: () => _addToPanier(item),
                            onRemove: () => _removeFromPanier(item['id']),
                            onDelete: () =>
                                _removeFromPanier(item['id'], all: true),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: Offset(0, -2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sous-total'),
                              Text(
                                '€${_total.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Remise'),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline),
                                    onPressed: _showRemiseDialog,
                                    iconSize: 18,
                                  ),
                                ],
                              ),
                              if (_remiseMontant > 0 || _remisePourcentage > 0)
                                Row(
                                  children: [
                                    Text(
                                      '${_remiseMontant > 0 ? '-€${_remiseMontant.toStringAsFixed(2)} ' : ''}'
                                      '${_remisePourcentage > 0 ? '(-${_remisePourcentage.toStringAsFixed(0)}%)' : ''}',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          size: 18, color: Colors.red),
                                      onPressed: _removeRemise,
                                      tooltip: 'Supprimer la remise',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Code promo'),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline),
                                    onPressed: _showCodePromoDialog,
                                    iconSize: 18,
                                  ),
                                ],
                              ),
                              if (_codePromo != null)
                                Row(
                                  children: [
                                    Text(
                                      '$_codePromo (-${_codesPromo[_codePromo]}%)',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          size: 18, color: Colors.red),
                                      onPressed: _removeCodePromo,
                                      tooltip: 'Retirer le code promo',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (_total != _totalAvecRemises)
                                    Text(
                                      '€${_total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    '€${_totalAvecRemises.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _validerCommande,
                            icon: Icon(Icons.check),
                            label: Text('Valider la commande'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 48),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _panier.clear();
                                _total = 0;
                              });
                            },
                            icon: Icon(Icons.delete_outline),
                            label: Text('Annuler / Vider panier'),
                            style: TextButton.styleFrom(
                              minimumSize: Size(double.infinity, 40),
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(Map<String, dynamic> category) {
    final isSelected = _selectedCategory == category['id'].toString();
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          category['nom'],
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = selected ? category['id'].toString() : null;
            _loadProduits(categoryId: _selectedCategory);
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.blue,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> produit) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _addToPanier(produit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fastfood, size: 32, color: Colors.grey[700]),
              SizedBox(height: 12),
              Text(
                produit['nom'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                '€${(produit['prix'] as double).toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (produit['stock'] != null) ...[
                SizedBox(height: 4),
                Text(
                  'Stock: ${produit['stock']}',
                  style: TextStyle(
                    color: produit['stock'] <= (produit['seuilAlerte'] ?? 0)
                        ? Colors.red
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
