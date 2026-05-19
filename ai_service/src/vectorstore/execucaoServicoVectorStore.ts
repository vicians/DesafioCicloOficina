import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';
import type { ExecucaoServicoPayload } from '../schemas/ai_schemas';

export async function upsertExecucao(execucao: ExecucaoServicoPayload): Promise<void> {
  const iniciadoStr = execucao.iniciado_em 
    ? ` Iniciado em ${new Date(execucao.iniciado_em).toLocaleString('pt-BR')}.` 
    : '';
  const notasStr = execucao.notas_internas 
    ? ` Notas do mecânico: ${execucao.notas_internas}.` 
    : '';

  const document = 
    `Execução de serviço. Status atual: ${execucao.status}.${iniciadoStr}${notasStr}`;

  const embedding = await embeddings.embedQuery(document);
  const metadata = {
    cliente_id: execucao.cliente_id,
    orcamento_id: execucao.orcamento_id,
    status: execucao.status
  };

  await prisma.$executeRawUnsafe(`
    INSERT INTO execucao_servico_embeddings (id, content, embedding, metadata)
    VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
    ON CONFLICT (id) DO UPDATE SET
      content = EXCLUDED.content,
      embedding = EXCLUDED.embedding,
      metadata = EXCLUDED.metadata
  `, execucao.id, document, toSql(embedding), JSON.stringify(metadata));
}

export async function queryExecucoes(cliente_id: string, query: string, nResults = 3): Promise<string[]> {
  try {
    const embedding = await embeddings.embedQuery(query);
    
    const results = await prisma.$queryRawUnsafe<{ content: string }[]>(`
      SELECT content 
      FROM execucao_servico_embeddings 
      WHERE metadata->>'cliente_id' = $1
      ORDER BY embedding <=> $2::vector 
      LIMIT $3
    `, cliente_id, toSql(embedding), nResults);

    return results.map(r => r.content);
  } catch (error) {
    console.error('Erro na busca vetorial de execuções de serviço:', error);
    return [];
  }
}
