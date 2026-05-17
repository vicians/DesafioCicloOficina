import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';
import type { AgendamentoPayload } from '../schemas/ai_schemas';

export async function upsertAgendamento(agendamento: AgendamentoPayload): Promise<void> {
  const dataFormatada = new Date(agendamento.agendado_para).toLocaleString('pt-BR');
  const modeloStr = agendamento.veiculo_modelo ? ` (Modelo: ${agendamento.veiculo_modelo})` : '';
  const notasStr = agendamento.notas_cliente ? ` Notas do cliente: ${agendamento.notas_cliente}.` : '';

  const document = 
    `Agendamento para o veículo placa ${agendamento.veiculo_placa}${modeloStr} marcado para ${dataFormatada}. ` +
    `Status atual: ${agendamento.status}.${notasStr}`;

  const embedding = await embeddings.embedQuery(document);
  const metadata = {
    cliente_id: agendamento.cliente_id,
    veiculo_placa: agendamento.veiculo_placa,
    status: agendamento.status,
    agendado_para: agendamento.agendado_para
  };

  await prisma.$executeRawUnsafe(`
    INSERT INTO agendamento_embeddings (id, content, embedding, metadata)
    VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
    ON CONFLICT (id) DO UPDATE SET
      content = EXCLUDED.content,
      embedding = EXCLUDED.embedding,
      metadata = EXCLUDED.metadata
  `, agendamento.id, document, toSql(embedding), JSON.stringify(metadata));
}

export async function queryAgendamentos(cliente_id: string, query: string, nResults = 3): Promise<string[]> {
  try {
    const embedding = await embeddings.embedQuery(query);
    
    // Filtro estrito pelo cliente_id via metadata para segurança (evitar vazamento de dados)
    const results = await prisma.$queryRawUnsafe<{ content: string }[]>(`
      SELECT content 
      FROM agendamento_embeddings 
      WHERE metadata->>'cliente_id' = $1
      ORDER BY embedding <=> $2::vector 
      LIMIT $3
    `, cliente_id, toSql(embedding), nResults);

    return results.map(r => r.content);
  } catch (error) {
    console.error('Erro na busca vetorial de agendamentos:', error);
    return [];
  }
}
