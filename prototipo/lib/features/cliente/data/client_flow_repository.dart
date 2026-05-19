import 'package:flutter/foundation.dart';
import 'models/client_models.dart';

abstract class ClientFlowRepository extends ChangeNotifier {
  Future<ServiceModel?> fetchCurrentService();
  Future<ServiceModel?> fetchServiceById(String execucaoId);
  Future<List<ServiceModel>> fetchPendingBudgets();
  Future<List<HistoryItem>> fetchServiceHistory();
  Future<void> approveBudget(String budgetId);
  Future<void> refuseBudget(String budgetId);
  Future<void> rejectBudgetChange(String budgetId);
  Future<void> cancelService({required String budgetId, String? agendamentoId});
  Future<void> createVeiculo(String marca, String modelo, String placa, int ano);
  Future<String> fetchProfileName();
  Future<List<Map<String, dynamic>>> fetchVehicles();
  void invalidateProfile();
}
