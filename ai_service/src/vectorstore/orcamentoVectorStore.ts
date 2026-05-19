import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';
import type { OrcamentoPayload } from '../schemas/ai_schemas';

export async function upsertOrcamento(orcamento: OrcamentoPayload): Promise<void> {
  const itensStr = orcamento.itens_descricao.length > 0 
    ? ` Itens inclusos: ${orcamento.itens_descricao.join(', ')}.` 
    : '';
  const validadeStr = orcamento.valido_ate 
    ? ` Válido até ${new Date(orcamento.valido_ate).toLocaleDateString('pt-BR')}.` 
    : '';

  const document = 
    `Orçamento no valor total de R$ ${(orcamento.valor_total / 100).toFixed(2)}. ` +
    `Status atual: ${orcamento.status}.${itensStr}${validadeStr}`;

  const embedding = await embeddings.embedQuery(document);
  const metadata = {
    cliente_id: orcamento.cliente_id,
    status: orcamento.status,
    valor_total: orcamento.valor_total
  };

  await prisma.$executeRawUnsafe(`
    INSERT INTO orcamento_embeddings (id, content, embedding, metadata)
    VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
    ON CONFLICT (id) DO UPDATE SET
      content = EXCLUDED.content,
      embedding = EXCLUDED.embedding,
      metadata = EXCLUDED.metadata
  `, orcamento.id, document, toSql(embedding), JSON.stringify(metadata));
}

export async function queryOrcamentos(cliente_id: string, query: string, nResults = 3): Promise<string[]> {
  try {
    const embedding = await embeddings.embedQuery(query);
    
    const results = await prisma.$queryRawUnsafe<{ content: string }[]>(`
      SELECT content 
      FROM orcamento_embeddings 
      WHERE metadata->>'cliente_id' = $1
      ORDER BY embedding <=> $2::vector 
      LIMIT $3
    `, cliente_id, toSql(embedding), nResults);

    return results.map(r => r.content);
  } catch (error) {
    console.error('Erro na busca vetorial de orçamentos:', error);
    return [];
  }
}
