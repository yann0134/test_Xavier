import 'package:flutter/material.dart';
import '../../models/produit.dart';
import '../../services/db_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class ProduitsPage extends StatefulWidget {
  @override
  _ProduitsPageState createState() => _ProduitsPageState();
}

class _ProduitsPageState extends State<ProduitsPage> {
  final _dbHelper = DBHelper();

  List<Map<String, dynamic>> _produits = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  int _produitsActifs = 0;
  int _stockBas = 0;
  int _rupture = 0;
  String? _selectedPrixFilter;
  String? _selectedStockFilter;

  // Ajout des contrôleurs
  final TextEditingController nomController = TextEditingController();
  final TextEditingController prixController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController seuilController = TextEditingController();
  final TextEditingController codeBarreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final csvData = await file.readAsString();
        final rows = const CsvToListConverter().convert(csvData);

        final db = await DBHelper.database;
        await db.transaction((txn) async {
          for (var row in rows.skip(1)) {
            // Skip header row
            await txn.insert('produits', {
              'nom': row[0],
              'categorieId': row[1],
              'prix': double.parse(row[2].toString()),
              'stock': int.parse(row[3].toString()),
              'seuilAlerte': int.parse(row[4].toString()),
              'actif': 1,
            });
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importation réussie')),
        );
        _loadData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'importation: $e')),
      );
    }
  }

  Future<void> _exportCSV() async {
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
        WHERE p.actif = 1
      ''');

      List<List<dynamic>> rows = [
        [
          'Nom',
          'Catégorie',
          'Prix',
          'Stock',
          'Seuil Alerte',
          'Unité'
        ] // En-tête
      ];

      // Données
      rows.addAll(produits.map((produit) => [
            produit['nom'],
            produit['categorie_nom'] ?? 'Non catégorisé',
            produit['prix'],
            produit['stock'],
            produit['seuilAlerte'],
            produit['unite_nom'] ?? 'Unité par défaut',
          ]));

      String csv = const ListToCsvConverter().convert(rows);

      // Demander où sauvegarder le fichier
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer l\'export des produits',
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
        ['ID', 'Nom', 'Catégorie', 'Prix', 'Stock', 'Seuil', 'Unité', 'Statut']
      ];

      rows.addAll(produits.map((p) => [
            p['id'],
            p['nom'],
            p['categorie_nom'] ?? 'Non catégorisé',
            p['prix'],
            p['stock'],
            p['seuilAlerte'],
            p['unite_nom'] ?? 'Unité par défaut',
            p['actif'] == 1 ? 'Actif' : 'Inactif'
          ]));

      String csv = const ListToCsvConverter().convert(rows);

      // Demander où sauvegarder le fichier
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer l\'export des produits',
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

  void _showCategorieFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrer par catégorie'),
        content: Container(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text('Toutes les catégories'),
                selected: _selectedCategory == null,
                onTap: () {
                  setState(() => _selectedCategory = null);
                  Navigator.pop(context);
                  _loadData();
                },
              ),
              ..._categories.map((cat) => ListTile(
                    title: Text(cat['nom']),
                    selected: _selectedCategory == cat['id'].toString(),
                    onTap: () {
                      setState(() => _selectedCategory = cat['id'].toString());
                      Navigator.pop(context);
                      _loadData();
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showStockFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrer par stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Tous les produits'),
              selected: _selectedStockFilter == null,
              onTap: () {
                setState(() => _selectedStockFilter = null);
                Navigator.pop(context);
                _loadData();
              },
            ),
            ListTile(
              title: Text('Stock bas'),
              selected: _selectedStockFilter == 'bas',
              onTap: () {
                setState(() => _selectedStockFilter = 'bas');
                Navigator.pop(context);
                _loadData();
              },
            ),
            ListTile(
              title: Text('En rupture'),
              selected: _selectedStockFilter == 'rupture',
              onTap: () {
                setState(() => _selectedStockFilter = 'rupture');
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrixFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trier par prix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Prix croissant'),
              selected: _selectedPrixFilter == 'asc',
              onTap: () {
                setState(() => _selectedPrixFilter = 'asc');
                Navigator.pop(context);
                _loadData();
              },
            ),
            ListTile(
              title: Text('Prix décroissant'),
              selected: _selectedPrixFilter == 'desc',
              onTap: () {
                setState(() => _selectedPrixFilter = 'desc');
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> _loadData() async {
    try {
      final db = await DBHelper.database;

      // Charger les statistiques
      final stats = await Future.wait<List<Map<String, Object?>>>([
        db.rawQuery('SELECT COUNT(*) as count FROM produits WHERE actif = 1'),
        db.rawQuery(
            'SELECT COUNT(*) as count FROM produits WHERE stock <= seuilAlerte AND stock > 0'),
        db.rawQuery('SELECT COUNT(*) as count FROM produits WHERE stock = 0'),
      ]);

      // Charger les catégories
      final categories = await db.query('categories');

      // Charger les produits avec filtre
      String whereClause = 'p.actif = 1';
      List<dynamic> whereArgs = [];

      if (_searchQuery.isNotEmpty) {
        whereClause += ' AND p.nom LIKE ?';
        whereArgs.add('%$_searchQuery%');
      }
      if (_selectedCategory != null) {
        whereClause += ' AND p.categorieId = ?';
        whereArgs.add(_selectedCategory);
      }
      if (_selectedStockFilter == 'bas') {
        whereClause += ' AND p.stock <= p.seuilAlerte AND p.stock > 0';
      } else if (_selectedStockFilter == 'rupture') {
        whereClause += ' AND p.stock = 0';
      }

      String orderBy = '';
      if (_selectedPrixFilter == 'asc') {
        orderBy = ' ORDER BY p.prix ASC';
      } else if (_selectedPrixFilter == 'desc') {
        orderBy = ' ORDER BY p.prix DESC';
      }

      final produits = await db.rawQuery('''
        SELECT p.*, c.nom as categorie_nom 
        FROM produits p 
        LEFT JOIN categories c ON p.categorieId = c.id 
        WHERE $whereClause
        $orderBy
      ''', whereArgs);

      if (mounted) {
        setState(() {
          _produitsActifs = stats[0].first['count'] as int;
          _stockBas = stats[1].first['count'] as int;
          _rupture = stats[2].first['count'] as int;
          _categories = categories;
          _produits = produits;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données3: $e');
    }
  }

  Future<void> _deleteProduit(int id, String nomProduit) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$nomProduit" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmation ?? false) {
      try {
        final db = await DBHelper.database;
        await db.update(
          'produits',
          {'actif': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produit supprimé avec succès')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  void _showProductModal([Map<String, dynamic>? produit]) {
    // Reset controllers or set them with product values if editing
    if (produit != null) {
      nomController.text = produit['nom'];
      prixController.text = produit['prix'].toString();
      stockController.text = produit['stock'].toString();
      seuilController.text = produit['seuilAlerte']?.toString() ?? '5';
      _selectedCategory = produit['categorieId']?.toString();
    } else {
      _resetForm();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 800,
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9),
              child: Column(
                children: [
                  // En-tête
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_business, color: Colors.white),
                        SizedBox(width: 16),
                        Text(
                          produit != null
                              ? 'Modifier le produit'
                              : 'Ajouter un nouveau produit',
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

                  // Contenu scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Informations générales
                          _buildSectionTitle(
                              'Informations générales', Icons.info_outline),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Catégorie'),
                                    SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCategory,
                                          isExpanded: true,
                                          hint: Text(
                                              '  Sélectionner une catégorie'),
                                          items: [
                                            DropdownMenuItem(
                                              value: null,
                                              child: Text('  Aucune catégorie'),
                                            ),
                                            ..._categories.map((cat) =>
                                                DropdownMenuItem(
                                                  value: cat['id'].toString(),
                                                  child:
                                                      Text('  ${cat['nom']}'),
                                                )),
                                          ],
                                          onChanged: (value) {
                                            setDialogState(() =>
                                                _selectedCategory = value);
                                            setState(() =>
                                                _selectedCategory = value);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),

                          // Prix et stock
                          _buildSectionTitle('Prix et stock', Icons.inventory),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                    'Prix de vente*', prixController,
                                    prefix: '€'),
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

                          // Code-barres et image
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle(
                                        'Code-barres', Icons.qr_code),
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: codeBarreController,
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
                                    _buildSectionTitle('Image', Icons.image),
                                    SizedBox(height: 16),
                                    Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: IconButton(
                                          icon: Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
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
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade200)),
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
                          label: Text(produit != null
                              ? 'Mettre à jour'
                              : 'Enregistrer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          onPressed: () async {
                            if (produit != null) {
                              await _updateProduit(produit['id']);
                            } else {
                              await _ajouterProduit();
                            }
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateProduit(int id) async {
    try {
      if (nomController.text.isEmpty ||
          prixController.text.isEmpty ||
          stockController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Veuillez remplir tous les champs obligatoires')),
        );
        return;
      }

      final db = await DBHelper.database;
      await db.update(
        'produits',
        {
          'nom': nomController.text,
          'categorieId':
              _selectedCategory != null ? int.parse(_selectedCategory!) : null,
          'prix': double.parse(prixController.text),
          'stock': int.parse(stockController.text),
          'seuilAlerte': seuilController.text.isNotEmpty
              ? int.parse(seuilController.text)
              : 5,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      _resetForm();
      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit mis à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
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
          title: Text('Produits & Stock'),
          actions: [
            _buildImportExportButton(
              'Importer CSV',
              Icons.upload_file,
              Colors.green,
              onPressed: _importCSV,
            ),
            SizedBox(width: 8),
            _buildImportExportButton(
              'Exporter CSV',
              Icons.download,
              Colors.blue.shade700,
              onPressed: _exportCSV,
            ),
            SizedBox(width: 16),
            _buildAddButton(),
            SizedBox(width: 16),
          ],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistiques
                Row(
                  children: [
                    _buildStatCard(
                      'Produits actifs',
                      '$_produitsActifs',
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                    SizedBox(width: 24),
                    _buildStatCard(
                      'Stock bas',
                      '$_stockBas',
                      Icons.warning,
                      Colors.orange,
                    ),
                    SizedBox(width: 24),
                    _buildStatCard(
                      'Rupture',
                      '$_rupture',
                      Icons.error_outline,
                      Colors.red,
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Barre de recherche et filtres
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                            hintText: 'Rechercher un produit...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    _buildFilterButton(
                      'Catégorie',
                      Icons.category,
                      onPressed: _showCategorieFilter,
                    ),
                    SizedBox(width: 8),
                    _buildFilterButton(
                      'Stock',
                      Icons.filter_list,
                      onPressed: _showStockFilter,
                    ),
                    SizedBox(width: 8),
                    _buildFilterButton(
                      'Prix',
                      Icons.euro,
                      onPressed: _showPrixFilter,
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Liste des produits
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
                            itemCount: _produits.length,
                            itemBuilder: (context, index) =>
                                _buildProductRow(_produits[index]),
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
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
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
          ],
        ),
      ),
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

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(width: 48), // Pour l'image
          Expanded(
              flex: 2,
              child:
                  Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Catégorie',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child:
                  Text('Prix', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child:
                  Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Seuil alerte',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 48), // Pour les actions
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> produit) {
    final bool stockBas =
        (produit['stock'] as int) <= (produit['seuilAlerte'] as int? ?? 5);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: Colors.grey[400]),
          ),
          SizedBox(width: 16),
          Expanded(flex: 2, child: Text(produit['nom'])),
          Expanded(
              flex: 1,
              child: Text(produit['categorie_nom'] ?? 'Non catégorisé')),
          Expanded(
              flex: 1,
              child: Text('€${(produit['prix'] as num).toStringAsFixed(2)}')),
          Expanded(
            flex: 1,
            child: Text(
              '${produit['stock']}',
              style: TextStyle(
                color: produit['stock'] == 0
                    ? Colors.red
                    : stockBas
                        ? Colors.orange
                        : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(flex: 1, child: Text('${produit['seuilAlerte'] ?? 5}')),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit, size: 20),
                onPressed: () => _showProductModal(produit),
                color: Colors.grey[600],
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 20),
                onPressed: () => _deleteProduit(produit['id'], produit['nom']),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportExportButton(
    String label,
    IconData icon,
    Color color, {
    required VoidCallback onPressed,
  }) {
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
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String? prefix}) {
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
            prefixText: prefix,
          ),
          keyboardType: prefix == '€' ||
                  label.contains('Stock') ||
                  label.contains('Seuil')
              ? TextInputType.number
              : TextInputType.text,
        ),
      ],
    );
  }

  Widget _buildCategorieDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catégorie'),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              hint: Text('  Sélectionner une catégorie'),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('  Aucune catégorie'),
                ),
                ..._categories.map((cat) => DropdownMenuItem(
                      value: cat['id'].toString(),
                      child: Text('  ${cat['nom']}'),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ajouterProduit() async {
    try {
      if (nomController.text.isEmpty ||
          prixController.text.isEmpty ||
          stockController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Veuillez remplir tous les champs obligatoires')),
        );
        return;
      }

      final db = await DBHelper.database;
      await db.insert('produits', {
        'nom': nomController.text,
        'categorieId':
            _selectedCategory != null ? int.parse(_selectedCategory!) : null,
        'prix': double.parse(prixController.text),
        'stock': int.parse(stockController.text),
        'seuilAlerte': seuilController.text.isNotEmpty
            ? int.parse(seuilController.text)
            : 5,
        'actif': 1,
      });

      _resetForm();
      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit ajouté avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout: $e')),
      );
    }
  }

  Future<void> _scanBarcode() async {
    // TODO: Implémenter la fonction de scan
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonction de scan à implémenter')),
    );
  }

  Future<void> _pickImage() async {
    // TODO: Implémenter la sélection d'image
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sélection d\'image à implémenter')),
    );
  }

  void _resetForm() {
    nomController.clear();
    prixController.clear();
    stockController.clear();
    seuilController.clear();
    codeBarreController.clear();
    setState(() {
      _selectedCategory = null;
    });
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: () => _showProductModal(),
      icon: Icon(Icons.add),
      label: Text('Ajouter un produit'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}
