import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle; // Ajout du paramètre subtitle

  const StatsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
