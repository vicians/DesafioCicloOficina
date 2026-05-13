class ProdutoItem {
  final String id;
  final String nome;
  final String? marca;
  final double valor;

  const ProdutoItem({
    required this.id,
    required this.nome,
    this.marca,
    required this.valor,
  });

  factory ProdutoItem.fromJson(Map<String, dynamic> json) {
    return ProdutoItem(
      id: json['id'] as String,
      nome: json['nome'] as String,
      marca: json['marca'] as String?,
      valor: (json['valor'] as num).toDouble() / 100.0,
    );
  }
}
