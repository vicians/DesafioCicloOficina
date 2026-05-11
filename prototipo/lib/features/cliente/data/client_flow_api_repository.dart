import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/auth_manager.dart';
import 'client_flow_repository.dart';
import 'models/client_models.dart';

class ClientFlowApiRepository extends ClientFlowRepository {
  final String baseUrl;
  final String clientId; // Hardcoded para o protótipo, mas injetável

  ClientFlowApiRepository({
    required this.baseUrl,
    required this.clientId,
  });

  @override
  Future<ServiceModel?> fetchCurrentService() async {
    try {
      // 1. Priorizar orçamento pendente (add-ons ENVIADO)
      final orcResp = await http.get(Uri.parse('$baseUrl/orcamentos'));
      if (orcResp.statusCode == 200) {
        final List orcs = jsonDecode(orcResp.body);
        final pendingOrc = orcs.firstWhere(
          (o) =>
              o['cliente_id'] == clientId &&
              (o['status'] as String).toLowerCase() == 'enviado',
          orElse: () => null,
        );

        if (pendingOrc != null) {
          return _mapOrcToServiceModel(pendingOrc);
        }
      }

      // 2. Sem orçamento pendente, buscar execução ativa
      final execResp = await http.get(Uri.parse('$baseUrl/execucoes'));
      if (execResp.statusCode == 200) {
        final List execs = jsonDecode(execResp.body);
        final activeExec = execs.firstWhere(
          (e) {
            final status = (e['status'] as String? ?? '').toLowerCase();
            return e['cliente_id'] == clientId && status != 'concluido' && status != 'cancelado';
          },
          orElse: () => null,
        );

        if (activeExec != null) {
          return _mapExecToServiceModel(activeExec);
        }
      }

      // 3. Sem execução e sem orçamento pendente, buscar agendamento ativo
      final agendResp = await http.get(
        Uri.parse('$baseUrl/agendamentos/cliente/$clientId'),
      );
      if (agendResp.statusCode == 200) {
        final List agends = jsonDecode(agendResp.body);
        final activeAgend = agends.firstWhere(
          (a) {
            final s = (a['status'] as String? ?? '').toUpperCase();
            return s == 'PENDENTE' || s == 'CONFIRMADO';
          },
          orElse: () => null,
        );
        if (activeAgend != null) {
          return _mapAgendamentoToServiceModel(activeAgend as Map<String, dynamic>);
        }
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }
  @override
  Future<List<HistoryItem>> fetchServiceHistory() async {
    try {
      final history = <HistoryItem>[];

      final execResp = await http.get(Uri.parse('$baseUrl/execucoes'));
      if (execResp.statusCode == 200) {
        final List execs = jsonDecode(execResp.body);
        final filtered = execs
            .where((e) {
              final s = (e['status'] as String? ?? '').toLowerCase();
              return e['cliente_id'] == clientId && (s == 'concluido' || s == 'cancelado');
            })
            .toList();
            
        filtered.sort((a, b) {
          final dateA = a['finalizado_em'] ?? '';
          final dateB = b['finalizado_em'] ?? '';
          return dateB.compareTo(dateA); // Descending
        });

        history.addAll(filtered.map<HistoryItem>((e) => HistoryItem(
                  id: e['id'],
                  title: (e['status'] as String? ?? '').toLowerCase() == 'cancelado'
                      ? (e['servico_resumo'] ?? 'Atendimento cancelado')
                      : (e['servico_resumo'] ?? 'Manutenção'),
                  date: _formatDate(e['finalizado_em']),
                  status: (e['status'] as String? ?? '').toLowerCase(),
                  total: 'R\$ ${(e['valor_total'] / 100).toStringAsFixed(2).replaceAll('.', ',')}',
                )));
      }

      final agendResp = await http.get(Uri.parse('$baseUrl/agendamentos/cliente/$clientId'));
      if (agendResp.statusCode == 200) {
        final List agends = jsonDecode(agendResp.body);
        final canceled = agends
            .where((a) => (a['status'] as String? ?? '').toUpperCase() == 'CANCELADO')
            .toList();

        history.addAll(canceled.map<HistoryItem>((a) {
          final marca = (a['veiculo_marca'] as String? ?? '').trim();
          final modelo = (a['veiculo_modelo'] as String? ?? '').trim();
          final desc = [marca, modelo].where((s) => s.isNotEmpty).join(' ');
          return HistoryItem(
            id: a['id'] as String? ?? '',
            title: desc.isEmpty ? 'Agendamento cancelado' : '$desc (cancelado)',
            date: _formatDate(a['agendado_para'] as String?),
            status: 'cancelado',
            total: '—',
          );
        }));
      }

      history.sort((a, b) => b.date.compareTo(a.date));
      return history;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> createVeiculo(String marca, String modelo, String placa, int ano) async {
    final response = await http.post(
      Uri.parse('$baseUrl/veiculos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cliente_id': clientId,
        'marca': marca,
        'modelo': modelo,
        'placa': placa,
        'ano': ano,
        'quilometragem_atual': 0,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Falha ao cadastrar veículo: ${response.body}');
    }
    notifyListeners();
  }

  @override
  Future<void> approveBudget(String budgetId) async {
    final validUntil = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    final resp = await http.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/aprovar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'valido_ate': validUntil}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao aprovar orçamento: ${resp.body}');
    }
    notifyListeners();
  }

  @override
  Future<void> refuseBudget(String budgetId) async {
    final resp = await http.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/rejeitar'),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao rejeitar orçamento: ${resp.body}');
    }
    notifyListeners();
  }

  @override
  Future<void> rejectBudgetChange(String budgetId) async {
    final resp = await http.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/rejeitar-addons'),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao rejeitar alteração: ${resp.body}');
    }
    notifyListeners();
  }

  @override
  Future<void> cancelService({required String budgetId, String? agendamentoId}) async {
    if (agendamentoId != null && agendamentoId.isNotEmpty) {
      final cancelAgendamentoResp = await http.patch(
        Uri.parse('$baseUrl/agendamentos/$agendamentoId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'CANCELADO'}),
      );
      if (cancelAgendamentoResp.statusCode != 200) {
        throw Exception('Falha ao cancelar agendamento: ${cancelAgendamentoResp.body}');
      }
    }

    final execResp = await http.get(Uri.parse('$baseUrl/execucoes/orcamento/$budgetId'));
    if (execResp.statusCode == 200) {
      final exec = jsonDecode(execResp.body) as Map<String, dynamic>;
      final execId = exec['id'] as String?;
      if (execId != null && execId.isNotEmpty) {
        await http.patch(
          Uri.parse('$baseUrl/execucoes/$execId/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': 'CANCELADO'}),
        );
      }
    }

    await refuseBudget(budgetId);
    notifyListeners();
  }

  @override
  Future<String> fetchProfileName() async {
    final headers = <String, String>{};
    if (AuthManager.token != null) {
      headers['Authorization'] = 'Bearer ${AuthManager.token}';
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/$clientId'),
      headers: headers.isNotEmpty ? headers : null,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['nome'] ?? 'Cliente';
    }
    return 'Cliente';
  }

  @override
  Future<List<Map<String, dynamic>>> fetchVehicles() async {
    final response = await http.get(Uri.parse('$baseUrl/veiculos/cliente/$clientId'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  ServiceModel _mapExecToServiceModel(Map<String, dynamic> exec) {
    final double total = (exec['valor_total'] ?? 0) / 100;
    
    // Mapear itens de orçamento para BudgetItem
    final List<BudgetItem> items = [];
    final rawItems = exec['itens_servico'] as List? ?? [];
    for (var i in rawItems) {
      items.add(BudgetItem(
        label: i['nome'] ?? 'Serviço',
        total: (i['preco_total'] ?? 0) / 100,
        qty: i['quantidade'],
        unitPrice: (i['preco_unitario'] ?? 0) / 100,
        type: 'labor',
      ));
    }
    final rawProducts = exec['itens_produto'] as List? ?? [];
    for (var i in rawProducts) {
      items.add(BudgetItem(
        label: i['nome'] ?? 'Produto',
        total: (i['preco_total'] ?? 0) / 100,
        qty: i['quantidade'],
        unitPrice: (i['preco_unitario'] ?? 0) / 100,
        type: 'part',
      ));
    }

    return ServiceModel(
      id: exec['id'],
      car: exec['veiculo_modelo'] ?? 'Veículo',
      plate: exec['veiculo_placa'] ?? '—',
      status: exec['status'],
      title: exec['servico_resumo'] ?? 'Serviço em execução',
      mechanic: exec['funcionario_nome'] ?? 'Mecânico',
      mechanicInitials: _getInitials(exec['funcionario_nome']),
      startDate: exec['iniciado_em'] ?? '—',
      estimatedEnd: 'Hoje, até 17h', // Mockado para o protótipo
      progress: _calculateProgress(exec['status']),
      timeline: _generateTimeline(exec),
      budgetItems: items,
      budgetTotal: total,
    );
  }

  ServiceModel _mapOrcToServiceModel(Map<String, dynamic> orc) {
    final double total = (orc['valor_total'] ?? 0) / 100;
    final status = (orc['status'] as String? ?? 'ORCAMENTO').toLowerCase();
    
    final List<BudgetItem> items = [];
    final rawItems = orc['itens_servico'] as List? ?? [];
    for (var i in rawItems) {
      items.add(BudgetItem(
        label: i['nome'] ?? 'Serviço',
        total: (i['preco_total'] ?? 0) / 100,
        qty: i['quantidade'],
        unitPrice: (i['preco_unitario'] ?? 0) / 100,
        type: 'labor',
      ));
    }
    final rawProducts = orc['itens_produto'] as List? ?? [];
    for (var i in rawProducts) {
      items.add(BudgetItem(
        label: i['nome'] ?? 'Produto',
        total: (i['preco_total'] ?? 0) / 100,
        qty: i['quantidade'],
        unitPrice: (i['preco_unitario'] ?? 0) / 100,
        type: 'part',
      ));
    }

    return ServiceModel(
      id: orc['id'],
      agendamentoId: orc['agendamento_id'] as String?,
      car: orc['veiculo_modelo'] ?? 'Veículo',
      plate: orc['veiculo_placa'] ?? '—',
      status: status,
      title: status == 'enviado'
          ? 'Alteração de orçamento pendente de aprovação'
          : 'Orçamento para aprovação',
      mechanic: orc['funcionario_nome'] ?? 'Mecânico',
      mechanicInitials: _getInitials(orc['funcionario_nome']),
      startDate: orc['criado_em'] ?? '—',
      estimatedEnd: 'Aguardando aprovação',
      progress: 20,
      timeline: _generateTimeline(orc),
      budgetItems: items,
      budgetTotal: total,
    );
  }

  ServiceModel _mapAgendamentoToServiceModel(Map<String, dynamic> agend) {
    final marca = (agend['veiculo_marca'] as String? ?? '').trim();
    final modelo = (agend['veiculo_modelo'] as String? ?? '').trim();
    final car = [marca, modelo].where((s) => s.isNotEmpty).join(' ');

    return ServiceModel(
      id: agend['id'] as String? ?? '',
      agendamentoId: agend['id'] as String? ?? '',
      car: car.isNotEmpty ? car : 'Veículo',
      plate: agend['veiculo_placa'] as String? ?? '—',
      status: 'agendado',
      title: 'Agendamento confirmado',
      mechanic: 'Aguardando atendimento',
      mechanicInitials: '??',
      startDate: _formatDate(agend['agendado_para'] as String?),
      estimatedEnd: 'Aguardando chegada na oficina',
      progress: 10,
      timeline: _generateTimelineAgendamento(agend),
      budgetItems: const [],
      budgetTotal: 0,
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  int _calculateProgress(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'agendado':
        return 10;
      case 'orcamento':
      case 'enviado':
        return 20;
      case 'aguardando':
      case 'pendente':
        return 30;
      case 'andamento':
      case 'em_execucao':
        return 65;
      case 'revisao':
      case 'revisao_tecnica':
        return 85;
      case 'aguardando_retirada':
        return 95;
      case 'concluido':
        return 100;
      default:
        return 0;
    }
  }

  List<TimelineStep> _generateTimeline(Map<String, dynamic> data) {
    // Para o protótipo, vamos gerar uma timeline estática baseada no status
    // O ideal seria ter uma tabela de histórico no banco de dados
    final status = (data['status'] as String? ?? '').toLowerCase();
    final isOrcamento = status == 'orcamento' || status == 'enviado';
    final isAguardando = status == 'aguardando' || status == 'pendente';
    final isExecucao = status == 'em_execucao' || status == 'andamento';
    final isRevisao = status == 'revisao_tecnica' || status == 'revisao';
    final isAguardandoRetirada = status == 'aguardando_retirada';
    final isConcluido = status == 'concluido';

    return [
      TimelineStep(
        id: '1',
        time: '08:00',
        date: 'Hoje',
        title: 'Veículo recebido',
        desc: 'Check-in realizado',
        done: true,
        active: false,
      ),
      TimelineStep(
        id: '2',
        time: '09:30',
        date: 'Hoje',
        title: 'Diagnóstico concluído',
        desc: 'Aguardando orçamento',
        done: isOrcamento || isAguardando || isExecucao || isRevisao || isAguardandoRetirada || isConcluido,
        active: false,
      ),
      TimelineStep(
        id: '3',
        time: '10:15',
        date: 'Hoje',
        title: 'Orçamento enviado',
        desc: 'Aguardando aprovação',
        done: isAguardando || isExecucao || isRevisao || isAguardandoRetirada || isConcluido,
        active: isOrcamento,
      ),
      TimelineStep(
        id: '4',
        time: '—',
        date: '—',
        title: 'Serviço em execução',
        desc: 'Mecânico trabalhando...',
        done: isRevisao || isAguardandoRetirada || isConcluido,
        active: isExecucao,
      ),
      TimelineStep(
        id: '5',
        time: '—',
        date: '—',
        title: 'Pronto para retirada',
        desc: 'Aguardando cliente',
        done: isConcluido,
        active: isAguardandoRetirada,
      ),
    ];
  }

  List<TimelineStep> _generateTimelineAgendamento(Map<String, dynamic> agend) {
    final agendadoPara = agend['agendado_para'] as String?;
    String dataStr = '—';
    String horaStr = '—';
    if (agendadoPara != null) {
      try {
        final dt = DateTime.parse(agendadoPara).toLocal();
        dataStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
        horaStr = '${dt.hour.toString().padLeft(2, '0')}:00';
      } catch (_) {}
    }

    return [
      TimelineStep(id: '1', time: horaStr, date: dataStr, title: 'Agendamento confirmado', desc: 'Aguardando atendimento na oficina', done: true, active: false),
      TimelineStep(id: '2', time: '—', date: '—', title: 'Veículo recebido', desc: 'Check-in na oficina', done: false, active: true),
      TimelineStep(id: '3', time: '—', date: '—', title: 'Diagnóstico e orçamento', desc: 'Aguardando análise do mecânico', done: false, active: false),
      TimelineStep(id: '4', time: '—', date: '—', title: 'Serviço em execução', desc: 'Mecânico trabalhando...', done: false, active: false),
      TimelineStep(id: '5', time: '—', date: '—', title: 'Pronto para retirada', desc: 'Aguardando cliente', done: false, active: false),
    ];
  }
}
