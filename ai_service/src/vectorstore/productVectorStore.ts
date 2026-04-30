import { ChromaClient, Collection } from 'chromadb';

const COLLECTION_NAME = 'produtos_oficina';

let _collection: Collection | null = null;

async function getCollection(): Promise<Collection> {
  if (_collection) return _collection;

  const client = new ChromaClient({
    path: process.env.CHROMA_URL ?? 'http://localhost:8000',
  });

  _collection = await client.getOrCreateCollection({
    name: COLLECTION_NAME,
    metadata: { description: 'Peças e insumos da oficina com preços atualizados' },
  });

  return _collection;
}

export interface ProdutoPayload {
  id: string;
  nome: string;
  valor: number;       // em reais (R$)
  quantidade_estoque: number;
  marca?: string;
}

/**
 * Insere ou atualiza um produto no Vector DB.
 * O documento em linguagem natural permite que a IA responda perguntas sobre
 * preços e disponibilidade com contexto atualizado.
 */
export async function upsertProduto(produto: ProdutoPayload): Promise<void> {
  const col = await getCollection();

  const marcaStr = produto.marca ? ` (${produto.marca})` : '';
  const document =
    `${produto.nome}${marcaStr}: preço R$ ${produto.valor.toFixed(2)} por unidade. ` +
    `Estoque atual: ${produto.quantidade_estoque} unidades.`;

  await col.upsert({
    ids: [produto.id],
    documents: [document],
    metadatas: [
      {
        nome: produto.nome,
        marca: produto.marca ?? '',
        valor: produto.valor,
        quantidade_estoque: produto.quantidade_estoque,
      },
    ],
  });
}

/**
 * Busca os produtos mais relevantes para uma query em linguagem natural.
 * Usado para injetar contexto de preços na resposta da IA.
 */
export async function queryProdutos(query: string, nResults = 3): Promise<string[]> {
  try {
    const col = await getCollection();
    const results = await col.query({ queryTexts: [query], nResults });
    return (results.documents[0] ?? []).filter((d): d is string => d !== null);
  } catch {
    return [];
  }
}
