import 'package:flutter/material.dart';
import '../../services/objective_service.dart';
import '../../services/auth_service.dart';

class DailyObjectiveWidget extends StatefulWidget {
  const DailyObjectiveWidget({super.key});

  @override
  State<DailyObjectiveWidget> createState() => _DailyObjectiveWidgetState();
}

class _DailyObjectiveWidgetState extends State<DailyObjectiveWidget> {
  double _progress = 0;
  double _target = 0;

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
        _progress = amount == 0 ? 0 : (sales / amount).clamp(0, 1);
      });
    }
  }

  Color get _color {
    if (_progress < 0.3) return Colors.redAccent;
    if (_progress < 0.7) return Colors.orangeAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/daily-objective'),
        child: Material(
          color: Colors.white,
          elevation: 6,
          borderRadius: BorderRadius.circular(40),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation(_color),
                  backgroundColor: Colors.grey.shade300,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${(_progress * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      _target.toStringAsFixed(0),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
