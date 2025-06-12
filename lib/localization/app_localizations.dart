import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> localizedValues = {
    'en': {
      'home': 'Home',
      'orders': 'Orders',
      'history': 'History',
      'products': 'Products / Stock',
      'reports': 'Reports',
      'management': 'Management',
      'settings': 'Settings',
      'assistant': 'AI Assistant',
      'dark_theme': 'Dark Theme',
      'language': 'Language',
      'send': 'Send',
      'ask_hint': 'Ask something...'
    },
    'fr': {
      'home': 'Accueil',
      'orders': 'Commande',
      'history': 'Historique',
      'products': 'Produits / Stock',
      'reports': 'Rapports',
      'management': 'Gestion',
      'settings': 'Paramètres',
      'assistant': 'Assistant IA',
      'dark_theme': 'Thème sombre',
      'language': 'Langue',
      'send': 'Envoyer',
      'ask_hint': 'Posez une question...'
    }
  };

  String translate(String key) {
    return localizedValues[locale.languageCode]?[key] ??
        localizedValues['en']![key] ?? key;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}
