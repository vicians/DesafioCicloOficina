class TimelineStep {
  final String id;
  final String time;
  final String date;
  final String title;
  final String desc;
  final bool done;
  final bool active;

  const TimelineStep({
    required this.id,
    required this.time,
    required this.date,
    required this.title,
    required this.desc,
    required this.done,
    required this.active,
  });

  factory TimelineStep.fromJson(Map<String, dynamic> json) {
    return TimelineStep(
      id: json['id']?.toString() ?? '',
      time: json['time'] ?? '—',
      date: json['date'] ?? '—',
      title: json['title'] ?? '',
      desc: json['desc'] ?? '',
      done: json['done'] ?? false,
      active: json['active'] ?? false,
    );
  }
}

class BudgetItem {
  final String label;
  final double total;
  final int? qty;
  final double? unitPrice;
  final String type; // 'part' | 'labor'

  const BudgetItem({
    required this.label,
    required this.total,
    this.qty,
    this.unitPrice,
    this.type = 'part',
  });

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      label: json['label'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
      qty: json['qty'],
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      type: json['type'] ?? 'part',
    );
  }
}

class ServiceModel {
  final String id;
  final String car;
  final String plate;
  final String status;
  final String title;
  final String mechanic;
  final String mechanicInitials;
  final String startDate;
  final String estimatedEnd;
  final int progress;
  final List<TimelineStep> timeline;
  final List<BudgetItem> budgetItems;
  final double budgetTotal;

  const ServiceModel({
    required this.id,
    required this.car,
    required this.plate,
    required this.status,
    required this.title,
    required this.mechanic,
    required this.mechanicInitials,
    required this.startDate,
    required this.estimatedEnd,
    required this.progress,
    required this.timeline,
    required this.budgetItems,
    required this.budgetTotal,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    final timelineJson = json['timeline'] as List? ?? [];
    final budgetItemsJson = json['budgetItems'] as List? ?? [];

    return ServiceModel(
      id: json['id']?.toString() ?? '',
      car: json['car'] ?? '',
      plate: json['plate'] ?? '',
      status: json['status'] ?? '',
      title: json['title'] ?? '',
      mechanic: json['mechanic'] ?? '',
      mechanicInitials: json['mechanicInitials'] ?? '',
      startDate: json['startDate'] ?? '',
      estimatedEnd: json['estimatedEnd'] ?? '',
      progress: json['progress'] ?? 0,
      timeline: timelineJson.map((e) => TimelineStep.fromJson(e)).toList(),
      budgetItems: budgetItemsJson.map((e) => BudgetItem.fromJson(e)).toList(),
      budgetTotal: (json['budgetTotal'] ?? 0).toDouble(),
    );
  }
}

class HistoryItem {
  final String id;
  final String title;
  final String date;
  final String status;
  final String total;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.date,
    required this.status,
    required this.total,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? '',
      total: json['total'] ?? '',
    );
  }
}
