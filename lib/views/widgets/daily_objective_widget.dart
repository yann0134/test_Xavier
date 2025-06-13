import 'package:flutter/material.dart';
import '../../services/objective_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';

class DailyObjectiveWidget extends StatefulWidget {
  const DailyObjectiveWidget({super.key});

  @override
  State<DailyObjectiveWidget> createState() => _DailyObjectiveWidgetState();
}

class _DailyObjectiveWidgetState extends State<DailyObjectiveWidget> {
  double _progress = 0;
  double _target = 0;
  double _currentSales = 0;
  final _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

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

    if (obj != null) {
      final amount = (obj['target_sales_amount'] as num?)?.toDouble() ?? 0;
      setState(() {
        _target = amount;
        _currentSales = sales;
        _progress = amount == 0 ? 0 : (sales / amount).clamp(0, 1);
      });
    }
  }

  Color get _progressColor {
    if (_progress < 0.3) return Colors.redAccent;
    if (_progress < 0.7) return Colors.orangeAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      bottom: 24,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/daily-objective'),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.track_changes,
                size: 16,
                color: _progressColor,
              ),
              const SizedBox(width: 8),
              Container(
                width: 100,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(_progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _progressColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${_currencyFormat.format(_currentSales)} / ${_currencyFormat.format(_target)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
