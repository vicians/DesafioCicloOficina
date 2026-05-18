class ReportData {
  final String month;
  final double revenue;
  final double revenueGrowth;
  final int services;
  final int servicesGrowth;
  final double avgTicket;
  final double avgTicketGrowth;
  final int pending;
  final List<StatusCount> byStatus;
  final List<TopService> topServices;
  final List<TopMechanic> topMechanics;

  const ReportData({
    required this.month,
    required this.revenue,
    required this.revenueGrowth,
    required this.services,
    required this.servicesGrowth,
    required this.avgTicket,
    required this.avgTicketGrowth,
    required this.pending,
    required this.byStatus,
    required this.topServices,
    required this.topMechanics,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final byStatusRaw = (json['byStatus'] as List<dynamic>? ?? const []);
    final topServicesRaw = (json['topServices'] as List<dynamic>? ?? const []);

    return ReportData(
      month: json['month'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      revenueGrowth: (json['revenueGrowth'] as num?)?.toDouble() ?? 0,
      services: (json['services'] as num?)?.toInt() ?? 0,
      servicesGrowth: (json['servicesGrowth'] as num?)?.toInt() ?? 0,
      avgTicket: (json['avgTicket'] as num?)?.toDouble() ?? 0,
      avgTicketGrowth: (json['avgTicketGrowth'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      byStatus: byStatusRaw
          .cast<Map<String, dynamic>>()
          .map(StatusCount.fromJson)
          .toList(),
      topServices: topServicesRaw
          .cast<Map<String, dynamic>>()
          .map(TopService.fromJson)
          .toList(),
      topMechanics: (json['topMechanics'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(TopMechanic.fromJson)
          .toList(),
    );
  }
}

class StatusCount {
  final String label;
  final int value;
  final int total;

  const StatusCount({
    required this.label,
    required this.value,
    required this.total,
  });

  factory StatusCount.fromJson(Map<String, dynamic> json) {
    return StatusCount(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopService {
  final String name;
  final int count;
  final double revenue;

  const TopService({
    required this.name,
    required this.count,
    required this.revenue,
  });

  factory TopService.fromJson(Map<String, dynamic> json) {
    return TopService(
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopMechanic {
  final String name;
  final int count;
  final double revenue;

  const TopMechanic({
    required this.name,
    required this.count,
    required this.revenue,
  });

  factory TopMechanic.fromJson(Map<String, dynamic> json) {
    return TopMechanic(
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}
