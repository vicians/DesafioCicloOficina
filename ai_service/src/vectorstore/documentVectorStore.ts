import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';
import { DocumentChunk } from '../schemas/ai_schemas';

/**
 * Insere um fragmento de documento no PGVector.
 */
export async function saveDocumentChunk(chunk: DocumentChunk): Promise<void> {
  const embedding = await embeddings.embedDocuments([chunk.content]);
  
  await prisma.$executeRawUnsafe(`
    INSERT INTO document_embeddings (content, embedding, metadata, source, category)
    VALUES ($1, $2::vector, $3::jsonb, $4, $5)
  `, chunk.content, toSql(embedding[0]), JSON.stringify(chunk.metadata), chunk.source, chunk.category);
}

/**
 * Busca documentos relevantes baseados em uma query.
 */
export async function queryDocuments(
  query: string, 
  category?: 'policy' | 'manual', 
  nResults = 4
): Promise<{ content: string; metadata: any; source: string }[]> {
  try {
    const embedding = await embeddings.embedQuery(query);
    
    let sql = `
      SELECT content, metadata, source 
      FROM document_embeddings 
    `;

    const params: any[] = [toSql(embedding)];

    if (category) {
      sql += ` WHERE category = $2 `;
      params.push(category);
    }

    sql += ` ORDER BY embedding <=> $1::vector LIMIT ${nResults}`;

    const results = await prisma.$queryRawUnsafe<any[]>(sql, ...params);

    return results;
  } catch (error) {
    console.error('Erro na busca vetorial de documentos:', error);
    return [];
  }
}
