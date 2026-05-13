import { prisma } from '../config/prisma';
import { upsertProduto } from '../vectorstore/productVectorStore';
import { upsertServico } from '../vectorstore/serviceVectorStore';

import dotenv from 'dotenv';
dotenv.config();

/**
 * Script para gerar os embeddings de todos os produtos e serviços
 * já cadastrados no banco de dados principal.
 */
async function ingestCatalog() {
  console.log('[Catalog Ingestion] Iniciando geração de embeddings...');

  try {
    // 1. Processar Produtos
    const produtos = await prisma.produtos.findMany({
      where: { ativo: true }
    });
    console.log(`[Catalog Ingestion] Encontrados ${produtos.length} produtos ativos.`);

    for (const p of produtos) {
      console.log(`   -> Processando produto: ${p.nome}`);
      await upsertProduto({
        id: p.id,
        nome: p.nome,
        marca: p.marca || undefined,
        valor: p.valor / 100, // Ajuste se o valor no DB estiver em centavos
        quantidade_estoque: p.quantidade_estoque
      });
    }

    // 2. Processar Serviços
    const servicos = await prisma.catalogo_servicos.findMany({
      where: { ativo: true }
    });
    console.log(`[Catalog Ingestion] Encontrados ${servicos.length} serviços ativos.`);

    for (const s of servicos) {
      console.log(`   -> Processando serviço: ${s.nome}`);
      await upsertServico({
        id: s.id,
        nome: s.nome,
        preco: s.preco / 100, // Ajuste se o valor no DB estiver em centavos
        descricao: s.descricao || undefined,
        duracao_minutos: s.duracao_minutos
      });
    }

    console.log('[Catalog Ingestion] Sucesso! Catálogo de produtos e serviços atualizado.');
    process.exit(0);
  } catch (err) {
    console.error('[Catalog Ingestion] Erro crítico:', err);
    process.exit(1);
  }
}

ingestCatalog();