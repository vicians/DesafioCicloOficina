import 'express-async-errors';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import dotenv from 'dotenv';
import { ChatOpenAI } from "@langchain/openai";

// 1. Carregar configurações do .env
dotenv.config();

const app = express();

// 2. Middlewares base
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;

// 3. Inicialização da IA (NVIDIA NIM / DeepSeek)
// Focada estritamente em processamento de texto conforme o escopo
const model = new ChatOpenAI({
  apiKey: process.env.NVIDIA_API_KEY,
  configuration: {
    baseURL: process.env.NVIDIA_BASE_URL,
  },
  modelName: process.env.AI_MODEL,
  temperature: 0.3, // Temperatura baixa para maior precisão técnica
});

// 4. Rotas de Monitorização e Processamento
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'CicloOficina AI Service',
    model: process.env.AI_MODEL
  });
});

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

/**
 * Exemplo de Rota de Triagem: 
 * Recebe o texto do WhatsApp e devolve uma análise inicial.
 */
app.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message, number } = req.body; // Recebe o número enviado pelo backend

  if (!message || !number) {
    return res.status(400).json({ error: "Mensagem e número são obrigatórios." });
  }

  try {
    // 1. Consulta o status do cliente no Prisma
    // Certifique-se de que o modelo 'customer' existe no seu schema.prisma
    let customer = await prisma.customer.findUnique({
      where: { whatsappNumber: number }
    });

    // 2. Se o atendimento estiver em modo HUMAN, não processa com IA
    if (customer?.status === 'HUMAN') {
      return res.json({
        result: null,
        action: 'MANUAL_WAIT',
        info: 'O atendimento está sendo realizado por um humano.'
      });
    }

    // 3. Se for BOT (ou cliente novo), processa com a IA
    const response = await model.invoke([
      ["system", "És o assistente virtual da CicloOficina. Teu objetivo é identificar se o cliente precisa de Borracharia ou Oficina Mecânica."],
      ["user", message]
    ]);

    // Opcional: Se a IA detectar que não consegue ajudar, você pode 
    // atualizar o status para HUMAN aqui mesmo.

    return res.json({
      result: response.content,
      action: 'REPLY'
    });

  } catch (error) {
    console.error("Erro no fluxo do ai_service:", error);
    return res.status(500).json({ error: "Erro ao processar consulta." });
  }
});

// 5. Tratamento Global de Erros (usando express-async-errors)
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('AI_SERVICE_ERROR:', err.message);
  res.status(500).json({ error: 'Erro interno no processamento de IA.' });
});

// 6. Iniciar Servidor
app.listen(PORT, () => {
  console.log(`🚀 AI Service da CicloOficina online na porta ${PORT}`);
});