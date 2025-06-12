import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:scoped_model/scoped_model.dart';
import 'services/db_helper.dart';
import 'scoped_models/main_model.dart';
import 'routes.dart';
import 'localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.initializeFfi();
  await DBHelper.database;

  final mainModel = MainModel();
  await mainModel.loadSettings();

  runApp(MyApp(mainModel));
}

class MyApp extends StatelessWidget {
  final MainModel mainModel;
  const MyApp(this.mainModel, {super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedModel<MainModel>(
      model: mainModel,
      child: ScopedModelDescendant<MainModel>(
        builder: (context, child, model) {
          return MaterialApp(
            title: 'CaissePro',
            theme: ThemeData.light().copyWith(useMaterial3: true),
            darkTheme: ThemeData.dark().copyWith(useMaterial3: true),
            themeMode: model.themeMode,
            locale: model.locale,
            supportedLocales: const [Locale('fr'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/',
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}
