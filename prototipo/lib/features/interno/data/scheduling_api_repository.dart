import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/scheduled_service_item.dart';
import 'scheduling_repository.dart';

class SchedulingApiRepository implements SchedulingRepository {
  final String baseUrl;
  final http.Client _client;

  SchedulingApiRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String _normalizeStatus(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'PENDENTE':
        return 'PENDENTE';
      case 'CONFIRMADO':
        return 'CONFIRMADO';
      case 'CANCELADO':
        return 'CANCELADO';
      case 'CONCLUIDO':
        return 'CONCLUIDO';
      // Em cenários legados o backend pode retornar ANDAMENTO para agendamento.
      // Para a UI de agenda, tratamos como confirmado para simplificar os filtros.
      case 'ANDAMENTO':
        return 'CONFIRMADO';
      default:
        return 'PENDENTE';
    }
  }

  String _readErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as String?;
      if (error != null && error.trim().isNotEmpty) {
        return error;
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  ScheduledServiceItem _mapScheduledItem(Map<String, dynamic> map) {
    final modelo = (map['veiculo_modelo'] as String?)?.trim();
    final marca = (map['veiculo_marca'] as String?)?.trim();
    final clienteNome = (map['cliente_nome'] as String?)?.trim().isNotEmpty == true
        ? (map['cliente_nome'] as String)
        : 'Cliente sem nome';

    final veiculoDescricao = [
      if (marca != null && marca.isNotEmpty) marca,
      if (modelo != null && modelo.isNotEmpty) modelo,
    ].join(' ');

    final agendadoPara = DateTime.tryParse(map['agendado_para'] as String? ?? '');

    return ScheduledServiceItem(
      id: map['id'] as String? ?? '',
      clienteId: map['cliente_id'] as String? ?? '',
      veiculoId: map['veiculo_id'] as String? ?? '',
      funcionarioId: map['funcionario_id'] as String?,
      clienteNome: clienteNome,
      veiculoDescricao: veiculoDescricao.isNotEmpty ? veiculoDescricao : 'Veiculo nao identificado',
      placa: (map['veiculo_placa'] as String?) ?? 'Sem placa',
      agendadoPara: agendadoPara ?? DateTime.now(),
      duracaoMinutos: (map['duracao_total_minutos'] as num?)?.toInt() ?? 0,
      status: _normalizeStatus(map['status'] as String? ?? 'PENDENTE'),
      possuiOrcamento: map['possui_orcamento'] == true,
      possuiExecucao: map['possui_execucao'] == true,
      notasCliente: map['notas_cliente'] as String?,
    );
  }

  @override
  Future<List<ScheduledServiceItem>> fetchScheduledServices() async {
    final agendamentosResp = await _client.get(Uri.parse('$baseUrl/agendamentos'));
    final orcamentosResp = await _client.get(Uri.parse('$baseUrl/orcamentos'));

    if (agendamentosResp.statusCode != 200) {
      throw Exception('Falha ao buscar agendamentos: ${agendamentosResp.statusCode}');
    }

    if (orcamentosResp.statusCode != 200) {
      throw Exception('Falha ao buscar orçamentos: ${orcamentosResp.statusCode}');
    }

    final List<dynamic> orcamentos = jsonDecode(orcamentosResp.body) as List<dynamic>;
    final sentBudgetAgendamentoIds = <String>{};
    for (final raw in orcamentos.cast<Map<String, dynamic>>()) {
      final status = (raw['status'] as String? ?? '').toUpperCase();
      final agendamentoId = raw['agendamento_id'] as String?;
      if (status == 'ENVIADO' && agendamentoId != null && agendamentoId.isNotEmpty) {
        sentBudgetAgendamentoIds.add(agendamentoId);
      }
    }

    final List<dynamic> agendamentos =
        jsonDecode(agendamentosResp.body) as List<dynamic>;
    final items = agendamentos
        .cast<Map<String, dynamic>>()
        .where((map) => !sentBudgetAgendamentoIds.contains(map['id'] as String? ?? ''))
        .map(_mapScheduledItem)
        .toList();

    items.sort((a, b) => a.agendadoPara.compareTo(b.agendadoPara));
    return items;
  }

  @override
  Future<String> confirmScheduleToService({
    required ScheduledServiceItem schedule,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/agendamentos/${schedule.id}/confirmar-recebimento'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'funcionario_id': schedule.funcionarioId,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_readErrorMessage(response, 'Falha ao confirmar recebimento do agendamento'));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final serviceId = body['id'] as String?;
    if (serviceId == null || serviceId.isEmpty) {
      throw Exception('OS criada sem ID retornado pela API');
    }
    return serviceId;
  }

  @override
  Future<String> openScheduleBudget({
    required ScheduledServiceItem schedule,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/orcamentos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cliente_id': schedule.clienteId,
        'funcionario_id': schedule.funcionarioId,
        'agendamento_id': schedule.id,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final id = body['id'] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('Orçamento retornado sem ID');
      }
      return id;
    }

    if (response.statusCode == 409) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final existing = body['orcamento_id'] as String?;
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
    }

    throw Exception(_readErrorMessage(response, 'Falha ao abrir orçamento para o agendamento'));
  }
}
