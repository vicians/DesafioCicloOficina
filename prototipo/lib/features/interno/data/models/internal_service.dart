import 'internal_budget_item.dart';

class InternalService {
  final String id;
  final String? clientId;
  final String sourceType;
  final String client;
  final String car;
  final String plate;
  final String service; // Resumo dos serviços
  final List<BudgetLineItem> budgetServices;
  final List<BudgetLineItem> budgetProducts;
  final String employeeObservation;
  final String status;
  final String mechanic;
  final String time;
  final double value;
  final int progress;
  final String openedAt; // 'dd/MM/yyyy'
  final String? finishedAt; // 'dd/MM/yyyy', presente quando concluido/cancelado

  const InternalService({
    required this.id,
    this.clientId,
    this.sourceType = 'execucao',
    required this.client,
    required this.car,
    required this.plate,
    required this.service,
    this.budgetServices = const [],
    this.budgetProducts = const [],
    this.employeeObservation = '',
    required this.status,
    required this.mechanic,
    required this.time,
    required this.value,
    required this.progress,
    required this.openedAt,
    this.finishedAt,
  });

  factory InternalService.fromJson(Map<String, dynamic> json) {
    final servicesJson = _readLineItems(json, ['servicos', 'itens_servico']);
    final productsJson = _readLineItems(json, ['produtos', 'itens_produto']);

    // Formatar data iniciada_em
    String rawDate =
        json['iniciado_em'] as String? ?? json['criado_em'] as String? ?? '';
    String formattedDate = '';
    String formattedTime = '—';
    if (rawDate.length >= 10) {
      formattedDate =
          '${rawDate.substring(8, 10)}/${rawDate.substring(5, 7)}/${rawDate.substring(0, 4)}';
    }
    if (rawDate.length >= 16) {
      formattedTime = rawDate.substring(11, 16);
    }

    String? rawFinished = json['finalizado_em'] as String?;
    String? formattedFinished;
    if (rawFinished != null && rawFinished.length >= 10) {
      formattedFinished =
          '${rawFinished.substring(8, 10)}/${rawFinished.substring(5, 7)}/${rawFinished.substring(0, 4)}';
    }

    // Calcula progresso aproximado
    String currentStatus = (json['status'] as String? ?? 'aguardando')
        .toLowerCase();
    int progressVal = 0;
    if (currentStatus == 'em_execucao' || currentStatus == 'andamento') {
      progressVal = 50;
    }
    if (currentStatus == 'revisao_tecnica' ||
        currentStatus == 'aguardando_retirada') {
      progressVal = 80;
    }
    if (currentStatus == 'concluido') {
      progressVal = 100;
    }
    if (currentStatus == 'enviado' || currentStatus == 'orcamento') {
      progressVal = 20;
    }
    if (currentStatus == 'pendente') {
      progressVal = 10;
    }

    // Resumo de serviço
    List<dynamic>? servicosList = servicesJson;
    String servicoName = 'Sem serviços';
    final resumo = json['servico_resumo'] as String?;
    if (resumo != null && resumo.isNotEmpty) {
      servicoName = resumo;
      if (servicosList != null && servicosList.length > 1) {
        servicoName += ' + outros';
      }
    } else if (servicosList != null && servicosList.isNotEmpty) {
      servicoName = servicosList.first['nome'] as String? ?? 'Sem nome';
      if (servicosList.length > 1) {
        servicoName += ' + outros';
      }
    }

    return InternalService(
      id: json['id'] as String,
      clientId: json['cliente_id'] as String?,
      sourceType: json['flow_type'] as String? ?? _inferSourceType(json),
      client: json['cliente_nome'] as String? ?? 'Cliente não informado',
      car: json['veiculo_modelo'] != null && json['veiculo_marca'] != null
          ? '${json['veiculo_marca']} ${json['veiculo_modelo']}'
          : 'Veículo não informado',
      plate: json['veiculo_placa'] as String? ?? '---',
      service: servicoName,
      status: currentStatus,
      mechanic: json['oficina_nome'] as String? ?? 'Tião Oficina Mecânica',
      time: formattedTime,
      value: ((json['valor_total'] as num?)?.toDouble() ?? 0) / 100.0,
      progress: progressVal,
      openedAt: formattedDate,
      finishedAt: formattedFinished,
      employeeObservation: json['notas_internas'] as String? ?? '',
      budgetServices:
          servicesJson
              ?.map((e) => BudgetLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      budgetProducts:
          productsJson
              ?.map((e) => BudgetLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static String _inferSourceType(Map<String, dynamic> json) {
    if (json.containsKey('orcamento_id')) {
      return 'execucao';
    }
    if (json.containsKey('agendado_para')) {
      return 'agendamento';
    }
    return 'orcamento';
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
