import 'package:flutter/material.dart';

class OrderListItem extends StatelessWidget {
  final String orderNumber;
  final String time;
  final double amount;
  final String? clientName;

  const OrderListItem({
    required this.orderNumber,
    required this.time,
    required this.amount,
    this.clientName,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (clientName != null)
                  Text(
                    clientName!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '€${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
