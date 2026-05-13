export interface VeiculoDTO {
  id: string;
  cliente_id: string;
  placa: string;
  marca?: string;
  modelo?: string;
  ano?: number;
  quilometragem_atual?: number;
  criado_em?: Date;
}

export interface CreateVeiculoDTO {
  cliente_id: string;
  placa: string;
  marca?: string;
  modelo?: string;
  ano?: number;
  quilometragem_atual?: number;
}
