import 'package:http/http.dart' as http;
import '../../../data/mock_data.dart';
import 'internal_flow_repository.dart';
import 'models/catalogo_servico_item.dart';
import 'models/internal_budget_item.dart';
import 'models/produto_item.dart';

class InternalFlowApiRepository extends InternalFlowRepository {
  final String baseUrl;
  final http.Client _client;

  InternalFlowApiRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<List<CatalogoServicoItem>> fetchCatalogoServicos() async {
    await _client.get(Uri.parse('$baseUrl/servicos'));
    return const [];
  }

  @override
  Future<List<ProdutoItem>> fetchProdutos() async {
    await _client.get(Uri.parse('$baseUrl/produtos'));
    return const [];
  }

  @override
  Future<List<InternalBudgetItem>> fetchOrcamentos() async {
    await _client.get(Uri.parse('$baseUrl/orcamentos'));
    return const [];
  }

  @override
  Future<List<InternalService>> fetchServicos() async {
    await _client.get(Uri.parse('$baseUrl/execucoes'));
    return const [];
  }

  @override
  Future<InternalService?> fetchServicoById(String serviceId) async {
    throw UnsupportedError('Buscar OS por ID via API ainda não implementado.');
  }

  @override
  Future<InternalBudgetItem> updateOrcamento(InternalBudgetItem budget) async {
    throw UnsupportedError('Editar orçamento via API ainda não implementado.');
  }

  @override
  Future<InternalBudgetItem> cancelOrcamento(String budgetId) async {
    throw UnsupportedError('Cancelar orçamento via API ainda não implementado.');
  }

  @override
  Future<InternalService> approveOrcamento(String budgetId) async {
    throw UnsupportedError('Aprovar orçamento via API ainda não implementado.');
  }

  @override
  Future<InternalService> updateServicoStatus(String serviceId, String status) async {
    throw UnsupportedError('Atualizar status da OS via API ainda não implementado.');
  }
}
