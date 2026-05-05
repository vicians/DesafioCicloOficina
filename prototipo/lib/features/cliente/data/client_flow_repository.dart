import 'package:flutter/foundation.dart';
import 'models/client_models.dart';

abstract class ClientFlowRepository extends ChangeNotifier {
  Future<ServiceModel?> fetchCurrentService();
  Future<List<HistoryItem>> fetchServiceHistory();
  Future<void> approveBudget(String budgetId);
  Future<void> createVeiculo(String marca, String modelo, String placa, int ano);
  Future<String> fetchProfileName();
  Future<List<Map<String, dynamic>>> fetchVehicles();
}
