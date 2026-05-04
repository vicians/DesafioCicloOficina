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

// Inicialização do Modelo
const model = new ChatOpenAI({
  apiKey: process.env.NVIDIA_API_KEY,
  configuration: {
    baseURL: process.env.NVIDIA_BASE_URL,
  },
  modelName: process.env.AI_MODEL,
  temperature: 0.3,
  maxRetries: 1, // Tenta apenas uma vez para não travar o webhook
}).withConfig({
  runName: "Pistao_Analyze",
  timeout: 15000, // 15 segundos de limite
});

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// ── Rota de Health Check ─────────────────────────────────────────────────────
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'CicloOficina AI Service' });
});

// ── Rota de Sync de Produtos ─────────────────────────────────────────────────
app.post('/ai/produtos/sync', async (req: Request, res: Response) => {
  const produto = req.body as Partial<ProdutoPayload>;
  if (!produto.id || !produto.nome) return res.status(400).json({ error: 'id e nome obrigatórios' });

  await upsertProduto({
    id: produto.id,
    nome: produto.nome,
    valor: produto.valor ?? 0,
    quantidade_estoque: produto.quantidade_estoque ?? 0,
    marca: produto.marca,
  });

  return res.json({ ok: true, message: `Produto "${produto.nome}" indexado.` });
});

// ── Rota Principal: Análise da Mensagem (O Coração do Pistão) ────────────────
app.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message, number } = req.body;

  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

  if (!message || !number) return res.status(400).json({ error: 'Dados ausentes.' });

  try {
    console.log(`[AI Service] 🔍 Verificando status do cliente no banco...`);
    let customer = await prisma.customer.findUnique({ where: { whatsappNumber: number } });

    if (customer?.status === 'HUMAN') {
      console.log(`[AI Service] 👤 Atendimento Humano. Abortando.`);
      return res.json({ result: null, action: 'MANUAL_WAIT' });
    }

    console.log(`[AI Service] 📚 Consultando base de produtos (RAG)...`);
    const ragDocs = await queryProdutos(message);
    const contextBlock = ragDocs.length > 0
      ? `\n\nProdutos na oficina:\n${ragDocs.map((d) => `- ${d}`).join('\n')}`
      : '';

    console.log(`[AI Service] 🤖 Chamando NVIDIA NIM...`);
    const response = await model.invoke([
      ['system', `És o assistente virtual da CicloOficina. Objetivo: 1. Identificar Borracharia ou Mecânica. 2. Informar preços. 3. Para agendamentos, responder EXATAMENTE: {"action":"CREATE_OS","customerName":"<nome>","vehiclePlate":"<placa>","description":"<problema>","serviceType":"<serviço>"}${contextBlock}`],
      ['user', message],
    ]);

    const content = String(response.content).trim();
    console.log(`[AI Service] ✨ IA Respondeu.`);

    try {
      const parsed = JSON.parse(content);
      if (parsed.action === 'CREATE_OS') {
        console.log(`[AI Service] 🛠️ Ação: Criar Ordem de Serviço.`);
        return res.json({
          result: 'Identifiquei que você precisa de um agendamento. Gerando OS...',
          action: 'CREATE_OS',
          demand: { number, ...parsed },
        });
      }
    } catch { /* Não é JSON */ }

    return res.json({ result: content, action: 'REPLY' });
  } catch (error: any) {
    console.error('[AI Service] ❌ Erro:', error.message);
    return res.status(500).json({ error: 'Erro interno.' });
  }
});

// ── Rota de Criação de OS (Sub-Agente) ───────────────────────────────────────
app.post('/ai/create-os', async (req: Request, res: Response) => {
  const { number, customerName, vehiclePlate, description, serviceType } = req.body;
  console.log(`[OS] 📝 Iniciando processo de criação para: ${number}`);

  if (!number || !description || !vehiclePlate) {
    return res.status(400).json({ error: 'Dados insuficientes para criar OS (falta placa ou descrição).' });
  }

  try {
    // 1. Cliente
    let clienteId: string;
    const usuariosRes = await axios.get(`${BACKEND_URL}/usuarios`, { params: { tipo_id: 2 } });
    const found = (usuariosRes.data ?? []).find((u: any) => u.telefone === number);

    if (found) {
      clienteId = found.id;
    } else {
      const novo = await axios.post(`${BACKEND_URL}/usuarios`, {
        tipo_id: 2,
        cpf_cnpj: number.replace(/\D/g, '').slice(0, 20),
        nome: customerName ?? `Cliente WhatsApp ${number}`,
        telefone: number,
      });
      clienteId = novo.data.id;
    }

    // 2. Veículo
    const veiculosRes = await axios.get(`${BACKEND_URL}/veiculos`);
    const vFound = (veiculosRes.data ?? []).find((v: any) => v.placa.toUpperCase() === vehiclePlate.toUpperCase());
    const veiculoId = vFound ? vFound.id : (await axios.post(`${BACKEND_URL}/veiculos`, {
      cliente_id: clienteId,
      placa: vehiclePlate.toUpperCase(),
      marca: 'Não informado', modelo: 'Não informado', ano: new Date().getFullYear(), quilometragem_atual: 0
    })).data.id;

    // 3. Mecânico, Agendamento, Orçamento e Magic Link
    const mecanicos = (await axios.get(`${BACKEND_URL}/usuarios`, { params: { tipo_id: 3 } })).data ?? [];
    const mecanicoId = mecanicos.length > 0 ? mecanicos[0].id : null;
    const agendadoPara = nextBusinessDay9am();

    const agendRes = await axios.post(`${BACKEND_URL}/agendamentos`, {
      cliente_id: clienteId, veiculo_id: veiculoId, funcionario_id: mecanicoId,
      agendado_para: agendadoPara.toISOString(), duracao_total_minutos: 60,
      notas_cliente: `[WhatsApp] ${serviceType ?? ''} — ${description}`.trim(),
    });

    await axios.post(`${BACKEND_URL}/orcamentos`, { agendamento_id: agendRes.data.id, cliente_id: clienteId, funcionario_id: mecanicoId });
    const mlRes = await axios.post(`${BACKEND_URL}/auth/magic-link`, { telefone: number });

    console.log(`[OS] ✅ Sucesso! Link: ${mlRes.data.url}`);
    return res.status(201).json({
      ok: true,
      magic_link_url: mlRes.data.url,
      message: `OS criada com sucesso! Acesse pelo link: ${mlRes.data.url}`
    });

  } catch (err: any) {
    console.error('[OS] ❌ Erro ao criar OS:', err.message);
    return res.status(502).json({ error: 'Falha na integração com o backend.' });
  }
});

// ── Helpers & Error Handler ──────────────────────────────────────────────────
function nextBusinessDay9am(): Date {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
  d.setHours(9, 0, 0, 0);
  return d;
}

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('SERVER_ERROR:', err.message);
  res.status(500).json({ error: 'Erro interno.' });
});

app.listen(PORT, () => console.log(`🚀 AI Service online na porta ${PORT}`));