import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService().getCurrentUser();
    final id = user['id'] as int? ?? 1;
    await ObjectiveService.createObjectiveIfNeeded(sellerId: id);
    final obj = await ObjectiveService.getTodayObjective(id);
    final sales = await ObjectiveService.getTodaySales();
    setState(() {
      _objective = obj;
      _sales = sales;
      _loading = false;
    });
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.redAccent;
    if (progress < 0.7) return Colors.orangeAccent;
    return Colors.green;
  }

  String _getStatusLabel(double progress) {
    if (progress >= 1.0) return '🏆 Expert';
    if (progress >= 0.8) return '🌟 Excellent';
    if (progress >= 0.6) return '💪 En forme';
    if (progress >= 0.4) return '📈 En progression';
    if (progress >= 0.2) return '🎯 En route';
    return '🚀 Démarrage';
  }

  Widget _buildStatusBadge(double progress) {
    final label = _getStatusLabel(progress);
    final color = _getProgressColor(progress);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHeader(double target, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getProgressColor(progress).withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Objectif du jour',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              _buildStatusBadge(progress),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Objectif',
                  _currencyFormat.format(target),
                  Icons.flag,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Réalisé',
                  _currencyFormat.format(_sales),
                  Icons.trending_up,
                  _getProgressColor(progress),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(double progress, Color progressColor) {
    final List<MapEntry<String, String>> achievements = [
      MapEntry('🎯 Démarrage', '20%'),
      MapEntry('📈 En progression', '40%'),
      MapEntry('💪 En forme', '60%'),
      MapEntry('🌟 Excellent', '80%'),
      MapEntry('🏆 Expert', '100%'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progression',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(progressColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                        Text(
                          'complété',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: achievements.map((achievement) {
                    final isReached = progress >=
                        double.parse(achievement.value.replaceAll('%', '')) /
                            100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isReached
                                  ? progressColor.withOpacity(0.1)
                                  : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isReached ? Icons.check : Icons.lock,
                              size: 16,
                              color: isReached ? progressColor : Colors.grey,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            achievement.key,
                            style: TextStyle(
                              color: isReached
                                  ? Colors.grey[800]
                                  : Colors.grey[500],
                              fontWeight: isReached
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Spacer(),
                          Text(
                            achievement.value,
                            style: TextStyle(
                              color:
                                  isReached ? progressColor : Colors.grey[500],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(double target) {
    final remaining = target - _sales;
    final isAhead = remaining < 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyse',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isAhead ? Icons.arrow_circle_up : Icons.arrow_circle_down,
              color: isAhead ? Colors.green : Colors.orange,
              size: 32,
            ),
            title: Text(
              isAhead ? 'Objectif dépassé !' : 'Reste à réaliser',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            subtitle: Text(
              isAhead
                  ? '+${_currencyFormat.format(remaining.abs())}'
                  : _currencyFormat.format(remaining),
              style: TextStyle(
                color: isAhead ? Colors.green : Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text(
            'Objectif du jour',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final target =
        (_objective?['target_sales_amount'] as num?)?.toDouble() ?? 0;
    final progress = target == 0 ? 0 : (_sales / target).clamp(0.0, 1.0);
    final progressColor = _getProgressColor(progress.toDouble());

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Objectif du jour',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(target, progress.toDouble()),
              SizedBox(height: 24),
              _buildProgressSection(progress.toDouble(), progressColor),
              SizedBox(height: 24),
              _buildAnalyticsSection(target),
            ],
          ),
        ),
      ),
    );
  }
}
