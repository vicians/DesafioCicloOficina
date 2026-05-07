export interface ItemOrcamentoServicoDTO {
  id: string;
  orcamento_id: string;
  servico_id: string;
  quantidade: number;
  preco_unitario: number;
}

export interface ItemOrcamentoProdutoDTO {
  id: string;
  orcamento_id: string;
  produto_id: string;
  quantidade: number;
  preco_unitario: number;
}
