class CatalogoServicoItem {
  final String id;
  final String nome;
  final double preco;
  final String? descricao;
  final int duracaoMinutos;

  const CatalogoServicoItem({
    required this.id,
    required this.nome,
    required this.preco,
    this.descricao,
    this.duracaoMinutos = 60,
  });

  factory CatalogoServicoItem.fromJson(Map<String, dynamic> json) {
    return CatalogoServicoItem(
      id: json['id'] as String,
      nome: json['nome'] as String,
      preco: (json['preco'] as num).toDouble() / 100.0,
      descricao: json['descricao'] as String?,
      duracaoMinutos: json['duracao_minutos'] as int? ?? 60,
    );
  }
}
