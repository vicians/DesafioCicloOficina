class BudgetLineItem {
  final String id;
  final String name;
  final double unitPrice;
  final int qty;

  const BudgetLineItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.qty = 1,
  });

  double get total => unitPrice * qty;

  BudgetLineItem copyWith({String? id, String? name, double? unitPrice, int? qty}) {
    return BudgetLineItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      qty: qty ?? this.qty,
    );
  }

  factory BudgetLineItem.fromJson(Map<String, dynamic> json) {
    return BudgetLineItem(
      id: (json['item_id'] as String?) ?? json['id'] as String,
      name: json['nome'] as String,
      unitPrice: (json['preco_unitario'] as num).toDouble() / 100.0, // Conversão de centavos
      qty: json['quantidade'] as int,
    );
  }
}

class InternalBudgetItem {
  final String id;
  final String client;
  final String car;
  final String plate;
  final List<BudgetLineItem> services;
  final List<BudgetLineItem> products;
  final String observation;
  final String createdAt; // dd/MM/yyyy
  final String status; // pendente | cancelado
  final String? canceledAt;
  final bool isAvaliacao;
  final String? notasCliente;

  const InternalBudgetItem({
    required this.id,
    required this.client,
    required this.car,
    required this.plate,
    this.services = const [],
    this.products = const [],
    this.observation = '',
    required this.createdAt,
    this.status = 'pendente',
    this.canceledAt,
    this.isAvaliacao = false,
    this.notasCliente,
  });

  double get value =>
      services.fold(0.0, (s, e) => s + e.total) +
      products.fold(0.0, (s, e) => s + e.total);

  bool get isCanceled => status == 'cancelado' || status == 'rejeitado';

  bool get isPending => status == 'rascunho' || status == 'enviado';

  InternalBudgetItem copyWith({
    String? id,
    String? client,
    String? car,
    String? plate,
    List<BudgetLineItem>? services,
    List<BudgetLineItem>? products,
    String? observation,
    String? createdAt,
    String? status,
    String? canceledAt,
    bool clearCanceledAt = false,
    bool? isAvaliacao,
    String? notasCliente,
  }) {
    return InternalBudgetItem(
      id: id ?? this.id,
      client: client ?? this.client,
      car: car ?? this.car,
      plate: plate ?? this.plate,
      services: services ?? this.services,
      products: products ?? this.products,
      observation: observation ?? this.observation,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      canceledAt: clearCanceledAt ? null : (canceledAt ?? this.canceledAt),
      isAvaliacao: isAvaliacao ?? this.isAvaliacao,
      notasCliente: notasCliente ?? this.notasCliente,
    );
  }

  factory InternalBudgetItem.fromJson(Map<String, dynamic> json) {
    String rawDate = json['criado_em'] as String? ?? '';
    String formattedDate = '';
    if (rawDate.length >= 10) {
      formattedDate = '${rawDate.substring(8, 10)}/${rawDate.substring(5, 7)}/${rawDate.substring(0, 4)}';
    }

    final servicesJson = _readLineItems(json, ['servicos', 'itens_servico']);
    final productsJson = _readLineItems(json, ['produtos', 'itens_produto']);

    return InternalBudgetItem(
      id: json['id'] as String,
      client: json['cliente_nome'] as String? ?? 'Cliente não informado',
      car: json['veiculo_modelo'] != null && json['veiculo_marca'] != null
          ? '${json['veiculo_marca']} ${json['veiculo_modelo']}'
          : 'Veículo não informado',
      plate: json['veiculo_placa'] as String? ?? '---',
      status: (json['status'] as String? ?? 'RASCUNHO').toLowerCase(),
      createdAt: formattedDate,
      observation: json['observacoes'] as String? ?? '',
      isAvaliacao: json['is_avaliacao'] == true,
      notasCliente: json['notas_cliente'] as String?,
      services: servicesJson
              ?.map((e) => BudgetLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      products: productsJson
              ?.map((e) => BudgetLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static List<dynamic>? _readLineItems(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is List<dynamic>) {
        return value;
      }
    }
    return null;
  }
}
