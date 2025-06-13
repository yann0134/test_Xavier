import 'package:flutter/material.dart';
import '../../services/objective_service.dart';
import '../../services/auth_service.dart';

class DailyObjectivePage extends StatefulWidget {
  const DailyObjectivePage({super.key});

  @override
  State<DailyObjectivePage> createState() => _DailyObjectivePageState();
}

class _DailyObjectivePageState extends State<DailyObjectivePage> {
  Map<String, dynamic>? _objective;
  double _sales = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService().getCurrentUser();
    final id = user['id'] as int? ?? 1;
    await ObjectiveService.createObjectiveIfNeeded(sellerId: id);
    final obj = await ObjectiveService.getTodayObjective(id);
    final sales = await ObjectiveService.getTodaySales();
    setState(() {
      _objective = obj;
      _sales = sales;
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = (_objective?['target_sales_amount'] as num?)?.toDouble() ?? 0;
    final progress = target == 0 ? 0 : (_sales / target).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Objectif du jour')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Objectif: ${target.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text('Ventes réalisées: ${_sales.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}
