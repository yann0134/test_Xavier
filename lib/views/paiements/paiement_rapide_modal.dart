import 'package:flutter/material.dart';
import '../../services/db_helper.dart';

class PaiementRapideModal extends StatefulWidget {
  final List<Map<String, dynamic>> commandes;

  const PaiementRapideModal({Key? key, required this.commandes})
      : super(key: key);

  @override
  _PaiementRapideModalState createState() => _PaiementRapideModalState();
}

class _PaiementRapideModalState extends State<PaiementRapideModal> {
  String? selectedPaymentMethod;
  int? selectedCommandeId; // Changement ici pour stocker l'ID de la commande

  Future<void> _validerPaiement() async {
    if (selectedCommandeId == null || selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Veuillez sélectionner une commande et un mode de paiement')),
      );
      return;
    }

    try {
      final commande = widget.commandes.firstWhere(
        (c) => c['id'] == selectedCommandeId,
        orElse: () => throw Exception('Commande non trouvée'),
      );

      final db = await DBHelper.database;

      // Mettre à jour le statut de la commande
      await db.update(
        'commandes',
        {'statut': 'payée'},
        where: 'id = ?',
        whereArgs: [commande['id']],
      );

      // Enregistrer le paiement
      await db.insert('paiements', {
        'commandeId': commande['id'],
        'montant': commande['total'],
        'moyenPaiement': selectedPaymentMethod,
        'date': DateTime.now().toIso8601String(),
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paiement validé avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du paiement: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          child: Container(
            width: 800,
            height: 600,
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paiement rapide',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Liste des commandes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commandes en cours',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.commandes.length,
                                itemBuilder: (context, index) {
                                  final commande = widget.commandes[index];
                                  final isSelected = selectedCommandeId ==
                                      commande['id']; // Modification ici

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.white,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          selectedCommandeId = commande[
                                              'id']; // Modification ici
                                        });
                                      },
                                      title: Text(
                                        'CMD${commande['id'].toString().padLeft(6, '0')}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.black,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(commande['client_nom'] ??
                                              'Client inconnu'),
                                          Text('Total: ${commande['total']}€'),
                                        ],
                                      ),
                                      trailing: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ...rest of existing code for payment methods
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mode de paiement :'),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                _buildPaymentMethodCard(
                                  'Espèces',
                                  Icons.money,
                                  Colors.green,
                                ),
                                SizedBox(width: 16),
                                _buildPaymentMethodCard(
                                  'Carte',
                                  Icons.credit_card,
                                  Colors.blue,
                                ),
                                SizedBox(width: 16),
                                _buildPaymentMethodCard(
                                  'Mobile',
                                  Icons.phone_android,
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ...rest of existing code for action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _validerPaiement,
                      child: Text('Valider le paiement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodCard(String method, IconData icon, Color color) {
    final isSelected = selectedPaymentMethod == method;

    return InkWell(
      onTap: () => setState(() => selectedPaymentMethod = method),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(method),
          ],
        ),
      ),
    );
  }
}
