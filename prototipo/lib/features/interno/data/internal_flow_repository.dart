import 'package:flutter/foundation.dart';
import 'models/internal_service.dart';
import 'models/catalogo_servico_item.dart';
import 'models/internal_budget_item.dart';
import 'models/produto_item.dart';

abstract class InternalFlowRepository extends ChangeNotifier {
  Future<List<CatalogoServicoItem>> fetchCatalogoServicos();
  Future<List<ProdutoItem>> fetchProdutos();
  Future<List<InternalBudgetItem>> fetchOrcamentos();
  Future<List<InternalService>> fetchServicos();
  Future<InternalService?> fetchServicoById(String serviceId);
  Future<InternalBudgetItem> updateOrcamento(InternalBudgetItem budget);
  Future<InternalBudgetItem> cancelOrcamento(String budgetId);
  Future<InternalService> approveOrcamento(String budgetId);
  Future<InternalService> updateServicoStatus(String serviceId, String status);
}
