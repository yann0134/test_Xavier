import 'base_model.dart';

class Produit extends BaseModel {
  final int? id;
  final String nom;
  final String categorie;
  final double prix;
  final int stock;
  final bool actif;
  final String? imagePath;

  Produit({
    this.id,
    required this.nom,
    required this.categorie,
    required this.prix,
    this.stock = 0,
    this.actif = true,
    this.imagePath,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'categorie': categorie,
        'prix': prix,
        'stock': stock,
        'actif': actif ? 1 : 0,
        'imagePath': imagePath,
      };

  factory Produit.fromMap(Map<String, dynamic> map) => Produit(
        id: map['id'],
        nom: map['nom'],
        categorie: map['categorie'],
        prix: map['prix'],
        stock: map['stock'],
        actif: map['actif'] == 1,
        imagePath: map['imagePath'],
      );
}
