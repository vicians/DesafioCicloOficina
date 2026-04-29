import 'package:http/http.dart' as http;
import '../../../data/mock_data.dart';
import 'internal_flow_repository.dart';
import 'models/internal_budget_item.dart';

class InternalFlowApiRepository extends InternalFlowRepository {
  final String baseUrl;
  final http.Client _client;

  InternalFlowApiRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

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
}
