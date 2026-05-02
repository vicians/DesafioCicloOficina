class ScheduledServiceItem {
  final String id;
  final String clienteNome;
  final String veiculoDescricao;
  final String placa;
  final DateTime agendadoPara;
  final int duracaoMinutos;
  final String status;
  final String? notasCliente;

  const ScheduledServiceItem({
    required this.id,
    required this.clienteNome,
    required this.veiculoDescricao,
    required this.placa,
    required this.agendadoPara,
    required this.duracaoMinutos,
    required this.status,
    this.notasCliente,
  });
}
