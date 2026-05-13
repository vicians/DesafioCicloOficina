import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';
import type { ProdutoPayload } from '../schemas/ai_schemas';

/**
 * Insere ou atualiza um produto no PGVector.
 * O documento em linguagem natural permite que a IA responda perguntas sobre
 * preços e disponibilidade com contexto atualizado.
 */

export async function upsertProduto(produto: ProdutoPayload): Promise<void> {
  const marcaStr = produto.marca ? ` (${produto.marca})` : '';
  const document =
    `${produto.nome}${marcaStr}: preço R$ ${produto.valor.toFixed(2)} por unidade. ` +
    `Estoque atual: ${produto.quantidade_estoque} unidades.`;

  const embedding = await embeddings.embedQuery(document);
  const metadata = {
    nome: produto.nome,
    marca: produto.marca ?? '',
    valor: produto.valor,
    quantidade_estoque: produto.quantidade_estoque,
  };

  // Usamos SQL puro para lidar com o tipo 'vector' que o Prisma não suporta nativamente para escrita
  await prisma.$executeRawUnsafe(`
    INSERT INTO produto_embeddings (id, content, embedding, metadata)
    VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
    ON CONFLICT (id) DO UPDATE SET
      content = EXCLUDED.content,
      embedding = EXCLUDED.embedding,
      metadata = EXCLUDED.metadata
  `, produto.id, document, toSql(embedding), JSON.stringify(metadata));
}

/**
 * Busca os produtos mais relevantes para uma query em linguagem natural.
 * Usado para injetar contexto de preços na resposta da IA.
 */
export async function queryProdutos(query: string, nResults = 3): Promise<string[]> {
  try {
    const embedding = await embeddings.embedQuery(query);
    
    // Busca por distância de cosseno (<=>)
    const results = await prisma.$queryRawUnsafe<{ content: string }[]>(`
      SELECT content 
      FROM produto_embeddings 
      ORDER BY embedding <=> $1::vector 
      LIMIT $2
    `, toSql(embedding), nResults);

    return results.map(r => r.content);
  } catch (error) {
    console.error('Erro na busca vetorial:', error);
    return [];
  }
}