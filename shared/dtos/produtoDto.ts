export interface ProdutoDTO {
  id: string;
  nome: string;
  marca?: string;
  valor: number;
  quantidade_estoque: number;
  ativo: boolean;
}

export interface CreateProdutoDTO {
  nome: string;
  marca?: string;
  valor: number;
  quantidade_estoque: number;
}
