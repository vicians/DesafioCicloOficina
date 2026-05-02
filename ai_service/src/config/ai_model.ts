import { ChatOpenAI } from '@langchain/openai';
import dotenv from 'dotenv';

dotenv.config();

export const model = new ChatOpenAI({
  apiKey: process.env.NVIDIA_API_KEY,
  configuration: {
    baseURL: process.env.NVIDIA_BASE_URL,
  },
  modelName: process.env.AI_MODEL,
  temperature: 0.3,
});
