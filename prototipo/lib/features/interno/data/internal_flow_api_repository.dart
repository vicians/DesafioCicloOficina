import 'dart:convert';
import 'package:http/http.dart' as http;
import 'internal_flow_repository.dart';
import 'models/catalogo_servico_item.dart';
import 'models/internal_budget_item.dart';
import 'models/produto_item.dart';
import 'models/internal_service.dart';
import 'models/internal_chat_models.dart';

class InternalFlowApiRepository extends InternalFlowRepository {
  final String baseUrl;
  final http.Client _client;

  String _readErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as String?;
      if (error != null && error.trim().isNotEmpty) {
        return error;
      }
    } catch (_) {}
    return fallback;
  }

  String _mapServiceStatusToApi(String status) {
    switch (status.toLowerCase()) {
      case 'aguardando':
        return 'AGUARDANDO';
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
      final List<InternalService> allServices = [];
      final response = await _client.get(Uri.parse('$baseUrl/execucoes'));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        for (final item in data.cast<Map<String, dynamic>>()) {
          item['flow_type'] = 'execucao';
          allServices.add(InternalService.fromJson(item));
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
        throw Exception(
          _readErrorMessage(response, 'Falha ao adicionar serviço no orçamento'),
        );
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
        throw Exception(
          _readErrorMessage(response, 'Falha ao adicionar produto no orçamento'),
        );
      }
    }

    // Atualiza observações por último para não interromper a persistência de itens/valor.
    final updateBaseRes = await _client.patch(
      Uri.parse('$baseUrl/orcamentos/${budget.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'observacoes': budget.observation,
      }),
    );
    if (updateBaseRes.statusCode != 200) {
      // Não bloqueia o fluxo principal de persistência de itens.
      // A observação pode ser ajustada em tentativa posterior.
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
  Future<InternalBudgetItem> sendAddons(String budgetId) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/enviar-addons'),
    );

    if (response.statusCode != 200) {
      throw Exception(_readErrorMessage(response, 'Falha ao enviar alterações para aprovação do cliente'));
    }

    notifyListeners();
    return InternalBudgetItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
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
    // O endpoint /aprovar agora cria a execucao automaticamente e retorna
    // os dados detalhados da OS gerada (com todos os joins necessários).
    final response = await _client.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/aprovar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'valido_ate': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      }),
    );
    if (response.statusCode == 200) {
      notifyListeners();
      return InternalService.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Falha ao aprovar orçamento');
  }

  @override
  Future<InternalService> updateServicoStatus(
    String serviceId,
    String status,
  ) async {
    if (status.toLowerCase() == 'concluido') {
      final response = await _client.patch(
        Uri.parse('$baseUrl/execucoes/$serviceId/finalizar'),
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
    } else {
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
    }
    throw Exception('Falha ao atualizar status da OS');
  }

  @override
  Future<List<InternalChatMessage>> fetchMensagensCliente(String clientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/chat/clientes/$clientId/mensagens'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body) as List;
      return data
          .cast<Map<String, dynamic>>()
          .map(InternalChatMessage.fromJson)
          .toList();
    }
    throw Exception('Falha ao buscar mensagens do cliente');
  }

  @override
  Future<InternalChatMessage> sendMensagemCliente(String clientId, String text) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/clientes/$clientId/mensagens'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tipo_remetente': 'employee',
        'conteudo': text,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      notifyListeners();
      return InternalChatMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Falha ao enviar mensagem para o cliente');
  }
}
