export interface CatalogoServicoDTO {
  id: string;
  nome: string;
  descricao?: string;
  preco: number;
  duracao_minutos: number;
  ativo: boolean;
}

export interface CreateCatalogoServicoDTO {
  nome: string;
  descricao?: string;
  preco: number;
  duracao_minutos: number;
}
