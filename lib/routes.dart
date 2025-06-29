import 'package:flutter/material.dart';
import 'views/layout/main_layout.dart';
import 'views/auth/login_page.dart';
import 'services/auth_service.dart';
import 'views/assistant/modular_ai_page.dart';
import 'views/assistant/seller_summary_page.dart';
import 'views/assistant/daily_objective_page.dart';
import 'views/rapports/rapport_ia_page.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => FutureBuilder<bool>(
            future: AuthService().isLoggedIn(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.data == true) {
                return MainLayout(selectedIndex: 0);
              }

              return LoginPage();
            },
          ),
        );

      case '/login':
        return MaterialPageRoute(builder: (_) => LoginPage());

      case '/assistant':
        return MaterialPageRoute(builder: (_) => ModularAIPage());

      case '/seller-summary':
        return MaterialPageRoute(builder: (_) => const SellerSummaryPage());

      case '/daily-objective':
        return MaterialPageRoute(builder: (_) => const DailyObjectivePage());

      case '/ai-report':
        return MaterialPageRoute(builder: (_) => const RapportIAPage());

      default:
        return MaterialPageRoute(builder: (_) => LoginPage());
    }
  }
}
