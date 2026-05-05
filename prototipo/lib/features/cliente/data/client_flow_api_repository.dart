import 'dart:convert';
import 'package:http/http.dart' as http;
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
      // 1. Tentar buscar execução ativa (em andamento)
      final execResp = await http.get(Uri.parse('$baseUrl/execucoes'));
      if (execResp.statusCode == 200) {
        final List execs = jsonDecode(execResp.body);
        // Filtrar execuções deste cliente que não estão concluídas/canceladas
        final activeExec = execs.firstWhere(
          (e) => e['cliente_id'] == clientId && e['status'] != 'concluido' && e['status'] != 'cancelado',
          orElse: () => null,
        );

        if (activeExec != null) {
          return _mapExecToServiceModel(activeExec);
        }
      }

      // 2. Se não houver execução, buscar orçamentos pendentes
      final orcResp = await http.get(Uri.parse('$baseUrl/orcamentos'));
      if (orcResp.statusCode == 200) {
        final List orcs = jsonDecode(orcResp.body);
        final pendingOrc = orcs.firstWhere(
          (o) => o['cliente_id'] == clientId && o['status'] == 'enviado',
          orElse: () => null,
        );

        if (pendingOrc != null) {
          return _mapOrcToServiceModel(pendingOrc);
        }
      }

      return null;
    } catch (e) {
      print('Erro ao buscar serviço atual: $e');
      return null;
    }
  }

  @override
  Future<List<HistoryItem>> fetchServiceHistory() async {
    try {
      final execResp = await http.get(Uri.parse('$baseUrl/execucoes'));
      if (execResp.statusCode == 200) {
        final List execs = jsonDecode(execResp.body);
        return execs
            .where((e) => e['cliente_id'] == clientId && e['status'] == 'concluido')
            .map<HistoryItem>((e) => HistoryItem(
                  id: e['id'],
                  title: e['servico_resumo'] ?? 'Manutenção',
                  date: e['finalizado_em'] ?? '—',
                  status: 'concluido',
                  total: 'R\$ ${(e['valor_total'] / 100).toStringAsFixed(2).replaceAll('.', ',')}',
                ))
            .toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar histórico: $e');
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
    final resp = await http.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/aprovar'),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao aprovar orçamento: ${resp.body}');
    }
    notifyListeners();
  }

  @override
  Future<String> fetchProfileName() async {
    final response = await http.get(Uri.parse('$baseUrl/usuarios/$clientId'));
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
      car: orc['veiculo_modelo'] ?? 'Veículo',
      plate: orc['veiculo_placa'] ?? '—',
      status: 'orcamento',
      title: 'Orçamento para aprovação',
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

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  int _calculateProgress(String status) {
    final s = status.toLowerCase();
    switch (s) {
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
    final status = data['status'];
    return [
      TimelineStep(id: '1', time: '08:00', date: 'Hoje', title: 'Veículo recebido', desc: 'Check-in realizado', done: true, active: false),
      TimelineStep(id: '2', time: '09:30', date: 'Hoje', title: 'Diagnóstico concluído', desc: 'Aguardando orçamento', done: true, active: false),
      TimelineStep(id: '3', time: '10:15', date: 'Hoje', title: 'Orçamento enviado', desc: 'Aguardando aprovação', done: status != 'orcamento', active: status == 'orcamento'),
      TimelineStep(id: '4', time: '—', date: '—', title: 'Serviço em execução', desc: 'Mecânico trabalhando...', done: status == 'revisao' || status == 'aguardando_retirada' || status == 'concluido', active: status == 'andamento'),
      TimelineStep(id: '5', time: '—', date: '—', title: 'Pronto para retirada', desc: 'Aguardando cliente', done: status == 'concluido', active: status == 'aguardando_retirada'),
    ];
  }
}
