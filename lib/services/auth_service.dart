import 'package:shared_preferences/shared_preferences.dart';
import 'db_helper.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String KEY_USER_ID = 'userId';
  static const String KEY_USER_ROLE = 'userRole';
  static const String KEY_USER_NAME = 'userName';

  Future<bool> login(String email, String password) async {
    try {
      final db = await DBHelper.database;

      // Hash du mot de passe
      final hashedPassword = sha256.convert(utf8.encode(password)).toString();
      //  print("${sha256.convert(utf8.encode("123456")).toString()}");
      final result = await db.query(
        'utilisateurs',
        where: 'email = ? AND motDePasse = ?',
        whereArgs: [email, hashedPassword],
        limit: 1,
      );

      if (result.isEmpty) return false;

      // Stocker les informations de session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(KEY_USER_ID, result.first['id'] as int);
      await prefs.setString(KEY_USER_ROLE, result.first['role'] as String);
      await prefs.setString(KEY_USER_NAME, result.first['nom'] as String);

      return true;
    } catch (e) {
      print('Erreur de connexion: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(KEY_USER_ID);
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getInt(KEY_USER_ID),
      'role': prefs.getString(KEY_USER_ROLE),
      'name': prefs.getString(KEY_USER_NAME),
    };
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}
