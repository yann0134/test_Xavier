class Unite {
  final int? id;
  final String nom;
  final String? symbole;

  Unite({
    this.id,
    required this.nom,
    this.symbole,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'symbole': symbole,
      };

  factory Unite.fromMap(Map<String, dynamic> map) => Unite(
        id: map['id'],
        nom: map['nom'],
        symbole: map['symbole'],
      );
}
