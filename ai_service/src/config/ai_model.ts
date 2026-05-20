import { ChatGoogle } from '@langchain/google';
import { ChatOpenAI } from '@langchain/openai';
import dotenv from 'dotenv';

dotenv.config();

const modelName = process.env.AI_MODEL;
const googleApiKey = process.env.GOOGLE_API_KEY;
const nvidiaApiKey = process.env.NVIDIA_API_KEY;
const nvidiaBaseUrl = process.env.NVIDIA_BASE_URL || 'https://integrate.api.nvidia.com/v1';

if (!modelName) {
  throw new Error('Configuração de modelo incompleta. Defina AI_MODEL.');
}

const model = googleApiKey
  ? new ChatGoogle({
      apiKey: googleApiKey,
      model: modelName,
      temperature: 0.3,
      maxRetries: 1,
    })
  : nvidiaApiKey
    ? new ChatOpenAI({
        apiKey: nvidiaApiKey,
        model: modelName,
        temperature: 0.3,
        maxRetries: 1,
        configuration: {
          baseURL: nvidiaBaseUrl,
        },
      })
    : (() => {
        throw new Error(
          'Configuração de modelo incompleta. Defina GOOGLE_API_KEY (Google) ou NVIDIA_API_KEY (NVIDIA) e AI_MODEL.',
        );
      })();

export { model };