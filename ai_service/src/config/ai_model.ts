import { ChatOpenAI } from '@langchain/openai';
import dotenv from 'dotenv';

dotenv.config();

const apiKey = process.env.OPENROUTER_API_KEY;
const modelName = process.env.AI_MODEL;
const baseURL = process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1';

if (!apiKey || !modelName) {
  throw new Error('Configuração de modelo incompleta. Defina OPENROUTER_API_KEY e AI_MODEL.');
}

const model = new ChatOpenAI({
  apiKey: apiKey,
  openAIApiKey: apiKey,
  modelName: modelName,
  temperature: 0.3,
  maxRetries: 1,
  configuration: {
    baseURL: baseURL,
  },
});

const chat_model = model.withConfig({
  runName: 'TiaoApp_AI',
  timeout: 15000,
});

export { chat_model, model };