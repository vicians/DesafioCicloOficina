export interface OrcamentoDTO {
  id: string;
  agendamento_id?: string;
  cliente_id: string;
  funcionario_id?: string;
  status: string;
  valor_total: number;
  valido_ate?: Date;
  criado_em?: Date;
}

export interface CreateOrcamentoDTO {
  agendamento_id?: string;
  cliente_id: string;
  funcionario_id?: string;
  valido_ate?: Date;
}
