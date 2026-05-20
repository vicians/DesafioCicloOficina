import '../../../data/mock_data.dart';
import 'models/internal_service.dart';
import 'internal_flow_repository.dart';
import 'models/catalogo_servico_item.dart';
import 'models/internal_budget_item.dart';
import 'models/produto_item.dart';
import 'models/internal_chat_models.dart';

class InternalFlowMockRepository extends InternalFlowRepository {
  final List<InternalBudgetItem> _budgets = [];
  final List<InternalService> _services = [];
  final Map<String, List<InternalChatMessage>> _messagesByClient = {};

  static const _mockServicos = [
    CatalogoServicoItem(
      id: 'svc-1',
      nome: 'Troca de óleo e filtros',
      preco: 80.00,
    ),
    CatalogoServicoItem(
      id: 'svc-2',
      nome: 'Alinhamento e balanceamento',
      preco: 120.00,
    ),
    CatalogoServicoItem(id: 'svc-3', nome: 'Revisão completa', preco: 350.00),
    CatalogoServicoItem(
      id: 'svc-4',
      nome: 'Substituição de pastilhas',
      preco: 70.00,
    ),
    CatalogoServicoItem(
      id: 'svc-5',
      nome: 'Diagnóstico eletrônico',
      preco: 150.00,
    ),
    CatalogoServicoItem(
      id: 'svc-6',
      nome: 'Troca de amortecedores',
      preco: 200.00,
    ),
  ];

  static const _mockProdutos = [
    ProdutoItem(
      id: 'prd-1',
      nome: 'Óleo Motor 5W30 Sintético (1L)',
      valor: 22.50,
    ),
    ProdutoItem(id: 'prd-2', nome: 'Filtro de Óleo Universal', valor: 35.00),
    ProdutoItem(id: 'prd-3', nome: 'Filtro de Ar Esportivo', valor: 45.00),
    ProdutoItem(
      id: 'prd-4',
      nome: 'Pastilhas de Freio Dianteira (par)',
      valor: 120.00,
    ),
    ProdutoItem(
      id: 'prd-5',
      nome: 'Fluido de Freio DOT4 (500ml)',
      valor: 28.00,
    ),
    ProdutoItem(id: 'prd-6', nome: 'Vela de Ignição NGK', valor: 18.00),
  ];

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
            services: [
              BudgetLineItem(
                id: 'svc-1',
                name: svc.service,
                unitPrice: svc.value,
              ),
            ],
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
        services: [
          BudgetLineItem(
            id: 'svc-6',
            name: 'Troca de amortecedores',
            unitPrice: 200.00,
          ),
        ],
        products: [
          BudgetLineItem(
            id: 'prd-4',
            name: 'Pastilhas de Freio Dianteira (par)',
            unitPrice: 120.00,
            qty: 2,
          ),
        ],
        createdAt: '27/04/2026',
      ),
      InternalBudgetItem(
        id: 'ORC-102',
        client: 'Lucas Ferreira',
        car: 'Ford Ka 2019',
        plate: 'RTY-7741',
        services: [
          BudgetLineItem(
            id: 'svc-5',
            name: 'Diagnóstico eletrônico',
            unitPrice: 150.00,
          ),
        ],
        createdAt: '28/04/2026',
      ),
    ]);
  }

  @override
  Future<List<CatalogoServicoItem>> fetchCatalogoServicos() async {
    return List.unmodifiable(_mockServicos);
  }

  @override
  Future<List<ProdutoItem>> fetchProdutos() async {
    return List.unmodifiable(_mockProdutos);
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
  Future<InternalBudgetItem> sendAddons(String budgetId) async {
    final index = _budgets.indexWhere((item) => item.id == budgetId);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: $budgetId');
    }

    _budgets[index] = _budgets[index].copyWith(status: 'enviado');
    notifyListeners();
    return _budgets[index];
  }

  @override
  Future<InternalBudgetItem> sendBudgetToClient(String budgetId) async {
    final index = _budgets.indexWhere((item) => item.id == budgetId);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: $budgetId');
    }

    _budgets[index] = _budgets[index].copyWith(status: 'enviado');
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
  Future<InternalBudgetItem> approveOrcamento(String budgetId) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: $budgetId');
    }

    if (_budgets[index].isCanceled) {
      throw StateError('Orçamento cancelado não pode ser aprovado: $budgetId');
    }

    _budgets[index] = _budgets[index].copyWith(status: 'aprovado');
    notifyListeners();
    return _budgets[index];
  }

  @override
  Future<InternalService> concludeAgendamento(String budgetId) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index < 0) {
      throw StateError('Orçamento não encontrado: $budgetId');
    }

    final budget = _budgets.removeAt(index);
    final hasItems = budget.services.isNotEmpty || budget.products.isNotEmpty;
    if (budget.status != 'aprovado' && !hasItems) {
      throw StateError('Agendamentos para análise precisam de itens antes de serem concluídos.');
    }

    final newService = InternalService(
      id: _nextOsId(),
      sourceType: 'execucao',
      client: budget.client,
      car: budget.car,
      plate: budget.plate,
      service: budget.services.isNotEmpty ? budget.services.first.name : '—',
      budgetServices: List.of(budget.services),
      budgetProducts: List.of(budget.products),
      employeeObservation: budget.observation,
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
  Future<InternalService> updateServicoStatus(
    String serviceId,
    String status,
  ) async {
    final index = _services.indexWhere((service) => service.id == serviceId);
    if (index < 0) {
      throw StateError('OS não encontrada: $serviceId');
    }

    final current = _services[index];
    final updated = InternalService(
      id: current.id,
      clientId: current.clientId,
      sourceType: current.sourceType,
      client: current.client,
      car: current.car,
      plate: current.plate,
      service: current.service,
      budgetServices: current.budgetServices,
      budgetProducts: current.budgetProducts,
      employeeObservation: current.employeeObservation,
      status: status,
      mechanic: current.mechanic,
      time: current.time,
      value: current.value,
      progress: _progressForStatus(status),
      openedAt: current.openedAt,
      finishedAt: _finishedAtForStatus(status, current.finishedAt),
    );

    _services[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<List<InternalChatMessage>> fetchMensagensCliente(String clientId) async {
    return List.unmodifiable(_messagesByClient[clientId] ?? const []);
  }

  @override
  Future<InternalChatMessage> sendMensagemCliente(String clientId, String text) async {
    final list = _messagesByClient.putIfAbsent(clientId, () => []);
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final message = InternalChatMessage(
      id: now.microsecondsSinceEpoch.toString(),
      from: 'employee',
      text: text,
      time: '$hh:$mm',
      createdAtIso: now.toIso8601String(),
    );
    list.add(message);
    notifyListeners();
    return message;
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
