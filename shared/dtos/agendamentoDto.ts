export interface AgendamentoDTO {
  id: string;
  cliente_id: string;
  veiculo_id: string;
  funcionario_id?: string;
  agendado_para: Date;
  duracao_total_minutos: number;
  fim_estimado_em: Date;
  status: string;
  notas_cliente?: string;
  criado_em?: Date;
}

export interface CreateAgendamentoDTO {
  cliente_id: string;
  veiculo_id: string;
  funcionario_id?: string;
  agendado_para: Date;
  duracao_total_minutos: number;
  notas_cliente?: string;
}
