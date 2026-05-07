interface ProdutoPayload {
  id: string;
  nome: string;
  valor: number;
  quantidade_estoque: number;
  marca?: string;
}

interface CreateOsBody {
  number: string;
  customerName?: string;
  vehiclePlate?: string;
  description: string;
  serviceType?: string;
}

interface AnalyzeRequestBody {
  message: string;
  number: string;
}

interface ServicoPayload {
  id: string;
  nome: string;
  descricao: string;
  preco: number;
  duracao_minutos: number;
}

export { ProdutoPayload, CreateOsBody, AnalyzeRequestBody, ServicoPayload };