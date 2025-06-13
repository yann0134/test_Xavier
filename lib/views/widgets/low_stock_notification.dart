import 'package:flutter/material.dart';

class LowStockNotification extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const LowStockNotification({
    Key? key,
    required this.count,
    required this.onClose,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = count > 5 ? Colors.red : Colors.orange;
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text('$count produits en stock critique'),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
