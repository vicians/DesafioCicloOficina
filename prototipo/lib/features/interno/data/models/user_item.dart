class UserItem {
  final String id;
  final int tipoId;
  final String cpfCnpj;
  final String nome;
  final String telefone;
  final String email;
  final bool ativo;

  const UserItem({
    required this.id,
    required this.tipoId,
    required this.cpfCnpj,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.ativo,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'] as String,
      tipoId: json['tipo_id'] as int,
      cpfCnpj: json['cpf_cnpj'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      telefone: json['telefone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  String get profileName {
    switch (tipoId) {
      case 1:
        return 'Gerente';
      case 3:
        return 'Mecânico';
      case 2:
        return 'Cliente';
      default:
        return 'Desconhecido';
    }
  }
}
