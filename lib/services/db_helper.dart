import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;
  static const String DATABASE_NAME = 'caissepro.db';
  static bool _isInitialized = false;

  // Singleton pattern
  static final DBHelper _instance = DBHelper._internal();

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  static Future<void> initializeFfi() async {
    if (_isInitialized) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _isInitialized = true;
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;

    await initializeFfi();
    String path = join(await getDatabasesPath(), DATABASE_NAME);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Produits
    await db.execute('''
      CREATE TABLE produits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        categorieId INTEGER NULL,
        prix REAL NOT NULL,
        stock INTEGER NOT NULL,
        seuilAlerte INTEGER,
        actif INTEGER NOT NULL,
        FOREIGN KEY (categorieId) REFERENCES categories(id)
      )
    ''');

    // Catégories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL
      )
    ''');

    // Clients
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT,
        email TEXT
      )
    ''');

    // Commandes
    await db.execute('''
      CREATE TABLE commandes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientId INTEGER,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        statut TEXT NOT NULL,
        remise_montant REAL DEFAULT 0,
        remise_pourcentage REAL DEFAULT 0,
        code_promo TEXT,
        total_avant_remise REAL,
        total_apres_remise REAL,
        montant_tva REAL,
        taux_tva REAL DEFAULT 20.0,
        notes TEXT,
        type_paiement TEXT,
        reference_paiement TEXT,
        FOREIGN KEY (clientId) REFERENCES clients(id)
      )
    ''');

    // Commande Produits (détail des lignes)
    await db.execute('''
      CREATE TABLE commande_produits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commandeId INTEGER,
        produitId INTEGER,
        quantite INTEGER NOT NULL,
        prixUnitaire REAL NOT NULL,
        FOREIGN KEY (commandeId) REFERENCES commandes(id),
        FOREIGN KEY (produitId) REFERENCES produits(id)
      )
    ''');

    // Reçus
    await db.execute('''
      CREATE TABLE recus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commandeId INTEGER,
        date TEXT NOT NULL,
        montant REAL NOT NULL,
        moyenPaiement TEXT NOT NULL,
        numeroRecu TEXT NOT NULL,
        FOREIGN KEY (commandeId) REFERENCES commandes(id)
      )
    ''');

    // Paiements (si plusieurs paiements par commande)
    await db.execute('''
      CREATE TABLE paiements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commandeId INTEGER,
        montant REAL NOT NULL,
        moyenPaiement TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (commandeId) REFERENCES commandes(id)
      )
    ''');

    // Utilisateurs (pour contrôle d'accès)
    await db.execute('''
      CREATE TABLE utilisateurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        email TEXT UNIQUE,
        motDePasse TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // Paramètres (globaux)
    await db.execute('''
      CREATE TABLE parametres (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cle TEXT UNIQUE NOT NULL,
        valeur TEXT
      )
    ''');

    // Rapports journaliers
    await db.execute('''
      CREATE TABLE rapports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        totalVentes REAL,
        totalCommandes INTEGER,
        nombreClients INTEGER
      )
    ''');

    // Daily objectives
    await db.execute('''
      CREATE TABLE IF NOT EXISTS objectives (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seller_id INTEGER,
        target_date TEXT,
        target_sales_amount REAL,
        target_sales_count INTEGER,
        generated_by_ai INTEGER DEFAULT 1,
        generated_at TEXT
      )
    ''');

    // Unités de mesure
    await db.execute('''
      CREATE TABLE unites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        symbole TEXT,
        description TEXT,
        conversion_ratio REAL DEFAULT 1.0,
        unite_base_id INTEGER,
        actif INTEGER DEFAULT 1,
        date_creation TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (unite_base_id) REFERENCES unites(id)
      )
    ''');

    // Insérer quelques unités de base
    await db.batch()
      ..insert('unites', {
        'nom': 'Pièce',
        'symbole': 'pc',
        'description': 'Unité par défaut',
      })
      ..insert('unites', {
        'nom': 'Kilogramme',
        'symbole': 'kg',
        'description': 'Poids en kilogrammes',
      })
      ..insert('unites', {
        'nom': 'Litre',
        'symbole': 'L',
        'description': 'Volume en litres',
      })
      ..insert('unites', {
        'nom': 'Gramme',
        'symbole': 'g',
        'description': 'Poids en grammes',
        'conversion_ratio': 0.001,
        'unite_base_id': 2, // Référence au kilogramme
      });
  }
}
