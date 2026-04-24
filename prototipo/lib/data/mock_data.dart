// Mock data shared by both apps

class TimelineStep {
  final int id;
  final String time;
  final String date;
  final String title;
  final String desc;
  final bool done;
  final bool active;

  const TimelineStep({
    required this.id,
    required this.time,
    required this.date,
    required this.title,
    required this.desc,
    required this.done,
    required this.active,
  });
}

class BudgetItem {
  final String label;
  final double total;
  const BudgetItem({required this.label, required this.total});
}

class ServiceModel {
  final String id;
  final String car;
  final String plate;
  final String status;
  final String title;
  final String mechanic;
  final String mechanicInitials;
  final String startDate;
  final String estimatedEnd;
  final int progress;
  final List<TimelineStep> timeline;
  final List<BudgetItem> budgetItems;
  final double budgetTotal;

  const ServiceModel({
    required this.id,
    required this.car,
    required this.plate,
    required this.status,
    required this.title,
    required this.mechanic,
    required this.mechanicInitials,
    required this.startDate,
    required this.estimatedEnd,
    required this.progress,
    required this.timeline,
    required this.budgetItems,
    required this.budgetTotal,
  });
}

class HistoryItem {
  final String id;
  final String title;
  final String date;
  final String status;
  final String total;
  const HistoryItem({
    required this.id,
    required this.title,
    required this.date,
    required this.status,
    required this.total,
  });
}

class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final String time;
  bool unread;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
  });
}

class InternalService {
  final String id;
  final String client;
  final String car;
  final String plate;
  final String service;
  final String status;
  final String mechanic;
  final String time;
  final double value;
  final int progress;

  const InternalService({
    required this.id,
    required this.client,
    required this.car,
    required this.plate,
    required this.service,
    required this.status,
    required this.mechanic,
    required this.time,
    required this.value,
    required this.progress,
  });
}

class ChatMessage {
  final int id;
  final String from; // 'client' | 'employee' | 'system'
  final String text;
  final String time;
  bool read;

  ChatMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.time,
    required this.read,
  });
}

class PartItem {
  final String id;
  final String name;
  final String category;
  final int qty;
  final int min;
  final String unit;
  final double price;
  final String status; // 'ok' | 'low'

  const PartItem({
    required this.id,
    required this.name,
    required this.category,
    required this.qty,
    required this.min,
    required this.unit,
    required this.price,
    required this.status,
  });
}

class ReportData {
  final String month;
  final double revenue;
  final double revenueGrowth;
  final int services;
  final int servicesGrowth;
  final double avgTicket;
  final double avgTicketGrowth;
  final int pending;
  final List<StatusCount> byStatus;
  final List<TopService> topServices;

  const ReportData({
    required this.month,
    required this.revenue,
    required this.revenueGrowth,
    required this.services,
    required this.servicesGrowth,
    required this.avgTicket,
    required this.avgTicketGrowth,
    required this.pending,
    required this.byStatus,
    required this.topServices,
  });
}

class StatusCount {
  final String label;
  final int value;
  final int total;

  const StatusCount({required this.label, required this.value, required this.total});
}

class TopService {
  final String name;
  final int count;
  final double revenue;

  const TopService({required this.name, required this.count, required this.revenue});
}

// ── Cliente Data ──────────────────────────────────────────────────────────────

final currentService = ServiceModel(
  id: 'OS-2026-089',
  car: 'Honda Civic 2019',
  plate: 'ABC-1234',
  status: 'andamento',
  title: 'Revisão completa + troca de pastilhas',
  mechanic: 'José Ferreira',
  mechanicInitials: 'JF',
  startDate: '22 abr 2026',
  estimatedEnd: 'Hoje, até 17h',
  progress: 65,
  timeline: const [
    TimelineStep(id: 1, time: '08:00', date: '22 abr', title: 'Veículo recebido', desc: 'Check-in realizado na oficina', done: true, active: false),
    TimelineStep(id: 2, time: '09:30', date: '22 abr', title: 'Diagnóstico concluído', desc: 'Pastilhas desgastadas, óleo vencido, filtro de ar sujo', done: true, active: false),
    TimelineStep(id: 3, time: '10:15', date: '22 abr', title: 'Orçamento aprovado', desc: 'Aprovado via app pelo cliente', done: true, active: false),
    TimelineStep(id: 4, time: '14:00', date: '24 abr', title: 'Serviço em execução', desc: 'Troca de óleo e filtros concluída. Iniciando freios...', done: false, active: true),
    TimelineStep(id: 5, time: '—', date: '—', title: 'Revisão final', desc: 'Teste de qualidade e lavagem', done: false, active: false),
    TimelineStep(id: 6, time: '—', date: '—', title: 'Pronto para retirada', desc: 'Notificação enviada ao cliente', done: false, active: false),
  ],
  budgetItems: const [
    BudgetItem(label: 'Troca de óleo (5W30 sintético)', total: 89.90),
    BudgetItem(label: 'Filtro de óleo', total: 35.00),
    BudgetItem(label: 'Filtro de ar', total: 45.00),
    BudgetItem(label: 'Pastilhas de freio (par diant.)', total: 120.00),
    BudgetItem(label: 'Mão de obra', total: 150.00),
  ],
  budgetTotal: 439.90,
);

final serviceHistory = [
  const HistoryItem(id: 'OS-2026-072', title: 'Alinhamento e balanceamento', date: '10 mar 2026', status: 'concluido', total: 'R\$ 180,00'),
  const HistoryItem(id: 'OS-2026-055', title: 'Troca de pneus (4 unidades)', date: '18 jan 2026', status: 'concluido', total: 'R\$ 1.200,00'),
  const HistoryItem(id: 'OS-2026-031', title: 'Revisão de 40.000 km', date: '05 nov 2025', status: 'concluido', total: 'R\$ 620,00'),
  const HistoryItem(id: 'OS-2026-018', title: 'Troca de bateria', date: '22 ago 2025', status: 'concluido', total: 'R\$ 380,00'),
];

List<NotificationItem> get notificationsData => [
  NotificationItem(id: 1, type: 'progress', title: 'Serviço atualizado', body: 'Trocas de filtros concluídas. Iniciando freios.', time: 'Agora há pouco', unread: true),
  NotificationItem(id: 2, type: 'budget', title: 'Orçamento disponível', body: 'Seu orçamento está pronto para aprovação.', time: '22 abr, 10:10', unread: false),
  NotificationItem(id: 3, type: 'checkin', title: 'Veículo recebido', body: 'Honda Civic ABC-1234 deu entrada na oficina.', time: '22 abr, 08:05', unread: false),
  NotificationItem(id: 4, type: 'done', title: 'Serviço anterior concluído', body: 'Alinhamento e balanceamento finalizado.', time: '10 mar, 17:30', unread: false),
];

// ── Sistema Interno Data ───────────────────────────────────────────────────

final internalServices = [
  const InternalService(id: 'OS-089', client: 'Carlos Mendes', car: 'Honda Civic 2019', plate: 'ABC-1234', service: 'Revisão completa + pastilhas', status: 'andamento', mechanic: 'José', time: '14:00', value: 439.90, progress: 65),
  const InternalService(id: 'OS-090', client: 'Ana Paula Lima', car: 'Toyota Corolla 2021', plate: 'DEF-5678', service: 'Troca de óleo + filtros', status: 'orcamento', mechanic: 'Ricardo', time: '10:30', value: 195.00, progress: 20),
  const InternalService(id: 'OS-091', client: 'Rafael Souza', car: 'Fiat Argo 2022', plate: 'GHI-9012', service: 'Alinhamento e balanceamento', status: 'aguardando', mechanic: '—', time: '—', value: 180.00, progress: 0),
  const InternalService(id: 'OS-092', client: 'Mariana Costa', car: 'VW Polo 2020', plate: 'JKL-3456', service: 'Revisão de 30.000 km', status: 'revisao', mechanic: 'José', time: '16:00', value: 520.00, progress: 85),
  const InternalService(id: 'OS-088', client: 'Pedro Alves', car: 'Chevrolet Onix 2018', plate: 'MNO-7890', service: 'Troca de bateria', status: 'concluido', mechanic: 'Ricardo', time: '11:00', value: 380.00, progress: 100),
];

List<ChatMessage> get chatMessages => [
  ChatMessage(id: 1, from: 'client', text: 'Boa tarde! Meu carro está fazendo um barulho estranho no freio.', time: '08:05', read: true),
  ChatMessage(id: 2, from: 'employee', text: 'Boa tarde, Carlos! Pode trazer para avaliarmos. Disponibilidade hoje?', time: '08:08', read: true),
  ChatMessage(id: 3, from: 'client', text: 'Sim, posso levar agora.', time: '08:12', read: true),
  ChatMessage(id: 4, from: 'system', text: 'Veículo recebido — Honda Civic ABC-1234', time: '08:30', read: true),
  ChatMessage(id: 5, from: 'employee', text: 'Carlos, identificamos pastilhas desgastadas e óleo vencido. Orçamento enviado.', time: '09:35', read: true),
  ChatMessage(id: 6, from: 'client', text: 'Pode fazer tudo. Aprovei o orçamento.', time: '10:18', read: true),
  ChatMessage(id: 7, from: 'system', text: 'Orçamento aprovado pelo cliente — R\$ 439,90', time: '10:18', read: true),
  ChatMessage(id: 8, from: 'employee', text: 'Ótimo! Começando agora. Previsão até 17h.', time: '14:02', read: false),
];

final partsInventory = const [
  PartItem(id: 'P001', name: 'Óleo Motor 5W30 Sintético (1L)', category: 'Lubrificantes', qty: 24, min: 10, unit: 'litro', price: 32.90, status: 'ok'),
  PartItem(id: 'P002', name: 'Filtro de Óleo Universal', category: 'Filtros', qty: 8, min: 10, unit: 'unid.', price: 28.50, status: 'low'),
  PartItem(id: 'P003', name: 'Filtro de Ar Esportivo', category: 'Filtros', qty: 5, min: 8, unit: 'unid.', price: 45.00, status: 'low'),
  PartItem(id: 'P004', name: 'Pastilha de Freio Dianteira', category: 'Freios', qty: 12, min: 6, unit: 'par', price: 89.00, status: 'ok'),
  PartItem(id: 'P005', name: 'Disco de Freio Ventilado', category: 'Freios', qty: 4, min: 4, unit: 'unid.', price: 185.00, status: 'ok'),
  PartItem(id: 'P006', name: 'Bateria 60Ah MF', category: 'Elétrica', qty: 3, min: 5, unit: 'unid.', price: 290.00, status: 'low'),
  PartItem(id: 'P007', name: 'Correia Dentada Kit', category: 'Motor', qty: 7, min: 4, unit: 'kit', price: 210.00, status: 'ok'),
  PartItem(id: 'P008', name: 'Vela de Ignição (jogo 4)', category: 'Motor', qty: 18, min: 8, unit: 'jogo', price: 68.00, status: 'ok'),
];

const reportData = ReportData(
  month: 'Abril 2026',
  revenue: 18420.00,
  revenueGrowth: 12.4,
  services: 42,
  servicesGrowth: 8,
  avgTicket: 438.57,
  avgTicketGrowth: 4.1,
  pending: 3,
  byStatus: [
    StatusCount(label: 'Concluídos', value: 34, total: 42),
    StatusCount(label: 'Em andamento', value: 5, total: 42),
    StatusCount(label: 'Aguardando', value: 3, total: 42),
  ],
  topServices: [
    TopService(name: 'Troca de óleo', count: 18, revenue: 1618.20),
    TopService(name: 'Revisão completa', count: 8, revenue: 4480.00),
    TopService(name: 'Freios', count: 7, revenue: 2240.00),
    TopService(name: 'Alinhamento/balanç.', count: 6, revenue: 1080.00),
    TopService(name: 'Bateria', count: 3, revenue: 1140.00),
  ],
);
