class CatalogoServicoItem {
  final String id;
  final String nome;
  final double preco;

  const CatalogoServicoItem({
    required this.id,
    required this.nome,
    required this.preco,
  });

  factory CatalogoServicoItem.fromJson(Map<String, dynamic> json) {
    return CatalogoServicoItem(
      id: json['id'] as String,
      nome: json['nome'] as String,
      preco: (json['preco'] as num).toDouble() / 100.0,
    );
  }
}
