import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/db_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';
import '../../scoped_models/main_model.dart';
import '../../localization/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Modification des valeurs par défaut
  static const String PREF_DARK_MODE = 'darkMode';
  static const String PREF_LANGUAGE = 'language';
  static const String PREF_NOTIFICATIONS = 'notifications';
  static const String PREF_STOCK_ALERTS = 'stockAlerts';
  static const String PREF_SALES_ALERTS = 'salesAlerts';

  late SharedPreferences _prefs;
  bool _loading = true;

  // Initialisation des valeurs par défaut pour tous les booléens
  String selectedLanguage = 'Français';
  late Currency selectedCurrency;
  String selectedTimeZone = 'Europe/Paris';
  bool isDarkMode = false;
  bool emailNotifications = false; // Valeur par défaut
  bool appNotifications = false; // Valeur par défaut
  bool stockAlerts = false; // Valeur par défaut
  bool salesAlerts = false; // Valeur par défaut
  String? logoPath;

  // Méthodes de paiement avec valeurs par défaut
  bool acceptCash = true; // Valeur par défaut
  bool acceptCard = false; // Valeur par défaut
  bool acceptMobile = false; // Valeur par défaut
  bool acceptBankTransfer = false; // Valeur par défaut

  // Paramètres du reçu avec valeurs par défaut
  bool afficherLogo = true; // Valeur par défaut
  bool afficherAdresse = true; // Valeur par défaut
  bool afficherTel = true; // Valeur par défaut
  bool afficherMerci = true; // Valeur par défaut
  TextEditingController messagePersonnaliseController = TextEditingController();

  // Ajouter les variables pour l'imprimante
  String selectedPrinterType = 'USB';
  TextEditingController ipAddressController = TextEditingController();
  TextEditingController usbPortController = TextEditingController();

  // Mise à jour des données utilisateurs
  List<Map<String, dynamic>> users = [
    {
      'name': 'Pierre Martin',
      'role': 'Admin',
      'lastAccess': '24/05/2024 08:52',
      'active': true,
    },
    {
      'name': 'Nadia Touré',
      'role': 'Caissier',
      'lastAccess': '24/05/2024 08:52',
      'active': true,
    },
  ];

  // Variable pour la TVA avec valeur par défaut
  String selectedTVA = '20%'; // Ajout de cette ligne

  @override
  void initState() {
    super.initState();
    // Initialisation de la devise par défaut
    selectedCurrency = Currency.from(json: {
      "code": "EUR",
      "name": "Euro",
      "symbol": "€",
      "flag": "🇪🇺",
      "number": 978, // Changé de String à int
      "decimal_digits": 2,
      "name_plural": "Euros",
      "symbol_on_left": true, // Ajout des propriétés requises
      "decimal_separator": ",",
      "thousands_separator": " ",
      "space_between_amount_and_symbol": true
    });
    final model = ScopedModel.of<MainModel>(context, rebuildOnChange: false);
    isDarkMode = model.themeMode == ThemeMode.dark;
    selectedLanguage = model.locale.languageCode == 'en' ? 'English' : 'Français';
    logoPath = model.logoPath;
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    try {
      // Initialiser SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Charger les préférences locales
      setState(() {
        isDarkMode = _prefs.getBool(PREF_DARK_MODE) ?? false;
        selectedLanguage = _prefs.getString('language') ?? 'Français';
        emailNotifications = _prefs.getBool('emailNotifications') ?? false;
        appNotifications = _prefs.getBool('appNotifications') ?? false;
        stockAlerts = _prefs.getBool('stockAlerts') ?? false;
        salesAlerts = _prefs.getBool('salesAlerts') ?? false;
        logoPath = _prefs.getString('logoPath');
      });

      // Charger les param\xC3\xA8tres système depuis SharedPreferences ou BD
      final db = await DBHelper.database;
      final systemSettings = await db.query('parametres');

      for (var setting in systemSettings) {
        String key = setting['cle'] as String;
        String value = _prefs.getString(key) ?? setting['valeur'] as String;

        switch (key) {
          case 'currency':
            selectedCurrency = Currency.from(json: {
              "code": value,
              "name": value,
              "symbol": value,
              "flag": "🇪🇺",
              "number": 978, // Changé de String à int
              "decimal_digits": 2,
              "name_plural": "Euros",
              "symbol_on_left": true,
              "decimal_separator": ",",
              "thousands_separator": " ",
              "space_between_amount_and_symbol": true
            });
            break;
          case 'timezone':
            selectedTimeZone = value;
            break;
          case 'tva':
            selectedTVA = value;
            break;
          case 'payment_methods':
            final methods = value.split(',');
            acceptCash = methods.contains('cash');
            acceptCard = methods.contains('card');
            acceptMobile = methods.contains('mobile');
            acceptBankTransfer = methods.contains('transfer');
            break;
          // ... autres paramètres système
        }
      }

      // Charger la liste des utilisateurs
      final usersList = await db.query('utilisateurs');
      setState(() {
        users = usersList
            .map((u) => {
                  'name': u['nom'],
                  'role': u['role'],
                  'lastAccess': u['derniere_connexion'] ?? 'Jamais',
                  'active': u['actif'] == 1,
                })
            .toList();
      });

      setState(() => _loading = false);
    } catch (e) {
      print('Erreur lors du chargement des paramètres: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Sauvegarder les préférences locales
      await _prefs.setBool(PREF_DARK_MODE, isDarkMode);
      await _prefs.setString('language', selectedLanguage);
      await _prefs.setBool('emailNotifications', emailNotifications);
      await _prefs.setBool('appNotifications', appNotifications);
      await _prefs.setBool('stockAlerts', stockAlerts);
      await _prefs.setBool('salesAlerts', salesAlerts);
      await _prefs.setString('logoPath', logoPath ?? '');
      await _prefs.setString('currency', selectedCurrency.code);
      await _prefs.setString('timezone', selectedTimeZone);
      await _prefs.setString('tva', selectedTVA);
      await _prefs.setString('payment_methods', [
        if (acceptCash) 'cash',
        if (acceptCard) 'card',
        if (acceptMobile) 'mobile',
        if (acceptBankTransfer) 'transfer',
      ].join(','));

      final model = ScopedModel.of<MainModel>(context);
      model.setThemeMode(isDarkMode ? ThemeMode.dark : ThemeMode.light);
      model.setLocale(Locale(selectedLanguage == 'English' ? 'en' : 'fr'));
      model.setLogoPath(logoPath);

      // Sauvegarder les paramètres système
      final db = await DBHelper.database;

      // Mettre à jour les paramètres système
      await Future.wait([
        _updateSetting(db, 'currency', selectedCurrency.code),
        _updateSetting(db, 'timezone', selectedTimeZone),
        _updateSetting(db, 'tva', selectedTVA),
        _updateSetting(
            db,
            'payment_methods',
            [
              if (acceptCash) 'cash',
              if (acceptCard) 'card',
              if (acceptMobile) 'mobile',
              if (acceptBankTransfer) 'transfer',
            ].join(',')),
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paramètres sauvegardés')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    }
  }

  Future<void> _updateSetting(Database db, String key, String value) async {
    final count = await db.update(
      'parametres',
      {'valeur': value},
      where: 'cle = ?',
      whereArgs: [key],
    );

    if (count == 0) {
      await db.insert('parametres', {
        'cle': key,
        'valeur': value,
      });
    }
  }

  // Méthode pour modifier un utilisateur
  Future<void> _updateUser(Map<String, dynamic> user) async {
    try {
      final db = await DBHelper.database;
      await db.update(
        'utilisateurs',
        {'actif': user['active'] ? 1 : 0},
        where: 'nom = ?',
        whereArgs: [user['name']],
      );

      await _initializeSettings(); // Recharger les données
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'utilisateur: $e');
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final dir = await getApplicationDocumentsDirectory();
        final newPath = '${dir.path}/logo.png';
        await file.copy(newPath);
        setState(() => logoPath = newPath);
        // Save directly when logo changes
        await _prefs.setString('logoPath', logoPath!);
        final db = await DBHelper.database;
        await _updateSetting(db, 'logo_path', logoPath!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo mis à jour')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection du logo: $e')),
      );
    }
  }

  void _showUserModal({Map<String, dynamic>? user}) {
    // Si user est null, c'est une création, sinon c'est une édition
    final nomController = TextEditingController(text: user?['name'] ?? '');
    final emailController = TextEditingController(text: user?['email'] ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?['role'] ?? 'Caissier';

    showDialog(
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
                    Icon(user == null ? Icons.person_add : Icons.edit,
                        color: Colors.white),
                    SizedBox(width: 16),
                    Text(
                      user == null
                          ? 'Nouvel utilisateur'
                          : 'Modifier l\'utilisateur',
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
                    _buildModalField(
                      'Nom complet',
                      TextField(
                        controller: nomController,
                        decoration: InputDecoration(
                          hintText: 'Ex: Jean Dupont',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildModalField(
                      'Email',
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Ex: jean.dupont@email.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildModalField(
                      'Mot de passe',
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildModalField(
                      'Rôle',
                      StatefulBuilder(
                        builder: (context, setState) {
                          return DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: ['Admin', 'Caissier', 'Manager']
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() => selectedRole = value!);
                            },
                          );
                        },
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
                      label: Text(user == null ? 'Créer' : 'Mettre à jour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () async {
                        try {
                          final db = await DBHelper.database;
                          if (user == null) {
                            // Création
                            await db.insert('utilisateurs', {
                              'nom': nomController.text,
                              'email': emailController.text,
                              'motDePasse': passwordController.text,
                              'role': selectedRole,
                            });
                          } else {
                            // Mise à jour
                            final updates = {
                              'nom': nomController.text,
                              'email': emailController.text,
                              'role': selectedRole,
                            };

                            // Ajouter le mot de passe uniquement s'il a été modifié
                            if (passwordController.text.isNotEmpty) {
                              updates['motDePasse'] = passwordController.text;
                            }

                            await db.update(
                              'utilisateurs',
                              updates,
                              where: 'id = ?',
                              whereArgs: [user['id']],
                            );
                          }

                          Navigator.pop(context);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(user == null
                                    ? 'Utilisateur créé avec succès'
                                    : 'Utilisateur mis à jour')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
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

  void _showAddUserModal() {
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Caissier';

    showDialog(
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
                    Icon(Icons.person_add, color: Colors.white),
                    SizedBox(width: 16),
                    Text(
                      'Nouvel utilisateur',
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
                    _buildModalField(
                      'Nom complet',
                      TextField(
                        controller: nomController,
                        decoration: InputDecoration(
                          hintText: 'Ex: Jean Dupont',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildModalField(
                      'Email',
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Ex: jean.dupont@email.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildModalField(
                      'Mot de passe',
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildModalField(
                      'Rôle',
                      StatefulBuilder(
                        builder: (context, setState) {
                          return DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: ['Admin', 'Caissier', 'Manager']
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() => selectedRole = value!);
                            },
                          );
                        },
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
                      label: Text('Créer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () async {
                        try {
                          final db = await DBHelper.database;
                          await db.insert('utilisateurs', {
                            'nom': nomController.text,
                            'email': emailController.text,
                            'motDePasse': passwordController
                                .text, // À hasher en production
                            'role': selectedRole,
                          });
                          Navigator.pop(context);
                          _loadData(); // Recharger la liste des utilisateurs
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Utilisateur créé avec succès')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
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

  Widget _buildModalField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        field,
      ],
    );
  }

  Future<void> _loadData() async {
    try {
      final db = await DBHelper.database;

      // Charger les utilisateurs
      final usersList = await db.query('utilisateurs');

      if (mounted) {
        setState(() {
          users = usersList
              .map((u) => {
                    'name': u['nom'],
                    'role': u['role'],
                    'lastAccess': u['derniere_connexion'] ?? 'Jamais',
                    'active': u['actif'] == 1,
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text('Paramètres système'),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveSettings,
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne de gauche
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionCard(
                        'Paramètres généraux',
                        Column(
                          children: [
                            _buildSettingField(
                              'Nom du commerce',
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Maison du Goût',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            _buildSettingField(
                              'Logo',
                              Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: logoPath != null
                                            ? FileImage(File(logoPath!))
                                                as ImageProvider
                                            : const AssetImage('assets/images/logo.png'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _pickLogo,
                                    child: Text('Changer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildSettingField(
                              'Devise',
                              ListTile(
                                leading: Text(
                                  selectedCurrency.flag.toString(),
                                  style: TextStyle(fontSize: 25),
                                ),
                                title: Text(selectedCurrency.name),
                                subtitle: Text(
                                    '${selectedCurrency.symbol} (${selectedCurrency.code})'),
                                trailing: Icon(Icons.arrow_drop_down),
                                onTap: () {
                                  showCurrencyPicker(
                                    context: context,
                                    showFlag: true,
                                    showCurrencyName: true,
                                    showCurrencyCode: true,
                                    showSearchField: true,
                                    searchHint: 'Rechercher une devise',
                                    favorite: ['EUR', 'USD', 'GBP'],
                                    onSelect: (Currency currency) {
                                      setState(() {
                                        selectedCurrency = currency;
                                      });
                                    },
                                    theme: CurrencyPickerThemeData(
                                      flagSize: 25,
                                      titleTextStyle: TextStyle(fontSize: 17),
                                      subtitleTextStyle: TextStyle(
                                          fontSize: 15, color: Colors.grey),
                                    ),
                                  );
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            _buildSettingField(
                              'Fuseau horaire',
                              DropdownButtonFormField<String>(
                                value: selectedTimeZone,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: ['Europe/Paris', 'America/New_York']
                                    .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedTimeZone = value!);
                                },
                              ),
                            ),
                            _buildSettingField(
                              'Langue',
                              DropdownButtonFormField<String>(
                                value: selectedLanguage,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: ['Français', 'English']
                                    .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedLanguage = value!);
                                },
                              ),
                            ),
                            _buildSettingField(
                              'Personnalisation du reçu',
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showReceiptSettingsModal(context),
                                icon: Icon(Icons.receipt_long),
                                label: Text('Paramètres du reçu'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildSectionCard(
                        'Méthodes de paiement',
                        Column(
                          children: [
                            _buildPaymentMethodToggle(
                              'Espèces',
                              'Accepter les paiements en espèces',
                              acceptCash,
                              (value) => setState(() => acceptCash = value),
                            ),
                            _buildPaymentMethodToggle(
                              'Carte bancaire',
                              'Accepter les paiements par carte',
                              acceptCard,
                              (value) => setState(() => acceptCard = value),
                            ),
                            _buildPaymentMethodToggle(
                              'Paiement mobile',
                              'Accepter les paiements mobiles',
                              acceptMobile,
                              (value) => setState(() => acceptMobile = value),
                            ),
                            _buildPaymentMethodToggle(
                              'Virement bancaire',
                              'Accepter les virements',
                              acceptBankTransfer,
                              (value) =>
                                  setState(() => acceptBankTransfer = value),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildSectionCard(
                        'TVA',
                        Column(
                          children: [
                            _buildSettingField(
                              'Taux de TVA par défaut',
                              DropdownButtonFormField<String>(
                                value: selectedTVA,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: ['0%', '5.5%', '10%', '20%']
                                    .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedTVA = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                // Colonne de droite
                Expanded(
                  child: Column(
                    children: [
                      _buildUsersSection(),
                      SizedBox(height: 24),
                      _buildSectionCard(
                        'Notifications & Alertes',
                        Column(
                          children: [
                            _buildNotificationToggle(
                              'Alertes stock bas',
                              'Notifications lorsque le stock d\'un produit est bas',
                              stockAlerts,
                              (value) => setState(() => stockAlerts = value),
                            ),
                            _buildNotificationToggle(
                              'Ventes importantes',
                              'Notifications pour les ventes importantes',
                              salesAlerts,
                              (value) => setState(() => salesAlerts = value),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Méthodes de notification :',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            _buildNotificationMethodToggle(
                              'Email',
                              emailNotifications,
                              (value) =>
                                  setState(() => emailNotifications = value),
                            ),
                            _buildNotificationMethodToggle(
                              'Application',
                              appNotifications,
                              (value) =>
                                  setState(() => appNotifications = value),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildSectionCard(
                        'Personnalisation',
                        Column(
                          children: [
                            _buildNotificationToggle(
                              'dark_theme'.tr,
                              'Activer le mode sombre',
                              isDarkMode,
                              (value) => setState(() => isDarkMode = value),
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
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      width: double.infinity,
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
            padding: EdgeInsets.all(24),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(24),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingField(String label, Widget field) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          field,
        ],
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
    );
  }

  Widget _buildNotificationMethodToggle(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: (val) => onChanged(val!),
      activeColor: Colors.blue,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPaymentMethodToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade100,
                child: Icon(Icons.person_outline,
                    color: Colors.grey[600], size: 20),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                user['role'],
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user['lastAccess'],
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            SizedBox(
              width: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 20),
                    color: Colors.blue,
                    onPressed: () => _showUserModal(user: user),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSection() {
    return _buildSectionCard(
      'Gestion des utilisateurs',
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // En-tête du tableau
              TextButton.icon(
                onPressed: () =>
                    _showUserModal(), // Utiliser la nouvelle fonction sans paramètre
                icon: Icon(Icons.add, size: 20),
                label: Text('Ajouter un utilisateur'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Liste des utilisateurs
          ...users.map((user) => _buildUserListItem(user)).toList(),
        ],
      ),
    );
  }

  // Ajouter la méthode pour afficher le modal
  void _showReceiptSettingsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: 800,
                height: 600,
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Paramètres du reçu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Panneau de configuration à gauche
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Configuration du reçu',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  SwitchListTile(
                                    title: Text('Afficher le logo'),
                                    value: afficherLogo,
                                    onChanged: (value) {
                                      setState(() => afficherLogo = value);
                                    },
                                  ),
                                  SwitchListTile(
                                    title: Text('Afficher l\'adresse'),
                                    value: afficherAdresse,
                                    onChanged: (value) {
                                      setState(() => afficherAdresse = value);
                                    },
                                  ),
                                  SwitchListTile(
                                    title:
                                        Text('Afficher le numéro de téléphone'),
                                    value: afficherTel,
                                    onChanged: (value) {
                                      setState(() => afficherTel = value);
                                    },
                                  ),
                                  SwitchListTile(
                                    title: Text(
                                        'Afficher "Merci de votre visite"'),
                                    value: afficherMerci,
                                    onChanged: (value) {
                                      setState(() => afficherMerci = value);
                                    },
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Message personnalisé',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        TextField(
                                          controller:
                                              messagePersonnaliseController,
                                          decoration: InputDecoration(
                                            hintText: 'Ex: À bientôt !',
                                            border: OutlineInputBorder(),
                                          ),
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    'Configuration de l\'imprimante',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  ListTile(
                                    title: Text('Type de connexion'),
                                    subtitle: SegmentedButton<String>(
                                      segments: [
                                        ButtonSegment(
                                          value: 'USB',
                                          label: Text('USB'),
                                          icon: Icon(Icons.usb),
                                        ),
                                        ButtonSegment(
                                          value: 'IP',
                                          label: Text('IP'),
                                          icon: Icon(Icons.wifi),
                                        ),
                                      ],
                                      selected: {selectedPrinterType},
                                      onSelectionChanged: (Set<String> value) {
                                        setState(() {
                                          selectedPrinterType = value.first;
                                        });
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        selectedPrinterType == 'USB'
                                            ? DropdownButtonFormField<String>(
                                                decoration: InputDecoration(
                                                  labelText: 'Port USB',
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: ['COM1', 'COM2', 'COM3']
                                                    .map((String value) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: value,
                                                    child: Text(value),
                                                  );
                                                }).toList(),
                                                onChanged: (String? value) {},
                                              )
                                            : TextField(
                                                controller: ipAddressController,
                                                decoration: InputDecoration(
                                                  labelText: 'Adresse IP',
                                                  hintText: '192.168.1.100',
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                        SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            // TODO: Implémenter le test d'impression
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Impression test en cours...'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          icon: Icon(Icons.print),
                                          label: Text('Tester l\'impression'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 24),
                          // Aperçu du reçu à droite
                          Container(
                            width: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aperçu du reçu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView(
                                      children: [
                                        if (afficherLogo)
                                          Container(
                                            height: 60,
                                            width: 120,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Center(
                                              child: Text('LOGO'),
                                            ),
                                          ),
                                        SizedBox(height: 16),
                                        Text(
                                          'CaissePro Market',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (afficherAdresse) ...[
                                          SizedBox(height: 8),
                                          Text('123 rue du Commerce'),
                                          Text('75001 Paris'),
                                        ],
                                        if (afficherTel) ...[
                                          SizedBox(height: 8),
                                          Text('Tél: 01 23 45 67 89'),
                                        ],
                                        Divider(height: 32),
                                        // Exemple d'articles
                                        _buildReceiptItem('Coca Cola', '2.00€'),
                                        _buildReceiptItem(
                                            'Burger Maison', '8.50€'),
                                        _buildReceiptItem('Frites', '3.00€'),
                                        Divider(height: 32),
                                        _buildReceiptTotal('TOTAL', '13.50€'),
                                        SizedBox(height: 16),
                                        if (afficherMerci)
                                          Text(
                                            'Merci de votre visite !',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        if (messagePersonnaliseController
                                            .text.isNotEmpty)
                                          Text(
                                            messagePersonnaliseController.text,
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler'),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            _saveSettings();
                            Navigator.pop(context);
                          },
                          child: Text('Enregistrer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptItem(String name, String price) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(price),
        ],
      ),
    );
  }

  Widget _buildReceiptTotal(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          amount,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
