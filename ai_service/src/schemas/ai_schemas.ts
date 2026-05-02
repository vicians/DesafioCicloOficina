export interface ProdutoPayload {
  id: string;
  nome: string;
  valor: number;
  quantidade_estoque: number;
  marca?: string;
}

export interface CreateOsBody {
  number: string;
  customerName?: string;
  vehiclePlate?: string;
  description: string;
  serviceType?: string;
}

export interface AnalyzeRequestBody {
  message: string;
  number: string;
}
