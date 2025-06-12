import 'base_model.dart';

class Commande extends BaseModel {
  final String numero;
  final DateTime date;
  final double montant;
  final String status;
  final String typePaiement;
  final String? clientNom;
  final bool payee;

  Commande({
    required this.numero,
    required this.date,
    required this.montant,
    required this.status,
    required this.typePaiement,
    this.clientNom,
    this.payee = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': numero,
        'date': date.toIso8601String(),
        'total': montant,
        'statut': status,
        'moyenPaiement': typePaiement,
        'client_nom': clientNom,
        'payee': payee ? 1 : 0,
      };

  factory Commande.fromMap(Map<String, dynamic> map) => Commande(
        numero: map['id']?.toString() ?? '',
        date: DateTime.parse(map['date'] as String),
        montant: (map['total'] as num).toDouble(),
        status: map['statut'] ?? 'En attente',
        typePaiement: map['moyenPaiement'] ?? 'Non spécifié',
        clientNom: map['client_nom'],
        payee: map['payee'] == 1,
      );
}
