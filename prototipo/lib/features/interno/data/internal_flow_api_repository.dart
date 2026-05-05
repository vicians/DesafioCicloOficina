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

  InternalFlowApiRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

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

      // 1. Processar Execuções
      if (results[0].statusCode == 200) {
        final List data = jsonDecode(results[0].body);
        allServices.addAll(data.map((e) => InternalService.fromJson(e)));
      }

      // 2. Processar Orçamentos (apenas os que não viraram execução ainda)
      if (results[1].statusCode == 200) {
        final List data = jsonDecode(results[1].body);
        for (var item in data) {
          // Evitar duplicidade: se já existe como execução, pula
          if (!allServices.any((s) => s.id == item['id'])) {
            allServices.add(InternalService.fromJson(item));
          }
        }
      }

      // 3. Processar Agendamentos (apenas os pendentes)
      if (results[2].statusCode == 200) {
        final List data = jsonDecode(results[2].body);
        for (var item in data) {
           if (item['status'] == 'PENDENTE' || item['status'] == 'ANDAMENTO') {
             // Mapeamento manual básico se necessário, ou usar fromJson se compatível
             allServices.add(InternalService.fromJson(item));
           }
        }
      }

      return allServices;
    } catch (e) {
      print('Erro ao unificar serviços: $e');
      throw Exception('Falha ao buscar dados unificados');
    }
  }

  @override
  Future<InternalService?> fetchServicoById(String serviceId) async {
    final response = await _client.get(Uri.parse('$baseUrl/execucoes/$serviceId'));
    if (response.statusCode == 200) {
      return InternalService.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  @override
  Future<InternalBudgetItem> updateOrcamento(InternalBudgetItem budget) async {
    throw UnsupportedError('Editar orçamento não implementado na UI via API');
  }

  @override
  Future<InternalBudgetItem> cancelOrcamento(String budgetId) async {
    throw UnsupportedError('Cancelar orçamento não implementado via API');
  }

  @override
  Future<InternalService> approveOrcamento(String budgetId) async {
    // Para aprovação, precisamos passar um valido_ate genérico para o mockup
    final response = await _client.patch(
      Uri.parse('$baseUrl/orcamentos/$budgetId/aprovar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'valido_ate': DateTime.now().add(const Duration(days: 7)).toIso8601String()}),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      // Como o backend devolve o Orçamento mas precisamos de um InternalService simulado para a UI...
      // O ideal seria a UI recarregar a lista de execuções. Retornando algo vazio temporário:
      final res = await _client.get(Uri.parse('$baseUrl/orcamentos/$budgetId'));
      return InternalService.fromJson(jsonDecode(res.body)); // Fallback grosseiro
    }
    throw Exception('Falha ao aprovar orçamento');
  }

  @override
  Future<InternalService> updateServicoStatus(String serviceId, String status) async {
    if (status.toLowerCase() == 'concluido') {
      final response = await _client.patch(Uri.parse('$baseUrl/execucoes/$serviceId/finalizar'));
      if (response.statusCode == 200) {
        final res = await _client.get(Uri.parse('$baseUrl/execucoes/$serviceId'));
        return InternalService.fromJson(jsonDecode(res.body));
      }
    }
    throw Exception('Falha ao atualizar status da OS');
  }
}
