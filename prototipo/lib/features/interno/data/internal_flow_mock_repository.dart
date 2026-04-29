import '../../../data/mock_data.dart';
import 'internal_flow_repository.dart';
import 'models/internal_budget_item.dart';

class InternalFlowMockRepository extends InternalFlowRepository {
  final List<InternalBudgetItem> _budgets = [];
  final List<InternalService> _services = [];

  InternalFlowMockRepository() {
    _seedData();
  }

  void _seedData() {
    for (final svc in internalServices) {
      if (svc.status == 'orcamento') {
        _budgets.add(
          InternalBudgetItem(
            id: svc.id,
            client: svc.client,
            car: svc.car,
            plate: svc.plate,
            description: svc.service,
            value: svc.value,
            createdAt: svc.openedAt,
          ),
        );
      } else {
        _services.add(svc);
      }
    }

    _budgets.addAll(const [
      InternalBudgetItem(
        id: 'ORC-101',
        client: 'Juliana Moraes',
        car: 'Hyundai Creta 2022',
        plate: 'QWE-1298',
        description: 'Troca de amortecedores dianteiros',
        value: 890.00,
        createdAt: '27/04/2026',
      ),
      InternalBudgetItem(
        id: 'ORC-102',
        client: 'Lucas Ferreira',
        car: 'Ford Ka 2019',
        plate: 'RTY-7741',
        description: 'Diagnóstico de injeção eletrônica',
        value: 250.00,
        createdAt: '28/04/2026',
      ),
    ]);
  }

  @override
  Future<List<InternalBudgetItem>> fetchOrcamentos() async {
    return List.unmodifiable(_budgets);
  }

  @override
  Future<List<InternalService>> fetchServicos() async {
    return List.unmodifiable(_services);
  }

  @override
  Future<InternalService?> fetchServicoById(String serviceId) async {
    for (final service in _services) {
      if (service.id == serviceId) {
        return service;
      }
    }
    return null;
  }

  @override
  Future<InternalBudgetItem> updateOrcamento(InternalBudgetItem budget) async {
    final index = _budgets.indexWhere((item) => item.id == budget.id);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: ${budget.id}');
    }

    _budgets[index] = budget;
    notifyListeners();
    return _budgets[index];
  }

  @override
  Future<InternalBudgetItem> cancelOrcamento(String budgetId) async {
    final index = _budgets.indexWhere((item) => item.id == budgetId);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: $budgetId');
    }

    _budgets[index] = _budgets[index].copyWith(
      status: 'cancelado',
      canceledAt: _todayDdMmYyyy(),
    );
    notifyListeners();
    return _budgets[index];
  }

  @override
  Future<InternalService> approveOrcamento(String budgetId) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: $budgetId');
    }

    final budget = _budgets.removeAt(index);
    if (budget.isCanceled) {
      throw StateError('Orçamento cancelado não pode ser aprovado: $budgetId');
    }

    final newService = InternalService(
      id: _nextOsId(),
      client: budget.client,
      car: budget.car,
      plate: budget.plate,
      service: budget.description,
      status: 'aguardando',
      mechanic: '—',
      time: '—',
      value: budget.value,
      progress: 0,
      openedAt: _todayDdMmYyyy(),
      finishedAt: null,
    );

    _services.insert(0, newService);
    notifyListeners();
    return newService;
  }

  @override
  Future<InternalService> updateServicoStatus(String serviceId, String status) async {
    final index = _services.indexWhere((service) => service.id == serviceId);
    if (index < 0) {
      throw StateError('OS não encontrada: $serviceId');
    }

    final current = _services[index];
    final updated = current.copyWith(
      status: status,
      progress: _progressForStatus(status),
      finishedAt: _finishedAtForStatus(status, current.finishedAt),
    );

    _services[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<InternalService> addServicoItem(String serviceId, InternalOsItem item) async {
    final index = _services.indexWhere((service) => service.id == serviceId);
    if (index < 0) {
      throw StateError('OS não encontrada: $serviceId');
    }

    final current = _services[index];
    final updatedItems = [...current.osItems, item];
    final baseValue = _baseServiceValue(current);
    final updated = current.copyWith(
      osItems: updatedItems,
      value: baseValue + _totalFromItems(updatedItems),
    );

    _services[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<InternalService> removeServicoItem(String serviceId, String itemId) async {
    final index = _services.indexWhere((service) => service.id == serviceId);
    if (index < 0) {
      throw StateError('OS não encontrada: $serviceId');
    }

    final current = _services[index];
    final updatedItems = current.osItems.where((item) => item.id != itemId).toList();
    final baseValue = _baseServiceValue(current);
    final updated = current.copyWith(
      osItems: updatedItems,
      value: baseValue + _totalFromItems(updatedItems),
    );

    _services[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<InternalService> updateServicoObservacoes(String serviceId, String notes) async {
    final index = _services.indexWhere((service) => service.id == serviceId);
    if (index < 0) {
      throw StateError('OS não encontrada: $serviceId');
    }

    final current = _services[index];
    final updated = current.copyWith(mechanicNotes: notes.trim());
    _services[index] = updated;
    notifyListeners();
    return updated;
  }

  double _totalFromItems(List<InternalOsItem> items) {
    var total = 0.0;
    for (final item in items) {
      total += item.total;
    }
    return total;
  }

  double _baseServiceValue(InternalService service) {
    final baseValue = service.value - _totalFromItems(service.osItems);
    return baseValue < 0 ? 0 : baseValue;
  }

  int _progressForStatus(String status) {
    switch (status) {
      case 'aguardando':
        return 0;
      case 'andamento':
        return 55;
      case 'revisao':
        return 85;
      case 'aguardando_retirada':
        return 95;
      case 'concluido':
        return 100;
      case 'cancelado':
        return 0;
      default:
        return 0;
    }
  }

  String? _finishedAtForStatus(String status, String? currentFinishedAt) {
    if (status == 'concluido' || status == 'cancelado') {
      return currentFinishedAt ?? _todayDdMmYyyy();
    }
    return null;
  }

  String _nextOsId() {
    var max = 0;
    for (final svc in _services) {
      final raw = svc.id.replaceFirst('OS-', '');
      final num = int.tryParse(raw);
      if (num != null && num > max) {
        max = num;
      }
    }
    return 'OS-${(max + 1).toString().padLeft(3, '0')}';
  }

  String _todayDdMmYyyy() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    return '$d/$m/$y';
  }
}
