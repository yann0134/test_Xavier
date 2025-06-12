import 'package:flutter/material.dart';
import '../../services/pdf_service.dart';

class ReceiptModal extends StatelessWidget {
  final Map<String, dynamic> commande;

  const ReceiptModal({Key? key, required this.commande}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = commande['items'].toString().split(',');

    return Dialog(
      child: Container(
        width: 400,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reçu',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.print),
                  onPressed: () => _imprimerRecu(context),
                ),
              ],
            ),
            Divider(height: 32),
            // En-tête
            Text(
              'CaissePro Market',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('123 rue du Commerce'),
            Text('75001 Paris'),
            Text('Tel: 01 23 45 67 89'),
            Divider(height: 32),
            // Informations client
            if (commande['client_nom'] != null) ...[
              Text('Client: ${commande['client_nom']}'),
              if (commande['telephone'] != null)
                Text('Tel: ${commande['telephone']}'),
              if (commande['email'] != null)
                Text('Email: ${commande['email']}'),
              SizedBox(height: 16),
            ],
            // Articles
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(item),
                  );
                },
              ),
            ),
            Divider(height: 32),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '€${commande['total'].toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 24),
            Text(
              'Merci de votre visite !',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimerRecu(BuildContext context) async {
    try {
      final pdfPath = await PdfService.generateReceipt(commande);
      // Ouvrir le PDF avec le visualiseur par défaut
      // Utiliser la méthode appropriée selon la plateforme
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'impression: $e')),
      );
    }
  }
}
