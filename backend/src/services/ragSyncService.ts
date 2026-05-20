import axios from 'axios';
import type { ProdutoDTO } from '../../../shared/dtos/produtoDto';

const AI_SERVICE_URL = process.env.AI_SERVICE_URL ?? 'http://localhost:3001';

export class RagSyncService {
  /**
   * Envia um produto ao ai_service para que seja indexado no Vector DB (ChromaDB).
   * Fire-and-forget: erros são logados mas não interrompem a resposta ao cliente.
   */
  static syncProduto(produto: ProdutoDTO): void {
    axios
      .post(
        `${AI_SERVICE_URL}/ai/produtos/sync`,
        {
          id: produto.id,
          nome: produto.nome,
          marca: produto.marca,
          valor: produto.valor,
          quantidade_estoque: produto.quantidade_estoque,
        },
        { 
          timeout: 5000,
          headers: { 'X-Internal-Token': process.env.INTERNAL_AUTH_TOKEN }
        },
      )
      .catch((err: Error) => {
        console.warn('[RAG_SYNC] Falha ao sincronizar produto com Vector DB:', err.message);
      });
  }
}
