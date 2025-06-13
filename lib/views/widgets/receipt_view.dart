import 'package:flutter/material.dart';
import '../../models/commande.dart';
import '../../services/pdf_service.dart';
import '../../services/db_helper.dart';

class ReceiptView extends StatelessWidget {
  final Commande commande;
  final VoidCallback? onPay;

  const ReceiptView({
    Key? key,
    required this.commande,
    this.onPay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête du reçu
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'CaissePro Market',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('123 rue du Commerce'),
                        Text('75001 Paris'),
                        Text('Tel: 01 23 45 67 89'),
                        SizedBox(height: 16),
                        Text(
                          'REÇU',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu du reçu
                  FutureBuilder<Map<String, dynamic>>(
                    future: _loadCommandeDetails(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        print(" snapshot ${snapshot}");
                        return Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Erreur de chargement'),
                        );
                      }

                      final details = snapshot.data!;
                      return Container(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Informations de la commande
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                      'N° Commande:', '#${commande.numero}'),
                                  _buildInfoRow(
                                      'Date:', _formatDate(commande.date)),
                                  if (details['client_nom'] != null)
                                    _buildInfoRow(
                                        'Client:', details['client_nom']),
                                  _buildInfoRow('Statut:', commande.status,
                                      color: _getStatusColor(commande.status)),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Articles
                            Text(
                              'ARTICLES',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // En-tête du tableau
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                            flex: 2, child: Text('Article')),
                                        Expanded(
                                            flex: 1,
                                            child: Text('Qté',
                                                textAlign: TextAlign.center)),
                                        Expanded(
                                            flex: 1,
                                            child: Text('Prix',
                                                textAlign: TextAlign.right)),
                                      ],
                                    ),
                                  ),
                                  // Liste des articles
                                  ...details['items'].map<Widget>((item) {
                                    final total = (item['quantite'] as int) *
                                        (item['prixUnitaire'] as double);
                                    return Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                              color: Colors.grey.shade200),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              flex: 2,
                                              child: Text(item['nom'])),
                                          Expanded(
                                              flex: 1,
                                              child: Text('${item['quantite']}',
                                                  textAlign: TextAlign.center)),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '€${total.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                  fontFamily: 'Monospace'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Total et remises
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  if (details['remise_montant'] > 0)
                                    _buildTotalRow(
                                      'Remise:',
                                      '-€${details['remise_montant']}',
                                      color: Colors.green,
                                    ),
                                  if (details['remise_pourcentage'] > 0)
                                    _buildTotalRow(
                                      'Remise %:',
                                      '-${details['remise_pourcentage']}%',
                                      color: Colors.green,
                                    ),
                                  _buildTotalRow(
                                    'TOTAL:',
                                    '€${commande.montant.toStringAsFixed(2)}',
                                    isBold: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Actions
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (commande.status == 'En attente')
                          ElevatedButton.icon(
                            icon: Icon(Icons.payment),
                            label: Text('Payer'),
                            onPressed: onPay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: Icon(Icons.print),
                          label: Text('Imprimer'),
                          onPressed: () => _printReceipt(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadCommandeDetails() async {
    final db = await DBHelper.database;

    // Extraire l'ID numérique de la commande (ex: "CMD000002" -> 2)
    final idStr = commande.numero.replaceAll(RegExp(r'[^\d]'), '');
    final id = int.tryParse(idStr) ?? 0;

    // Charger les détails de la commande
    final details = await db.rawQuery('''
      SELECT 
        c.*,
        cl.nom as client_nom,
        cl.telephone,
        cl.email
      FROM commandes c
      LEFT JOIN clients cl ON c.clientId = cl.id
      WHERE c.id = ?
    ''', [id]);

    // Charger les articles de la commande
    final items = await db.rawQuery('''
      SELECT 
        cp.quantite,
        cp.prixUnitaire,
        p.nom
      FROM commande_produits cp
      JOIN produits p ON cp.produitId = p.id
      WHERE cp.commandeId = ?
    ''', [id]);

    if (details.isEmpty) {
      throw Exception('Commande non trouvée');
    }

    return {
      ...details.first,
      'items': items,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      final details = await _loadCommandeDetails();

      // Préparation des données pour le PDF
      final receiptData = {
        'id': commande.numero,
        'date': _formatDate(commande.date),
        'total': commande.montant,
        'client_nom': details['client_nom'],
        'statut': commande.status,
        'items': (details['items'] as List)
            .map((item) =>
                '${item['quantite']}x ${item['nom']} @ ${item['prixUnitaire']}')
            .join(','),
        'remise_montant': details['remise_montant'] ?? 0,
        'remise_pourcentage': details['remise_pourcentage'] ?? 0,
      };

      final pdfFile = await PdfService.generateReceipt(receiptData);
      await PdfService.openFile(pdfFile);
    } catch (e) {
      print('Erreur impression: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'impression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: color,
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Payée':
        return Colors.green;
      case 'En attente':
        return Colors.orange;
      case 'Annulée':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
