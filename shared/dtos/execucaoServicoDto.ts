import type { ItemOrcamentoDTO } from './itemOrcamentoDto';

export interface ExecucaoServicoDTO {
  id: string;
  orcamento_id: string;
  funcionario_id: string | null;
  status: string;
  iniciado_em: string | null;
  finalizado_em: string | null;
  notas_internas: string | null;
}

export interface ExecucaoServicoDetalhadaDTO extends ExecucaoServicoDTO {
  valor_total: number;
  cliente_nome: string;
  veiculo_marca: string;
  veiculo_modelo: string;
  veiculo_placa: string;
  servicos: ItemOrcamentoDTO[];
  produtos: ItemOrcamentoDTO[];
}
