class InternalBudgetItem {
  final String id;
  final String client;
  final String car;
  final String plate;
  final String description;
  final double value;
  final String createdAt; // dd/MM/yyyy
  final String status; // pendente | cancelado
  final String? canceledAt;

  const InternalBudgetItem({
    required this.id,
    required this.client,
    required this.car,
    required this.plate,
    required this.description,
    required this.value,
    required this.createdAt,
    this.status = 'pendente',
    this.canceledAt,
  });

  bool get isCanceled => status == 'cancelado';

  InternalBudgetItem copyWith({
    String? id,
    String? client,
    String? car,
    String? plate,
    String? description,
    double? value,
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
      description: description ?? this.description,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      canceledAt: clearCanceledAt ? null : (canceledAt ?? this.canceledAt),
    );
  }
}
