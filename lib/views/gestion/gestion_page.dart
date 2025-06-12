import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/produit.dart';
import '../../services/db_helper.dart';
import '../../models/unite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class GestionPage extends StatefulWidget {
  @override
  _GestionPageState createState() => _GestionPageState();
}

class _GestionPageState extends State<GestionPage> {
  String? selectedCategorie;
  TextEditingController nomController = TextEditingController();
  TextEditingController prixController = TextEditingController();
  TextEditingController stockController = TextEditingController();
  TextEditingController seuilController = TextEditingController();
  bool actif = true;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _produits = [];
  List<Unite> _unites = [];
  Map<String, int> _produitsParCategorie = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DBHelper.database;

      // Modification de la requête pour les catégories
      final categories = await db.rawQuery('''
        SELECT 
          c.*,
          COALESCE(COUNT(p.id), 0) as nb_produits
        FROM categories c
        LEFT JOIN produits p ON c.id = p.categorieId AND p.actif = 1
        GROUP BY c.id, c.nom
        ORDER BY c.nom
      ''');

      // Charger les produits récents
      final produits = await db.rawQuery('''
        SELECT p.*, c.nom as categorie_nom
        FROM produits p
        LEFT JOIN categories c ON p.categorieId = c.id
        WHERE p.actif = 1
        ORDER BY p.id DESC LIMIT 5
      ''');

      // Charger les unités
      final unites = await db.query('unites');

      if (mounted) {
        setState(() {
          _categories = categories;
          _produits = produits;
          _unites = unites.map((u) => Unite.fromMap(u)).toList();
        });
        print('Catégories chargées2: ${_categories.length}'); // Debug log
      }
    } catch (e, stack) {
      print('Erreur lors du chargement des données: $e');
      print('Stack trace: $stack');
    }
  }

  Future<void> _ajouterProduit() async {
    try {
      final db = await DBHelper.database;
      await db.insert('produits', {
        'nom': nomController.text,
        'categorieId': selectedCategorie,
        'prix': double.parse(prixController.text),
        'stock': int.parse(stockController.text),
        'seuilAlerte': int.parse(seuilController.text),
        'actif': actif ? 1 : 0,
      });

      _loadData();
      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit ajouté avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout: $e')),
      );
    }
  }

  Future<void> _ajouterCategorie(String nom) async {
    try {
      final db = await DBHelper.database;
      await db.insert('categories', {'nom': nom});
      _loadData();
    } catch (e) {
      print('Erreur lors de l\'ajout de la catégorie: $e');
    }
  }

  Future<void> _supprimerCategorie(int id) async {
    try {
      final db = await DBHelper.database;
      await db.update(
        'produits',
        {'categorieId': null},
        where: 'categorieId = ?',
        whereArgs: [id],
      );
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
      _loadData();
    } catch (e) {
      print('Erreur lors de la suppression de la catégorie: $e');
    }
  }

  Future<void> _ajouterUnite(String nom, String? symbole) async {
    try {
      final db = await DBHelper.database;
      await db.insert('unites', {
        'nom': nom,
        'symbole': symbole,
      });
      _loadData();
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'unité: $e');
    }
  }

  void _modifierCategorie(Map<String, dynamic> category) {
    TextEditingController nomController =
        TextEditingController(text: category['nom']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier la catégorie'),
        content: TextField(
          controller: nomController,
          decoration: InputDecoration(
            labelText: 'Nom de la catégorie',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isNotEmpty) {
                final db = await DBHelper.database;
                await db.update(
                  'categories',
                  {'nom': nomController.text},
                  where: 'id = ?',
                  whereArgs: [category['id']],
                );
                Navigator.of(context).pop();
                _loadData();
              }
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog() {
    final nomController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category, color: Colors.white),
                    SizedBox(width: 16),
                    Text(
                      'Nouvelle catégorie',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Contenu
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom de la catégorie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: nomController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Boissons, Snacks, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () async {
                        if (nomController.text.isNotEmpty) {
                          await _ajouterCategorie(nomController.text);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Catégorie ajoutée')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddUnitDialog() {
    final nomController = TextEditingController();
    final symboleController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten, color: Colors.white),
                    SizedBox(width: 16),
                    Text(
                      'Nouvelle unité de mesure',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Contenu
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom de l\'unité',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: nomController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Kilogramme, Litre, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Symbole',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: symboleController,
                      decoration: InputDecoration(
                        hintText: 'Ex: kg, L, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () async {
                        if (nomController.text.isNotEmpty) {
                          await _ajouterUnite(
                              nomController.text, symboleController.text);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unité ajoutée')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _modifierUnite(Unite unite) {
    final nomController = TextEditingController(text: unite.nom);
    final symboleController = TextEditingController(text: unite.symbole);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier unité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'unité',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: symboleController,
              decoration: InputDecoration(
                labelText: 'Symbole',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            onPressed: () async {
              if (nomController.text.isNotEmpty) {
                await _updateUnite(unite.id!, {
                  'nom': nomController.text,
                  'symbole': symboleController.text,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unité mise à jour')),
                );
              }
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUnite(int id, Map<String, dynamic> data) async {
    try {
      final db = await DBHelper.database;
      await db.update('unites', data, where: 'id = ?', whereArgs: [id]);
      _loadData();
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'unité: $e');
    }
  }

  Future<void> _supprimerUnite(int id) async {
    try {
      final db = await DBHelper.database;
      await db.delete('unites', where: 'id = ?', whereArgs: [id]);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unité supprimée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    // Implémenter la sélection d'image ici
    // Utiliser image_picker package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité à venir')),
    );
  }

  Future<void> _scanBarcode() async {
    // Implémenter le scan de code-barres ici
    // Utiliser flutter_barcode_scanner package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité à venir')),
    );
  }

  Future<void> _exportToCsv() async {
    try {
      final db = await DBHelper.database;
      final produits = await db.rawQuery('''
        SELECT 
          p.*, 
          c.nom as categorie_nom,
          u.nom as unite_nom
        FROM produits p
        LEFT JOIN categories c ON p.categorieId = c.id
        LEFT JOIN unites u ON p.uniteId = u.id
      ''');

      List<List<dynamic>> rows = [
        // En-têtes
        [
          'ID',
          'Nom',
          'Catégorie',
          'Prix',
          'Stock',
          'Seuil Alerte',
          'Unité',
          'Actif'
        ]
      ];

      // Données
      rows.addAll(produits.map((produit) => [
            produit['id'],
            produit['nom'],
            produit['categorie_nom'] ?? 'Non catégorisé',
            produit['prix'],
            produit['stock'],
            produit['seuilAlerte'],
            produit['unite_nom'] ?? 'Unité par défaut',
            produit['actif'] == 1 ? 'Oui' : 'Non',
          ]));

      String csv = const ListToCsvConverter().convert(rows);

      // Demander où sauvegarder le fichier
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le fichier CSV',
        fileName: 'produits_${DateTime.now().millisecondsSinceEpoch}.csv',
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(csv);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export CSV réussi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddProductModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 800,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_business, color: Colors.white),
                    SizedBox(width: 16),
                    Text(
                      'Ajouter un nouveau produit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section informations générales
                      Text(
                        'Informations générales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                                'Nom du produit*', nomController),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildCategorieDropdown(),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Section prix et stock
                      Text(
                        'Prix et stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Prix de vente*',
                              prixController,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                                'Stock initial*', stockController),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                                'Seuil d\'alerte', seuilController),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Section code-barres et image
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code-barres / SKU',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          hintText:
                                              'Scanner ou saisir le code-barres',
                                          prefixIcon: Icon(Icons.qr_code),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _scanBarcode,
                                      icon: Icon(Icons.qr_code_scanner),
                                      label: Text('Scanner'),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Image du produit',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: IconButton(
                                      icon: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 32),
                                      onPressed: _pickImage,
                                    ),
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
              // Actions
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () {
                        _ajouterProduit();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    nomController.clear();
    prixController.clear();
    stockController.clear();
    seuilController.clear();
    setState(() {
      selectedCategorie = null;
      actif = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Formulaire d'ajout/modification à gauche
        Expanded(
          flex: 2,
          child: Container(
            margin: EdgeInsets.all(24),
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
            child: ListView(
              // crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créer ou modifier un produit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),
                _buildTextField('Nom du produit', nomController),
                SizedBox(height: 16),
                _buildCategorieDropdown(),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('Prix de vente', prixController),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField('Prix d\'achat', prixController),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('Stock initial', stockController),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child:
                          _buildTextField('Seuil d\'alerte', seuilController),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text('Code-barres / SKU'),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                    ),
                  ],
                ),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Ex: 123456789',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text('Image du produit'),
                    Spacer(),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.upload),
                      label: Text('Choisir'),
                    ),
                  ],
                ),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                ),
                SwitchListTile(
                  title: Text('Actif'),
                  value: actif,
                  onChanged: (value) => setState(() => actif = value),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _ajouterProduit,
                        child: Text('Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {},
                      child: Text('Annuler'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Sections à droite
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Section Catégories
                _buildSection(
                  'Catégories',
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      return _buildCategoryItem(_categories[index]);
                    },
                  ),
                  onAdd: _showAddCategoryDialog,
                ),
                SizedBox(height: 24),
                // Section Produits enregistrés
                _buildSection(
                  'Produits enregistrés',
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _produits.length,
                    itemBuilder: (context, index) {
                      return _buildProductItem(_produits[index]);
                    },
                  ),
                ),
                SizedBox(height: 24),
                // Section Unités
                _buildSection(
                  'Unités',
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _unites.length,
                    itemBuilder: (context, index) {
                      final unite = _unites[index];
                      return _buildUnitItem(unite);
                    },
                  ),
                  onAdd: _showAddUnitDialog,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorieDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Catégorie'),
            Spacer(),
            TextButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: Icon(Icons.add),
              label: Text('Nouvelle'),
            ),
          ],
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedCategorie,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hintText: 'Sélectionner une catégorie',
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Aucune catégorie'),
            ),
            ..._categories.map((category) {
              return DropdownMenuItem<String>(
                value: category['id'].toString(),
                child: Text(category['nom'] ?? 'Catégorie sans nom'),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() => selectedCategorie = value);
          },
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content, {VoidCallback? onAdd}) {
    return Container(
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
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: onAdd,
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
          Divider(height: 1),
          content,
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return ListTile(
      title: Text(category['nom']),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${category['nb_produits']} produits',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined),
            onPressed: () => _modifierCategorie(category),
            color: Colors.grey[600],
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => _supprimerCategorie(category['id']),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> produit) {
    final bool stockBas =
        (produit['stock'] as int) <= (produit['seuilAlerte'] as int? ?? 5);
    final bool rupture = (produit['stock'] as int) == 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: Icon(Icons.fastfood, color: Colors.grey[400]),
      ),
      title: Text(produit['nom']),
      subtitle: Text(produit['categorie_nom'] ?? 'Non catégorisé'),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: rupture
              ? Colors.red.shade50
              : stockBas
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${produit['stock']} en stock',
          style: TextStyle(
            color: rupture
                ? Colors.red
                : stockBas
                    ? Colors.orange
                    : Colors.green,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildUnitItem(Unite unite) {
    return ListTile(
      title: Text(unite.nom),
      subtitle: unite.symbole != null ? Text(unite.symbole!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit_outlined),
            onPressed: () => _modifierUnite(unite),
            color: Colors.grey[600],
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Supprimer l\'unité'),
                  content:
                      Text('Êtes-vous sûr de vouloir supprimer cette unité ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _supprimerUnite(unite.id!);
                      },
                      child: Text('Supprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
