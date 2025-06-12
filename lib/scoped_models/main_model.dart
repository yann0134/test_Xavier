import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainModel extends Model {
  int _currentIndex = 0;
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('fr');
  String? _logoPath;

  int get currentIndex => _currentIndex;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String? get logoPath => _logoPath;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void setLogoPath(String? path) {
    _logoPath = path;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool('darkMode') ?? false;
    final lang = prefs.getString('language') ?? 'fr';
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    _locale = Locale(lang);
    _logoPath = prefs.getString('logoPath');
    notifyListeners();
  }
}
