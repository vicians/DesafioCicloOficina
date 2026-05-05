export interface ProdutoDTO {
  id: string;
  nome: string;
  marca?: string;
  categoria?: string;
  valor: number;
  quantidade_estoque: number;
  min_estoque?: number;
  unidade?: string;
  ativo: boolean;
}

export interface CreateProdutoDTO {
  nome: string;
  marca?: string;
  categoria?: string;
  valor: number;
  quantidade_estoque: number;
  min_estoque?: number;
  unidade?: string;
}
