export interface OficinaDTO {
  id: string;
  nome: string;
  quantidade_boxes: number;
  criado_em?: Date;
}

export interface CreateOficinaDTO {
  nome: string;
  quantidade_boxes: number;
}
