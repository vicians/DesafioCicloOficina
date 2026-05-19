// =========================================================
// Esquemas para o Controller
// =========================================================

interface CreateOsBody {
  number: string;
  customerName?: string;
  vehiclePlate?: string;
  description: string;
  serviceType?: string;
  requestedDate?: string;
}

interface AnalyzeRequestBody {
  message: string;
  number: string;
  conversacaoId?: string;
}

// =========================================================
// Esquemas para o VectorStore
// =========================================================

interface DocumentChunk {
  content: string;
  metadata: Record<string, any>;
  source: string;
  category: 'policy' | 'manual';
}

interface ProdutoPayload {
  id: string;
  nome: string;
  valor: number;
  quantidade_estoque: number;
  marca?: string;
}

interface ServicoPayload {
  id: string;
  nome: string;
  descricao: string;
  preco: number;
  duracao_minutos: number;
}

interface AgendamentoPayload {
  id: string;
  cliente_id: string;
  veiculo_placa: string;
  veiculo_modelo?: string;
  agendado_para: string;
  status: string;
  notas_cliente?: string;
}

interface OrcamentoPayload {
  id: string;
  cliente_id: string;
  status: string;
  valor_total: number;
  valido_ate?: string;
  itens_descricao: string[];
}

interface ExecucaoServicoPayload {
  id: string;
  orcamento_id: string;
  cliente_id: string;
  status: string;
  iniciado_em?: string;
  notas_internas?: string;
}

export { 
  ProdutoPayload, 
  CreateOsBody, 
  AnalyzeRequestBody, 
  ServicoPayload, 
  DocumentChunk,
  AgendamentoPayload,
  OrcamentoPayload,
  ExecucaoServicoPayload
};
