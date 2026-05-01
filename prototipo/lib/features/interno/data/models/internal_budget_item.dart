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
  });

  double get value =>
      services.fold(0.0, (s, e) => s + e.total) +
      products.fold(0.0, (s, e) => s + e.total);

  bool get isCanceled => status == 'cancelado';

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
    );
  }
}
