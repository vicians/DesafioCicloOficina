import { ChatGoogle } from '@langchain/google';
import dotenv from 'dotenv';

dotenv.config();

const apiKey = process.env.GOOGLE_API_KEY;
const modelName = process.env.AI_MODEL;

if (!apiKey || !modelName) {
  throw new Error('Configuração de modelo incompleta. Defina GOOGLE_API_KEY e AI_MODEL.');
}

const model = new ChatGoogle({
  apiKey,
  model: modelName,
  temperature: 0.3,
  maxRetries: 1,
});

const chat_model = model.withConfig({
  runName: 'TiaoApp_AI',
  timeout: 15000,
});

export { chat_model, model };