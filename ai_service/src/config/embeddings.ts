import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

function getEmbeddingConfig() {
  const baseUrl = process.env.NVIDIA_BASE_URL;
  const apiKey = process.env.NVIDIA_API_KEY;
  const embeddingModel = process.env.EMBEDDING_MODEL;

  if (!baseUrl || !apiKey || !embeddingModel) {
    throw new Error(
      'Configuração de embeddings incompleta. Defina NVIDIA_BASE_URL, NVIDIA_API_KEY e EMBEDDING_MODEL no ai_service/.env.'
    );
  }

  return { baseUrl, apiKey, embeddingModel };
}

/**
 * Adaptado para usar a infraestrutura do NVIDIA NIM.
 * Modelos como o E5 exigem o parâmetro 'input_type' (query ou passage).
 */

export const embeddings = {
  async embedQuery(text: string): Promise<number[]> {
    const { baseUrl, apiKey, embeddingModel } = getEmbeddingConfig();
    const response = await axios.post(
      `${baseUrl}/embeddings`,
      {
        input: [text],
        model: embeddingModel,
        input_type: 'query'
      },
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }
    );
    return response.data.data[0].embedding;
  },

  async embedDocuments(texts: string[]): Promise<number[][]> {
    const { baseUrl, apiKey, embeddingModel } = getEmbeddingConfig();
    const response = await axios.post(
      `${baseUrl}/embeddings`,
      {
        input: texts,
        model: embeddingModel,
        input_type: 'passage'
      },
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }
    );
    return response.data.data.map((d: any) => d.embedding);
  }
};