import 'express-async-errors';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
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

/**
 * Exemplo de Rota de Triagem: 
 * Recebe o texto do WhatsApp e devolve uma análise inicial.
 */
app.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message } = req.body;

  if (!message) {
    return res.status(400).json({ error: "A mensagem é obrigatória." });
  }

  const response = await model.invoke([
    ["system", "És o assistente virtual da CicloOficina. O teu objetivo é identificar se o cliente precisa de Borracharia ou Oficina Mecânica com base no texto."],
    ["user", message]
  ]);

  return res.json({
    result: response.content
  });
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