import 'package:get/get.dart';
import 'app_localizations.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': AppLocalizations.localizedValues['en']!,
        'fr_FR': AppLocalizations.localizedValues['fr']!,
      };
}
