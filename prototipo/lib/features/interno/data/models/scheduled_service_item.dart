class ScheduledServiceItem {
  final String id;
  final String clienteId;
  final String veiculoId;
  final String? funcionarioId;
  final String clienteNome;
  final String veiculoDescricao;
  final String placa;
  final DateTime agendadoPara;
  final int duracaoMinutos;
  final String status;
  final bool possuiOrcamento;
  final bool possuiExecucao;
  final String? notasCliente;
  final String? orcamentoStatus;
  final bool orcamentoTemItens;

  const ScheduledServiceItem({
    required this.id,
    required this.clienteId,
    required this.veiculoId,
    this.funcionarioId,
    required this.clienteNome,
    required this.veiculoDescricao,
    required this.placa,
    required this.agendadoPara,
    required this.duracaoMinutos,
    required this.status,
    this.possuiOrcamento = false,
    this.possuiExecucao = false,
    this.notasCliente,
    this.orcamentoStatus,
    this.orcamentoTemItens = false,
  });
}
