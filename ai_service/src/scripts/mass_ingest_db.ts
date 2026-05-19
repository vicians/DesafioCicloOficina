import { prisma } from '../config/prisma';
import { embeddings } from '../config/embeddings';
import { toSql } from 'pgvector';
import { upsertProduto } from '../vectorstore/productVectorStore';
import { upsertServico } from '../vectorstore/serviceVectorStore';

async function ingestUsuarios() {
  console.log('🔄 Ingerindo usuarios...');
  const usuarios = await prisma.usuarios.findMany();
  for (const user of usuarios) {
    const document = `Cliente/Usuário: ${user.nome}. Contato (telefone/email): ${user.telefone} / ${user.email ?? 'N/A'}. CPF/CNPJ: ${user.cpf_cnpj}.`;
    const vector = await embeddings.embedQuery(document);
    await prisma.$executeRawUnsafe(`
      INSERT INTO usuario_embeddings (id, content, embedding, metadata)
      VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
      ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding, metadata = EXCLUDED.metadata
    `, user.id, document, toSql(vector), JSON.stringify({ nome: user.nome, email: user.email, telefone: user.telefone }));
  }
  console.log(`✅ ${usuarios.length} usuários ingeridos.`);
}

async function ingestOficinas() {
  console.log('🔄 Ingerindo oficinas...');
  const oficinas = await prisma.oficinas.findMany();
  for (const o of oficinas) {
    const document = `Oficina: ${o.nome}. Possui ${o.quantidade_boxes} boxes/vagas para atendimento.`;
    const vector = await embeddings.embedQuery(document);
    await prisma.$executeRawUnsafe(`
      INSERT INTO oficina_embeddings (id, content, embedding, metadata)
      VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
      ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding, metadata = EXCLUDED.metadata
    `, o.id, document, toSql(vector), JSON.stringify({ nome: o.nome }));
  }
  console.log(`✅ ${oficinas.length} oficinas ingeridas.`);
}

async function ingestVeiculos() {
  console.log('🔄 Ingerindo veículos...');
  const veiculos = await prisma.veiculos.findMany();
  for (const v of veiculos) {
    const document = `Veículo Placa ${v.placa}: ${v.marca ?? ''} ${v.modelo ?? ''} ano ${v.ano ?? 'desconhecido'}. KM: ${v.quilometragem_atual ?? 'desconhecida'}.`;
    const vector = await embeddings.embedQuery(document);
    await prisma.$executeRawUnsafe(`
      INSERT INTO veiculo_embeddings (id, content, embedding, metadata)
      VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
      ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding, metadata = EXCLUDED.metadata
    `, v.id, document, toSql(vector), JSON.stringify({ cliente_id: v.cliente_id, placa: v.placa, modelo: v.modelo }));
  }
  console.log(`✅ ${veiculos.length} veículos ingeridos.`);
}

async function ingestMensagens() {
  console.log('🔄 Ingerindo mensagens_chat...');
  const msgs = await prisma.mensagens_chat.findMany();
  let count = 0;
  for (const m of msgs) {
    const remetente = m.tipo_remetente === 'client' ? 'Cliente' : 'Oficina/Atendente';
    const document = `Mensagem no chat enviada por ${remetente}: "${m.conteudo}".`;
    const vector = await embeddings.embedQuery(document);
    await prisma.$executeRawUnsafe(`
      INSERT INTO mensagem_chat_embeddings (id, content, embedding, metadata)
      VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
      ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding, metadata = EXCLUDED.metadata
    `, m.id, document, toSql(vector), JSON.stringify({ cliente_id: m.cliente_id, conversacao_id: m.conversacao_id, tipo_remetente: m.tipo_remetente }));
    count++;
    if (count % 50 === 0) console.log(`   ... ${count} mensagens processadas.`);
  }
  console.log(`✅ ${count} mensagens de chat ingeridas.`);
}

async function ingestConversacoes() {
  console.log('🔄 Ingerindo conversacoes_chat...');
  const convs = await prisma.conversacoes_chat.findMany();
  for (const c of convs) {
    const document = `Conversação de chat ativa. IA Pausada? ${c.ia_pausada ? 'Sim' : 'Não'}.`;
    const vector = await embeddings.embedQuery(document);
    await prisma.$executeRawUnsafe(`
      INSERT INTO conversacao_chat_embeddings (id, content, embedding, metadata)
      VALUES ($1::uuid, $2, $3::vector, $4::jsonb)
      ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding, metadata = EXCLUDED.metadata
    `, c.id, document, toSql(vector), JSON.stringify({ cliente_id: c.cliente_id, ia_pausada: c.ia_pausada }));
  }
  console.log(`✅ ${convs.length} conversações ingeridas.`);
}

import { upsertAgendamento } from '../vectorstore/agendamentoVectorStore';
import { upsertOrcamento } from '../vectorstore/orcamentoVectorStore';
import { upsertExecucao } from '../vectorstore/execucaoServicoVectorStore';

async function ingestAgendamentos() {
  console.log('🔄 Ingerindo agendamentos...');
  const agendamentos = await prisma.agendamentos.findMany({ include: { veiculos: true } });
  for (const ag of agendamentos) {
    await upsertAgendamento({
      id: ag.id,
      cliente_id: ag.cliente_id,
      veiculo_placa: ag.veiculos.placa,
      veiculo_modelo: ag.veiculos.modelo ?? undefined,
      agendado_para: ag.agendado_para.toISOString(),
      status: ag.status,
      notas_cliente: ag.notas_cliente ?? undefined
    });
  }
  console.log(`✅ ${agendamentos.length} agendamentos ingeridos.`);
}

async function ingestOrcamentos() {
  console.log('🔄 Ingerindo orçamentos (agrupando itens)...');
  const orcamentos = await prisma.orcamentos.findMany({
    include: {
      itens_orcamento_produto: { include: { produtos: true } },
      itens_orcamento_servico: { include: { catalogo_servicos: true } }
    }
  });

  for (const orc of orcamentos) {
    const itensServico = orc.itens_orcamento_servico.map(i => `${i.quantidade}x ${i.catalogo_servicos.nome}`);
    const itensProduto = orc.itens_orcamento_produto.map(i => `${i.quantidade}x ${i.produtos.nome}`);
    const todosItens = [...itensServico, ...itensProduto];

    await upsertOrcamento({
      id: orc.id,
      cliente_id: orc.cliente_id,
      status: orc.status,
      valor_total: orc.valor_total,
      valido_ate: orc.valido_ate ? orc.valido_ate.toISOString() : undefined,
      itens_descricao: todosItens
    });
  }
  console.log(`✅ ${orcamentos.length} orçamentos ingeridos (com itens embutidos).`);
}

async function ingestExecucoes() {
  console.log('🔄 Ingerindo execucoes_servico...');
  const execucoes = await prisma.execucoes_servico.findMany({ include: { orcamentos: true } });
  for (const ex of execucoes) {
    await upsertExecucao({
      id: ex.id,
      orcamento_id: ex.orcamento_id,
      cliente_id: ex.orcamentos.cliente_id,
      status: ex.status,
      iniciado_em: ex.iniciado_em ? ex.iniciado_em.toISOString() : undefined,
      notas_internas: ex.notas_internas ?? undefined
    });
  }
  console.log(`✅ ${execucoes.length} execuções de serviço ingeridas.`);
}

async function ingest_produtos() {
  console.log('🔄 Ingerindo produtos...');
  const produtos_ativos = await prisma.produtos.findMany({
    where: { ativo: true }
  });
  for (const produto of produtos_ativos) {
    await upsertProduto({
      id: produto.id,
      nome: produto.nome,
      marca: produto.marca || undefined,
      valor: produto.valor / 100,
      quantidade_estoque: produto.quantidade_estoque
    });
  }
  console.log(`✅ ${produtos_ativos.length} produtos ingeridos.`);
}

async function ingest_servicos() {
  console.log('🔄 Ingerindo serviços...');
  const servicos_ativos = await prisma.catalogo_servicos.findMany({
    where: { ativo: true }
  });
  for (const servico of servicos_ativos) {
    await upsertServico({
      id: servico.id,
      nome: servico.nome,
      preco: servico.preco / 100,
      descricao: servico.descricao || undefined,
      duracao_minutos: servico.duracao_minutos
    });
  }
  console.log(`✅ ${servicos_ativos.length} serviços ingeridos.`);
}

async function main() {
  try {
    console.log('🚀 Iniciando script de ingestão em massa...');
    
    await ingestUsuarios();
    await ingestOficinas();
    await ingestVeiculos();
    await ingestConversacoes();
    await ingestMensagens();
    
    // Novas Ingestões Agrupadas
    await ingestAgendamentos();
    await ingestOrcamentos();
    await ingestExecucoes();
    await ingest_produtos();
    await ingest_servicos();

    console.log('🎉 Ingestão concluída com sucesso!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Falha na ingestão:', err);
    process.exit(1);
  }
}

main();
