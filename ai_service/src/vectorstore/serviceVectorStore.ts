import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';

export interface ServicoPayload {
  id: string;
  nome: string;
  preco: number;
  descricao?: string;
  duracao_minutos: number;
}

/**
 * Insere ou atualiza um serviço no PGVector.
 */
export async function upsertServico(servico: ServicoPayload): Promise<void> {
  const document =
    `${servico.nome}: serviço de mão de obra. Valor: R$ ${servico.preco.toFixed(2)}. ` +
    (servico.descricao ? `Descrição: ${servico.descricao}. ` : '') +
    `Duração estimada: ${servico.duracao_minutos} minutos.`;

  const embedding = await embeddings.embedQuery(document);
  const metadata = {
    nome: servico.nome,
    preco: servico.preco,
    duracao_minutos: servico.duracao_minutos,
  };

  await prisma.$executeRawUnsafe(`
    INSERT INTO servico_embeddings (id, content, embedding, metadata)
    VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
    ON CONFLICT (id) DO UPDATE SET
      content = EXCLUDED.content,
      embedding = EXCLUDED.embedding,
      metadata = EXCLUDED.metadata
  `, servico.id, document, toSql(embedding), JSON.stringify(metadata));
}

/**
 * Busca os serviços mais relevantes para uma query.
 */
export async function queryServicos(query: string, nResults = 3): Promise<string[]> {
  try {
    const embedding = await embeddings.embedQuery(query);
    
    const results = await prisma.$queryRawUnsafe<{ content: string }[]>(`
      SELECT content 
      FROM servico_embeddings 
      ORDER BY embedding <=> $1::vector 
      LIMIT $2
    `, toSql(embedding), nResults);

    return results.map(r => r.content);
  } catch (error) {
    console.error('Erro na busca vetorial de serviços:', error);
    return [];
  }
}
