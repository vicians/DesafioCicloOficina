/**
 * Configurações de estratégia para fragmentação de documentos (Splitting).
 * Centralizado para permitir testes de performance e precisão (RAG).
 */

export interface SplittingStrategy {
  chunkSize: number;
  chunkOverlap: number;
}

export const INGESTION_CONFIG = {
  // Estratégia padrão para documentos técnicos e manuais
  default: {
    chunkSize: 1000,
    chunkOverlap: 200,
  } as SplittingStrategy,

  // Estratégia focada em blocos menores para maior precisão semântica
  granular: {
    chunkSize: 500,
    chunkOverlap: 100,
  } as SplittingStrategy,

  // Estratégia para documentos longos onde o contexto estendido é necessário
  largeContext: {
    chunkSize: 2000,
    chunkOverlap: 400,
  } as SplittingStrategy,
};

/**
 * Retorna a estratégia ativa. Pode ser expandido para ler de variáveis de ambiente.
 */
export function getActiveStrategy(): SplittingStrategy {
  const strategyName = process.env.RAG_SPLITTING_STRATEGY || 'default';
  return (INGESTION_CONFIG as any)[strategyName] || INGESTION_CONFIG.default;
}
