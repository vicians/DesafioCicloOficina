import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api/api_helper.dart';
import 'models/scheduled_service_item.dart';
import 'scheduling_repository.dart';

class SchedulingApiRepository implements SchedulingRepository {
  final String baseUrl;

  SchedulingApiRepository({
    required this.baseUrl,
  });

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
      orcamentoStatus: map['orcamento_status'] as String?,
      orcamentoTemItens: map['orcamento_tem_itens'] == true,
    );
  }

  @override
  Future<List<ScheduledServiceItem>> fetchScheduledServices() async {
    final agendamentosResp = await ApiHelper.get('$baseUrl/agendamentos');
    final orcamentosResp = await ApiHelper.get('$baseUrl/orcamentos');

    if (agendamentosResp.statusCode != 200) {
      throw Exception('Falha ao buscar agendamentos: ${agendamentosResp.statusCode}');
    }

    if (orcamentosResp.statusCode != 200) {
      throw Exception('Falha ao buscar orçamentos: ${orcamentosResp.statusCode}');
    }

    final List<dynamic> orcamentos = jsonDecode(orcamentosResp.body) as List<dynamic>;
    final sentBudgetAgendamentoIds = <String>{};
    final budgetByAgendamento = <String, Map<String, dynamic>>{};

    for (final raw in orcamentos.cast<Map<String, dynamic>>()) {
      final status = (raw['status'] as String? ?? '').toUpperCase();
      final agendamentoId = raw['agendamento_id'] as String?;
      if (agendamentoId != null && agendamentoId.isNotEmpty) {
        budgetByAgendamento[agendamentoId] = raw;
        if (status == 'ENVIADO') {
          sentBudgetAgendamentoIds.add(agendamentoId);
        }
      }
    }

    final List<dynamic> agendamentos =
        jsonDecode(agendamentosResp.body) as List<dynamic>;
    final items = agendamentos
        .cast<Map<String, dynamic>>()
        .where((map) {
          final agendamentoId = map['id'] as String? ?? '';
          final possuiExecucao = map['possui_execucao'] == true;
          return !sentBudgetAgendamentoIds.contains(agendamentoId) && !possuiExecucao;
        })
        .map((map) {
          final agendamentoId = map['id'] as String? ?? '';
          final budget = budgetByAgendamento[agendamentoId];
          
          if (budget != null) {
            final budgetStatus = (budget['status'] as String? ?? '').toUpperCase();
            map['orcamento_status'] = budgetStatus.isNotEmpty ? budgetStatus : map['orcamento_status'];
            
            // O backend local já traz orcamento_tem_itens, mas o remoto (antigo) traz nulo.
            if (map['orcamento_tem_itens'] == null || map['orcamento_tem_itens'] == false) {
              final servicos = (budget['servicos'] as List?) ?? (budget['itens_servico'] as List?) ?? [];
              final produtos = (budget['produtos'] as List?) ?? (budget['itens_produto'] as List?) ?? [];
              final valorTotal = (budget['valor_total'] as num?)?.toInt() ?? 0;
              
              map['orcamento_tem_itens'] = servicos.isNotEmpty || 
                                           produtos.isNotEmpty || 
                                           valorTotal > 0 || 
                                           budgetStatus == 'ENVIADO' || 
                                           budgetStatus == 'APROVADO';
            }
            map['possui_orcamento'] = true;
          }
          return _mapScheduledItem(map);
        })
        .toList();

    items.sort((a, b) => a.agendadoPara.compareTo(b.agendadoPara));
    return items;
  }

  @override
  Future<String> confirmScheduleToService({
    required ScheduledServiceItem schedule,
  }) async {
    final response = await ApiHelper.patch(
      '$baseUrl/agendamentos/${schedule.id}/confirmar-recebimento',
      {
        'funcionario_id': schedule.funcionarioId,
      },
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
    final response = await ApiHelper.post(
      '$baseUrl/orcamentos',
      {
        'cliente_id': schedule.clienteId,
        'funcionario_id': schedule.funcionarioId,
        'agendamento_id': schedule.id,
      },
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
