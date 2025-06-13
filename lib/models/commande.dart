import 'base_model.dart';

class Commande extends BaseModel {
  final String numero;
  final DateTime date;
  final double montant;
  final double remiseMontant;
  final String status;
  final String typePaiement;
  final String? clientNom;

  Commande({
    required this.numero,
    required this.date,
    required this.montant,
    required this.status,
    required this.typePaiement,
    this.remiseMontant = 0,
    this.clientNom,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': numero,
        'date': date.toIso8601String(),
        'total': montant,
        'remise_montant': remiseMontant,
        'statut': status,
        'moyenPaiement': typePaiement,
        'client_nom': clientNom,
      };

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory Commande.fromMap(Map<String, dynamic> map) {
    try {
      // Conversion sécurisée pour le numéro
      String numero = 'CMD${(map['id'] ?? 0).toString().padLeft(6, '0')}';

      // Conversion sécurisée pour la date
      DateTime date;
      try {
        date = DateTime.parse(map['date'] as String);
      } catch (e) {
        date = DateTime.now();
      }

      // Conversion sécurisée pour le montant et la remise
      final montant = _parseDouble(map['total']);
      final remiseMontant = _parseDouble(map['remise_montant']);

      return Commande(
        numero: numero,
        date: date,
        montant: montant,
        status: map['statut'] as String? ?? 'En attente',
        typePaiement: map['moyenPaiement'] as String? ?? 'Non spécifié',
        clientNom: map['client_nom'] as String?,
        remiseMontant: remiseMontant,
      );
    } catch (e, stack) {
      print('Erreur Commande.fromMap: $e\n$stack\nmap=$map');
      return Commande(
        numero: 'CMD000000',
        date: DateTime.now(),
        montant: 0.0,
        status: 'Erreur',
        typePaiement: 'Erreur',
        clientNom: null,
        remiseMontant: 0.0,
      );
    }
  }
}
