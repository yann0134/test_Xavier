import 'package:flutter/material.dart';

class CartItem extends StatelessWidget {
  final String nom;
  final int quantite;
  final double prix;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  const CartItem({
    Key? key,
    required this.nom,
    required this.quantite,
    required this.prix,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  nom,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '€${(prix * quantite).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                onPressed: onRemove,
                iconSize: 20,
                color: Colors.grey[600],
              ),
              Text(
                quantite.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: onAdd,
                iconSize: 20,
                color: Colors.grey[600],
              ),
              IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: onDelete,
                iconSize: 20,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
