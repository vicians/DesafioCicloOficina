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
      notasCliente: map['notas_cliente'] as String?,
    );
  }

  @override
  Future<List<ScheduledServiceItem>> fetchScheduledServices() async {
    final agendamentosResp = await _client.get(Uri.parse('$baseUrl/agendamentos'));

    if (agendamentosResp.statusCode != 200) {
      throw Exception('Falha ao buscar agendamentos: ${agendamentosResp.statusCode}');
    }

    final List<dynamic> agendamentos =
        jsonDecode(agendamentosResp.body) as List<dynamic>;
    final items = agendamentos
        .cast<Map<String, dynamic>>()
        .map(_mapScheduledItem)
        .toList();

    items.sort((a, b) => a.agendadoPara.compareTo(b.agendadoPara));
    return items;
  }

  @override
  Future<String> sendScheduleToBudgets({
    required ScheduledServiceItem schedule,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/orcamentos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'agendamento_id': schedule.id,
        'cliente_id': schedule.clienteId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_readErrorMessage(response, 'Falha ao enviar agendamento para orçamentos'));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final budgetId = body['id'] as String?;
    if (budgetId == null || budgetId.isEmpty) {
      throw Exception('Orçamento criado sem ID retornado pela API');
    }
    return budgetId;
  }
}
