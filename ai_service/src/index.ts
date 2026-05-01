import 'express-async-errors';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import dotenv from 'dotenv';
import axios from 'axios';
import { ChatOpenAI } from '@langchain/openai';
import { upsertProduto, queryProdutos, ProdutoPayload } from './vectorstore/productVectorStore';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

const model = new ChatOpenAI({
  apiKey: process.env.NVIDIA_API_KEY,
  configuration: {
    baseURL: process.env.NVIDIA_BASE_URL,
  },
  modelName: process.env.AI_MODEL,
  temperature: 0.3,
});

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'CicloOficina AI Service',
    model: process.env.AI_MODEL,
  });
});

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

/**
 * Chamado pelo backend sempre que um produto é criado ou atualizado.
 */
app.post('/ai/produtos/sync', async (req: Request, res: Response) => {
  const produto = req.body as Partial<ProdutoPayload>;

  if (!produto.id || !produto.nome) {
    return res.status(400).json({ error: 'id e nome são obrigatórios' });
  }

  await upsertProduto({
    id: produto.id,
    nome: produto.nome,
    valor: produto.valor ?? 0,
    quantidade_estoque: produto.quantidade_estoque ?? 0,
    marca: produto.marca,
  });

  return res.json({
    ok: true,
    message: `Produto "${produto.nome}" indexado no Vector DB`,
  });
});

// ── Análise de mensagem com contexto RAG ──────────────────────────────────────

app.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message, number } = req.body;

  if (!message || !number) {
    return res.status(400).json({ error: 'Mensagem e número são obrigatórios.' });
  }

  try {
    let customer = await prisma.customer.findUnique({
      where: { whatsappNumber: number },
    });

    if (customer?.status === 'HUMAN') {
      return res.json({
        result: null,
        action: 'MANUAL_WAIT',
        info: 'O atendimento está sendo realizado por um humano.',
      });
    }

    const ragDocs = await queryProdutos(message);
    const contextBlock =
      ragDocs.length > 0
        ? `\n\nProdutos e preços disponíveis na oficina:\n${ragDocs.map((d) => `- ${d}`).join('\n')}`
        : '';

    const response = await model.invoke([
      [
        'system',
        `És o assistente virtual da CicloOficina. O teu objetivo é:
1. Identificar se o cliente precisa de Borracharia ou Oficina Mecânica com base no texto.
2. Informar preços de produtos quando solicitado.
3. Quando o cliente confirmar que deseja agendar um serviço, extrair as informações do veículo (placa, descrição do problema) e responder em formato JSON com a seguinte estrutura EXATA (sem texto adicional):
{"action":"CREATE_OS","customerName":"<nome do cliente ou Cliente>","vehiclePlate":"<placa ou null>","description":"<descrição do problema>","serviceType":"<tipo de serviço>"}

Só use o formato JSON acima quando o cliente confirmar explicitamente que quer agendar. Em todos os outros casos, responda normalmente em texto.${contextBlock}`,
      ],
      ['user', message],
    ]);

    const content = String(response.content).trim();

    // Tenta parsear se a IA retornou um CREATE_OS
    try {
      const parsed = JSON.parse(content);
      if (parsed.action === 'CREATE_OS') {
        return res.json({
          result: 'Demanda identificada. Criando ordem de serviço...',
          action: 'CREATE_OS',
          demand: {
            number,
            customerName: parsed.customerName,
            vehiclePlate: parsed.vehiclePlate,
            description: parsed.description,
            serviceType: parsed.serviceType,
          },
        });
      }
    } catch {
      // Não é JSON — resposta textual normal
    }

    return res.json({ result: content, action: 'REPLY' });
  } catch (error) {
    console.error('Erro no fluxo do ai_service:', error);
    return res.status(500).json({ error: 'Erro ao processar consulta.' });
  }
});

// ── Sub-Agent: Criação de OS ──────────────────────────────────────────────────

interface CreateOsBody {
  number: string;
  customerName?: string;
  vehiclePlate?: string;
  description: string;
  serviceType?: string;
}

/**
 * Sub-agent responsável por:
 * 1. Localizar ou criar o cliente pelo número WhatsApp
 * 2. Localizar ou criar o veículo pela placa
 * 3. Atribuir um mecânico disponível
 * 4. Criar o agendamento (próximo dia útil às 09h)
 * 5. Criar o orçamento (rascunho) vinculado ao agendamento
 * 6. Gerar um magic link de acesso ao app para o cliente
 */
app.post('/ai/create-os', async (req: Request, res: Response) => {
  const body = req.body as CreateOsBody;
  const { number, customerName, vehiclePlate, description, serviceType } = body;

  if (!number || !description) {
    return res.status(400).json({ error: 'number e description são obrigatórios' });
  }

  // ── 1. Localizar ou criar cliente ─────────────────────────────────────────
  let clienteId: string;
  let clienteTelefone: string = number;

  try {
    const usuariosRes = await axios.get(`${BACKEND_URL}/usuarios`, {
      params: { tipo_id: 2 },
    });
    const todos: any[] = usuariosRes.data ?? [];
    const found = todos.find((u: any) => u.telefone === number);

    if (found) {
      clienteId = found.id;
      console.log(`[OS] Cliente encontrado: ${found.nome} (${clienteId})`);
    } else {
      // Cria novo cliente whatsapp — cpf_cnpj usa o número como identificador único
      const novoCliente = await axios.post(`${BACKEND_URL}/usuarios`, {
        tipo_id: 2,
        cpf_cnpj: number.replace(/\D/g, '').slice(0, 20),
        nome: customerName ?? `Cliente WhatsApp ${number}`,
        telefone: number,
      });
      clienteId = novoCliente.data.id;
      console.log(`[OS] Novo cliente criado: ${clienteId}`);
    }
  } catch (err: any) {
    console.error('[OS] Erro ao buscar/criar cliente:', err.response?.data ?? err.message);
    return res.status(502).json({ error: 'Erro ao localizar cliente no sistema' });
  }

  // ── 2. Localizar ou criar veículo ─────────────────────────────────────────
  let veiculoId: string;

  if (!vehiclePlate) {
    return res.status(400).json({
      error: 'Placa do veículo é obrigatória para criar a OS. Por favor, informe a placa.',
    });
  }

  try {
    const veiculosRes = await axios.get(`${BACKEND_URL}/veiculos`);
    const veiculos: any[] = veiculosRes.data ?? [];
    const veiculoFound = veiculos.find(
      (v: any) => v.placa.toUpperCase() === vehiclePlate.toUpperCase()
    );

    if (veiculoFound) {
      veiculoId = veiculoFound.id;
      console.log(`[OS] Veículo encontrado: ${vehiclePlate} (${veiculoId})`);
    } else {
      const novoVeiculo = await axios.post(`${BACKEND_URL}/veiculos`, {
        cliente_id: clienteId,
        placa: vehiclePlate.toUpperCase(),
        marca: 'Não informado',
        modelo: 'Não informado',
        ano: new Date().getFullYear(),
        quilometragem_atual: 0,
      });
      veiculoId = novoVeiculo.data.id;
      console.log(`[OS] Novo veículo criado: ${vehiclePlate} (${veiculoId})`);
    }
  } catch (err: any) {
    console.error('[OS] Erro ao buscar/criar veículo:', err.response?.data ?? err.message);
    return res.status(502).json({ error: 'Erro ao localizar veículo no sistema' });
  }

  // ── 3. Selecionar mecânico disponível ─────────────────────────────────────
  let mecanicoId: string | null = null;
  let mecanicoNome: string = 'A definir';

  try {
    const mecanicosRes = await axios.get(`${BACKEND_URL}/usuarios`, {
      params: { tipo_id: 3 },
    });
    const mecanicos: any[] = mecanicosRes.data ?? [];
    if (mecanicos.length > 0) {
      mecanicoId = mecanicos[0].id;
      mecanicoNome = mecanicos[0].nome;
      console.log(`[OS] Mecânico atribuído: ${mecanicoNome} (${mecanicoId})`);
    } else {
      console.warn('[OS] Nenhum mecânico disponível — OS criada sem atribuição');
    }
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível buscar mecânicos:', err.message);
  }

  // ── 4. Criar agendamento (próximo dia útil às 09:00) ─────────────────────
  let agendamentoId: string;

  const agendadoPara = nextBusinessDay9am();

  try {
    const agendRes = await axios.post(`${BACKEND_URL}/agendamentos`, {
      cliente_id: clienteId,
      veiculo_id: veiculoId,
      funcionario_id: mecanicoId,
      agendado_para: agendadoPara.toISOString(),
      duracao_total_minutos: 60,
      notas_cliente: `[WhatsApp] ${serviceType ?? ''} — ${description}`.trim(),
    });
    agendamentoId = agendRes.data.id;
    console.log(`[OS] Agendamento criado: ${agendamentoId}`);
  } catch (err: any) {
    console.error('[OS] Erro ao criar agendamento:', err.response?.data ?? err.message);
    return res.status(502).json({ error: 'Erro ao criar agendamento no sistema' });
  }

  // ── 5. Criar orçamento (rascunho) ─────────────────────────────────────────
  let orcamentoId: string;

  try {
    const orcRes = await axios.post(`${BACKEND_URL}/orcamentos`, {
      agendamento_id: agendamentoId,
      cliente_id: clienteId,
      funcionario_id: mecanicoId,
    });
    orcamentoId = orcRes.data.id;
    console.log(`[OS] Orçamento criado: ${orcamentoId}`);
  } catch (err: any) {
    console.error('[OS] Erro ao criar orçamento:', err.response?.data ?? err.message);
    return res.status(502).json({ error: 'Erro ao criar orçamento no sistema' });
  }

  // ── 6. Gerar magic link para o cliente ────────────────────────────────────
  let magicLinkUrl: string | null = null;

  try {
    const mlRes = await axios.post(`${BACKEND_URL}/auth/magic-link`, {
      telefone: clienteTelefone,
    });
    magicLinkUrl = mlRes.data.url;
    console.log(`[OS] Magic link gerado: ${magicLinkUrl}`);
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível gerar magic link:', err.response?.data ?? err.message);
  }

  return res.status(201).json({
    ok: true,
    agendamento_id: agendamentoId,
    orcamento_id: orcamentoId,
    mechanic: { id: mecanicoId, nome: mecanicoNome },
    agendado_para: agendadoPara.toISOString(),
    magic_link_url: magicLinkUrl,
    message: magicLinkUrl
      ? `OS criada com sucesso! Acesse o app pelo link: ${magicLinkUrl}`
      : 'OS criada com sucesso! Entre em contato para obter acesso ao app.',
  });
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function nextBusinessDay9am(): Date {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  while (d.getDay() === 0 || d.getDay() === 6) {
    d.setDate(d.getDate() + 1);
  }
  d.setHours(9, 0, 0, 0);
  return d;
}

// ── Error handler ─────────────────────────────────────────────────────────────

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('AI_SERVICE_ERROR:', err.message);
  res.status(500).json({ error: 'Erro interno no processamento de IA.' });
});

app.listen(PORT, () => {
  console.log(`🚀 AI Service da CicloOficina online na porta ${PORT}`);
});
