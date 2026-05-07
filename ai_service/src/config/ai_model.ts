import { ChatOpenAI } from '@langchain/openai';
import dotenv from 'dotenv';

dotenv.config();

const model = new ChatOpenAI({
  apiKey: process.env.NVIDIA_API_KEY,
  configuration: {
    baseURL: process.env.NVIDIA_BASE_URL,
  },
  modelName: process.env.AI_MODEL,
  temperature: 0.3, // Pode ser usado para aumentar a segurança posteriormente
  maxRetries: 1,
});

const chat_model = model.withConfig({
  runName: "TiaoApp_AI",
  timeout: 15000,
});

export { chat_model, model };