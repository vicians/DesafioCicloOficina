import 'dart:convert';
import 'package:http/http.dart' as http;
import 'internal_flow_repository.dart';
import 'models/catalogo_servico_item.dart';
import 'models/internal_budget_item.dart';
import 'models/produto_item.dart';
import 'models/internal_service.dart';

class InternalFlowApiRepository extends InternalFlowRepository {
  final String baseUrl;
  final http.Client _client;

  String _mapServiceStatusToApi(String status) {
    switch (status.toLowerCase()) {
      case 'aguardando':
      case 'andamento':
      case 'em_execucao':
        return 'EM_EXECUCAO';
      case 'revisao':
      case 'revisao_tecnica':
        return 'REVISAO_TECNICA';
      case 'aguardando_retirada':
        return 'AGUARDANDO_RETIRADA';
      case 'concluido':
        return 'CONCLUIDO';
      case 'cancelado':
        return 'CANCELADO';
      default:
        return status.toUpperCase();
    }
  }

  InternalFlowApiRepository({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<List<CatalogoServicoItem>> fetchCatalogoServicos() async {
    final response = await _client.get(Uri.parse('$baseUrl/servicos'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => CatalogoServicoItem.fromJson(e)).toList();
    }
    throw Exception('Falha ao buscar catálogo de serviços');
  }

  @override
  Future<List<ProdutoItem>> fetchProdutos() async {
    final response = await _client.get(Uri.parse('$baseUrl/produtos'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ProdutoItem.fromJson(e)).toList();
    }
    throw Exception('Falha ao buscar produtos');
  }

  @override
  Future<List<InternalBudgetItem>> fetchOrcamentos() async {
    final response = await _client.get(Uri.parse('$baseUrl/orcamentos'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => InternalBudgetItem.fromJson(e)).toList();
    }
    throw Exception('Falha ao buscar orçamentos');
  }

  @override
  Future<List<InternalService>> fetchServicos() async {
    try {
      // Busca paralela para performance
      final results = await Future.wait([
        _client.get(Uri.parse('$baseUrl/execucoes')),
        _client.get(Uri.parse('$baseUrl/orcamentos')),
        _client.get(Uri.parse('$baseUrl/agendamentos')),
      ]);

      final List<InternalService> allServices = [];
      final executionBudgetIds = <String>{};

      // 1. Processar Execuções
      if (results[0].statusCode == 200) {
        final List data = jsonDecode(results[0].body);
        for (final item in data.cast<Map<String, dynamic>>()) {
          final orcamentoId = item['orcamento_id'] as String?;
          if (orcamentoId != null && orcamentoId.isNotEmpty) {
            executionBudgetIds.add(orcamentoId);
          }
          allServices.add(InternalService.fromJson(item));
        }
      }

      // 2. Processar Orçamentos (apenas os que não viraram execução ainda)
      if (results[1].statusCode == 200) {
        final List data = jsonDecode(results[1].body);
        for (final item in data.cast<Map<String, dynamic>>()) {
          // Evitar duplicidade: se já existe como execução, pula
          final budgetId = item['id'] as String?;
          final status =
              (item['status'] as String? ?? '').toLowerCase();
          final isPendingBudget = status == 'rascunho' || status == 'enviado';

          if (budgetId != null &&
              !executionBudgetIds.contains(budgetId) &&
              isPendingBudget) {
            allServices.add(InternalService.fromJson(item));
          }
        }
      }

      // 3. Processar Agendamentos (abertos para atendimento)
      if (results[2].statusCode == 200) {
        final List data = jsonDecode(results[2].body);
        for (final item in data.cast<Map<String, dynamic>>()) {
          if (item['status'] == 'PENDENTE' || item['status'] == 'CONFIRMADO') {
            allServices.add(InternalService.fromJson(item));
          }
        }
      }

      return allServices;
    } catch (e) {
      throw Exception('Falha ao buscar dados unificados');
    }
  }

  @override
  Future<InternalService?> fetchServicoById(String serviceId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/execucoes/$serviceId'),
    );
    if (response.statusCode == 200) {
      return InternalService.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  @override
  Future<InternalBudgetItem> updateOrcamento(InternalBudgetItem budget) async {
    final detailResponse = await _client.get(
      Uri.parse('$baseUrl/orcamentos/${budget.id}'),
    );
    if (detailResponse.statusCode != 200) {
      throw Exception('Falha ao carregar orçamento para atualização');
    }

    final detail = jsonDecode(detailResponse.body) as Map<String, dynamic>;
    final existingServices =
        (detail['servicos'] as List<dynamic>? ?? detail['itens_servico'] as List<dynamic>? ?? []);
    final existingProducts =
        (detail['produtos'] as List<dynamic>? ?? detail['itens_produto'] as List<dynamic>? ?? []);

    for (final raw in existingServices.cast<Map<String, dynamic>>()) {
      final lineId = raw['id'] as String?;
      if (lineId == null || lineId.isEmpty) {
        continue;
      }
      final response = await _client.delete(
        Uri.parse('$baseUrl/orcamentos/${budget.id}/servicos/$lineId'),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Falha ao remover item de serviço do orçamento');
      }
    }

    for (final raw in existingProducts.cast<Map<String, dynamic>>()) {
      final lineId = raw['id'] as String?;
      if (lineId == null || lineId.isEmpty) {
        continue;
      }
      final response = await _client.delete(
        Uri.parse('$baseUrl/orcamentos/${budget.id}/produtos/$lineId'),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Falha ao remover item de produto do orçamento');
      }
    }

    for (final item in budget.services) {
      final response = await _client.post(
        Uri.parse('$baseUrl/orcamentos/${budget.id}/servicos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'servico_id': item.id,
          'quantidade': item.qty,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Falha ao adicionar serviço no orçamento');
      }
    }

    for (final item in budget.products) {
      final response = await _client.post(
        Uri.parse('$baseUrl/orcamentos/${budget.id}/produtos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'produto_id': item.id,
          'quantidade': item.qty,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Falha ao adicionar produto no orçamento');
      }
    }

    final refreshedResponse = await _client.get(
      Uri.parse('$baseUrl/orcamentos/${budget.id}'),
    );
    if (refreshedResponse.statusCode != 200) {
      throw Exception('Falha ao recarregar orçamento atualizado');
    }

    notifyListeners();
    return InternalBudgetItem.fromJson(
      jsonDecode(refreshedResponse.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<InternalBudgetItem> cancelOrcamento(String budgetId) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/rejeitar'),
    );
    if (response.statusCode != 200) {
      throw Exception('Falha ao cancelar orçamento');
    }

    notifyListeners();
    return InternalBudgetItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<InternalService> approveOrcamento(String budgetId) async {
    // Para aprovação, precisamos passar um valido_ate genérico para o mockup
    final response = await _client.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/aprovar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'valido_ate': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      final res = await _client.get(
        Uri.parse('$baseUrl/execucoes/orcamento/$budgetId'),
      );
      if (res.statusCode == 200) {
        return InternalService.fromJson(jsonDecode(res.body));
      }

      final budgetRes = await _client.get(
        Uri.parse('$baseUrl/orcamentos/$budgetId'),
      );
      return InternalService.fromJson(jsonDecode(budgetRes.body));
    }
    throw Exception('Falha ao aprovar orçamento');
  }

  @override
  Future<InternalService> updateServicoStatus(
    String serviceId,
    String status,
  ) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/execucoes/$serviceId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': _mapServiceStatusToApi(status),
      }),
    );
    if (response.statusCode == 200) {
      final res = await _client.get(
        Uri.parse('$baseUrl/execucoes/$serviceId'),
      );
      if (res.statusCode == 200) {
        notifyListeners();
        return InternalService.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
    }
    throw Exception('Falha ao atualizar status da OS');
  }
}
