import 'package:flutter/foundation.dart';
import '../../../data/mock_data.dart';
import 'models/internal_budget_item.dart';

abstract class InternalFlowRepository extends ChangeNotifier {
  Future<List<InternalBudgetItem>> fetchOrcamentos();
  Future<List<InternalService>> fetchServicos();
  Future<InternalBudgetItem> updateOrcamento(InternalBudgetItem budget);
  Future<InternalBudgetItem> cancelOrcamento(String budgetId);
  Future<InternalService> approveOrcamento(String budgetId);
}
