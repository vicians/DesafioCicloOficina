import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Adaptado para usar a infraestrutura do NVIDIA NIM.
 * Modelos como o E5 exigem o parâmetro 'input_type' (query ou passage).
 */

export const embeddings = {
  async embedQuery(text: string): Promise<number[]> {
    const response = await axios.post(
      `${process.env.NVIDIA_BASE_URL}/embeddings`,
      {
        input: [text],
        model: process.env.EMBEDDING_MODEL,
        input_type: 'query'
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.NVIDIA_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );
    return response.data.data[0].embedding;
  },

  async embedDocuments(texts: string[]): Promise<number[][]> {
    const response = await axios.post(
      `${process.env.NVIDIA_BASE_URL}/embeddings`,
      {
        input: texts,
        model: process.env.EMBEDDING_MODEL,
        input_type: 'passage'
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.NVIDIA_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );
    return response.data.data.map((d: any) => d.embedding);
  }
};