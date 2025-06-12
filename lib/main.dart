import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import 'services/db_helper.dart';
import 'scoped_models/main_model.dart';
import 'routes.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for sqflite
  await DBHelper.initializeFfi();
  await DBHelper.database;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final MainModel mainModel = MainModel();

  @override
  Widget build(BuildContext context) {
    return ScopedModel<MainModel>(
      model: mainModel,
      child: MaterialApp(
        title: 'CaissePro',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
