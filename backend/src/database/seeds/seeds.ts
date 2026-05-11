import { getDb } from '../../config/database';
import { PasswordUtils } from '../../utils/passwordUtils';
import * as dotenv from 'dotenv';

dotenv.config();

const adminId    = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
const mecanicoId = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12';
const clienteIds = [
  '0116c28e-c42c-49ec-b955-a97bc867820f', // Gabriela
  '0116c28e-c42c-49ec-b955-a97bc8678210', // Beatriz
  '0116c28e-c42c-49ec-b955-a97bc8678211', // Carlos
  '0116c28e-c42c-49ec-b955-a97bc8678212', // Daniela
  '0116c28e-c42c-49ec-b955-a97bc8678213', // Fábio
  '0116c28e-c42c-49ec-b955-a97bc8678214', // Cliente Teste
];

export const runSeeds = async () => {
  const db = getDb();
  console.log('🚀 Iniciando Seeds de Demonstração...');

  try {
    // 1. Limpeza em ordem respeitando FK
    await db.query(`
      DELETE FROM notifications;
      DELETE FROM mensagens_chat;
      DELETE FROM conversacoes_chat;
      DELETE FROM execucoes_servico;
      DELETE FROM itens_orcamento_servico;
      DELETE FROM itens_orcamento_produto;
      DELETE FROM orcamentos;
      DELETE FROM agendamentos;
      DELETE FROM veiculos;
      DELETE FROM usuarios;
      DELETE FROM catalogo_servicos;
      DELETE FROM produtos;
      DELETE FROM oficinas;
    `);

    // 2. Senhas fixas (Lidas do .env)
    const passAdmin = await PasswordUtils.hash(process.env.ADMIN_SENHA || 'admin_secret_password');
    const passMec   = await PasswordUtils.hash(process.env.MECANICO_SENHA || 'mecanico_secret_password');
    const hashCli   = await PasswordUtils.hash(process.env.CLIENTE_SENHA || 'cliente_secret_password');
    console.log('🔑 Senhas geradas a partir do .env.');

    // 3. Tipos
    await db.query(`INSERT INTO tipos_usuario (id, nome) VALUES (1,'ADMIN'),(2,'CLIENTE'),(3,'MECANICO') ON CONFLICT DO NOTHING`);

    // 4. Usuários internos + oficina
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@omniconnect.com.br';
    const mecEmail = process.env.MECANICO_EMAIL || 'mecanico@omniconnect.com.br';

    await db.query(`
      INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone) VALUES
        ('${adminId}',    1, 'Administrador',  '${adminEmail}', '${passAdmin}', '000', '111'),
        ('${mecanicoId}', 3, 'Mecanico Chefe', '${mecEmail}', '${passMec}',   '111', '222')
    `);
    await db.query(`INSERT INTO oficinas (nome, quantidade_boxes) VALUES ('Tião Oficina Mecânica', 4)`);

    // 5. Clientes
    const clientes = [
      { id: clienteIds[0], nome: 'Gabriela Rocha',  email: 'gabriela@gmail.com' },
      { id: clienteIds[1], nome: 'Beatriz Souza',   email: 'beatriz@gmail.com'  },
      { id: clienteIds[2], nome: 'Carlos Eduardo',  email: 'carlos@gmail.com'   },
      { id: clienteIds[3], nome: 'Daniela Lima',    email: 'daniela@gmail.com'  },
      { id: clienteIds[4], nome: 'Fábio Santos',    email: 'fabio@gmail.com'    },
      { id: clienteIds[5], nome: 'Cliente Teste',   email: 'cliente@gmail.com'  },
    ];
    for (let i = 0; i < clientes.length; i++) {
      const c = clientes[i];
      await db.query(`
        INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone)
        VALUES ('${c.id}', 2, '${c.nome}', '${c.email}', '${hashCli}', 'cpf-00${i}', 'tel-00${i}')
      `);
      console.log(`✅ Cliente: ${c.email}`);
    }

    // 6. Catálogo de Serviços (10 itens)
    const s1  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Troca de Óleo', 18000, 40) RETURNING id`)).rows[0].id;
    const s2  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Revisão Técnica Completa', 35000, 90) RETURNING id`)).rows[0].id;
    const s3  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Alinhamento e Balanceamento', 12000, 60) RETURNING id`)).rows[0].id;
    const s4  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Limpeza de Bico Injetor', 15000, 60) RETURNING id`)).rows[0].id;
    const s5  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Troca de Pastilhas de Freio', 20000, 50) RETURNING id`)).rows[0].id;
    const s6  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Escaneamento Eletrônico', 10000, 30) RETURNING id`)).rows[0].id;
    const s7  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Troca de Correia Dentada', 45000, 120) RETURNING id`)).rows[0].id;
    const s8  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Higienização do Ar-Condicionado', 9000, 45) RETURNING id`)).rows[0].id;
    const s9  = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Troca de Amortecedor', 38000, 90) RETURNING id`)).rows[0].id;
    const s10 = (await db.query(`INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Substituição de Velas de Ignição', 14000, 40) RETURNING id`)).rows[0].id;

    // 7. Produtos (12 itens)
    const p1  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Filtro de Óleo',          'Bosch',    6000,  30,  true, 'Filtros',     'unid.') RETURNING id`)).rows[0].id;
    const p2  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Óleo Sintético 5W40',     'Castrol',  5000, 100,  true, 'Lubrificantes','L')    RETURNING id`)).rows[0].id;
    const p3  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Pastilha de Freio Diant.', 'Bosch',   15000,  20,  true, 'Freios',      'par')  RETURNING id`)).rows[0].id;
    const p4  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Fluido de Freio DOT4',    'Varga',    4000,  50,  true, 'Freios',      'L')    RETURNING id`)).rows[0].id;
    const p5  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Filtro de Ar',            'Fram',     4500,  25,  true, 'Filtros',     'unid.') RETURNING id`)).rows[0].id;
    const p6  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Aditivo para Radiador',   'Paraflu',  3500,  40,  true, 'Refrigeração','L')    RETURNING id`)).rows[0].id;
    const p7  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Correia Dentada Kit',     'Gates',   28000,   8,  true, 'Motor',       'kit')  RETURNING id`)).rows[0].id;
    const p8  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Vela de Ignição',         'NGK',      2500,  60,  true, 'Ignição',     'unid.') RETURNING id`)).rows[0].id;
    const p9  = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Filtro de Combustível',   'Mann',     5500,  15,  true, 'Filtros',     'unid.') RETURNING id`)).rows[0].id;
    const p10 = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Amortecedor Dianteiro',   'Monroe',  32000,   6,  true, 'Suspensão',   'unid.') RETURNING id`)).rows[0].id;
    const p11 = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Fluido de Direção',       'Delphi',   3200,  30,  true, 'Direção',     'L')    RETURNING id`)).rows[0].id;
    const p12 = (await db.query(`INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo, categoria, unidade) VALUES ('Gás Refrigerante R134a',  'DuPont',   8500,   5,  true, 'Ar-Cond.',    'kg')   RETURNING id`)).rows[0].id;

    console.log('✅ Catálogo expandido (10 serviços, 12 produtos)');

    // 8. Veículos
    const v1 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[0]}', 'GAB-2024', 'Honda',     'Civic',    2021) RETURNING id`)).rows[0].id;
    const v2 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[1]}', 'BEA-2019', 'Fiat',      'Uno',      2018) RETURNING id`)).rows[0].id;
    const v3 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[2]}', 'CAR-2022', 'Toyota',    'Corolla',  2020) RETURNING id`)).rows[0].id;
    const v4 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[3]}', 'DAN-2023', 'Jeep',      'Renegade', 2022) RETURNING id`)).rows[0].id;
    const v5 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[4]}', 'FAB-2020', 'Chevrolet', 'Onix',     2019) RETURNING id`)).rows[0].id;
    const v6 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[5]}', 'TST-1234', 'Volkswagen','Golf',     2022) RETURNING id`)).rows[0].id;
    console.log('✅ Veículos registrados');

    // =========================================================
    // 9. CENÁRIOS DE DEMONSTRAÇÃO
    // =========================================================

    // --- Cenário 1: Gabriela — EM EXECUÇÃO (orçamento APROVADO) ---
    const a1 = (await db.query(`
      INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos, notas_cliente)
      VALUES ('${clienteIds[0]}', '${v1}', '${mecanicoId}', 'CONFIRMADO',
              NOW() - interval '2 hours', NOW() + interval '2 hours', 240,
              'Troca de óleo e escaneamento eletrônico') RETURNING id
    `)).rows[0].id;
    const o1 = (await db.query(`
      INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, observacoes, valido_ate)
      VALUES ('${a1}', '${clienteIds[0]}', '${mecanicoId}', 'APROVADO', 49000,
              'Revisão aprovada pelo cliente. Prosseguindo com a troca.', NOW() + interval '7 days') RETURNING id
    `)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o1}','${s1}',1,18000)`);
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o1}','${s6}',1,10000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o1}','${p1}',1,6000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o1}','${p2}',3,5000)`);
    await db.query(`INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em) VALUES ('${o1}','${mecanicoId}','EM_EXECUCAO', NOW() - interval '1 hour')`);

    // Conversa da Gabriela — criar conversacao_chat primeiro para evitar orph
    const conv1 = (await db.query(`
      INSERT INTO conversacoes_chat (cliente_id, ia_pausada) VALUES ('${clienteIds[0]}', true) RETURNING id
    `)).rows[0].id;
    await db.query(`
      INSERT INTO mensagens_chat (conversacao_id, cliente_id, tipo_remetente, conteudo, criado_em) VALUES
        ('${conv1}', '${clienteIds[0]}', 'client',   'Bom dia, meu carro já entrou na oficina?',                                          NOW() - interval '90 minutes'),
        ('${conv1}', '${clienteIds[0]}', 'employee', 'Bom dia! Sim, já está em execução. Fazendo escaneamento e troca de óleo.',           NOW() - interval '85 minutes'),
        ('${conv1}', '${clienteIds[0]}', 'client',   'Perfeito, me avisem quando estiver pronto.',                                        NOW() - interval '80 minutes'),
        ('${conv1}', '${clienteIds[0]}', 'employee', 'Claro! Estimamos concluir em cerca de 1 hora.',                                     NOW() - interval '75 minutes')
    `);
    // Notificações relacionadas ao orçamento aprovado da Gabriela
    await db.query(`
      INSERT INTO notifications (usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo, lida) VALUES
        ('${adminId}',    'approved_budget', 'Orçamento aprovado pelo cliente',
         'Gabriela Rocha aprovou o orçamento e o serviço foi iniciado.', '${o1}', 'orcamento', false),
        ('${mecanicoId}', 'approved_budget', 'Orçamento aprovado pelo cliente',
         'Gabriela Rocha aprovou o orçamento e o serviço foi iniciado.', '${o1}', 'orcamento', true)
    `);

    // --- Cenário 2: Beatriz — PENDENTE (avaliação, sem orçamento) ---
    const a2 = (await db.query(`
      INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos, notas_cliente)
      VALUES ('${clienteIds[1]}', '${v2}', '${mecanicoId}', 'PENDENTE',
              NOW() + interval '1 day', NOW() + interval '1 day' + interval '45 minutes', 45,
              'Carro fazendo barulho no motor, precisa de avaliação') RETURNING id
    `)).rows[0].id;
    await db.query(`
      INSERT INTO notifications (usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo, lida) VALUES
        ('${adminId}',    'new_appointment', 'Novo agendamento recebido',
         'Beatriz Souza agendou uma avaliação para amanhã.', '${a2}', 'agendamento', false),
        ('${mecanicoId}', 'new_appointment', 'Novo agendamento recebido',
         'Beatriz Souza agendou uma avaliação para amanhã.', '${a2}', 'agendamento', false)
    `);

    // --- Cenário 3: Carlos — CANCELADO com orçamento REJEITADO (histórico) ---
    const a3 = (await db.query(`
      INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos, notas_cliente)
      VALUES ('${clienteIds[2]}', '${v3}', '${mecanicoId}', 'CANCELADO',
              NOW() - interval '3 days', NOW() - interval '3 days' + interval '90 minutes', 90,
              'Revisão completa e alinhamento') RETURNING id
    `)).rows[0].id;
    const o3 = (await db.query(`
      INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, observacoes, valido_ate)
      VALUES ('${a3}', '${clienteIds[2]}', '${mecanicoId}', 'REJEITADO', 65000,
              'Cliente achou caro, cancelou o serviço.', NOW() - interval '1 day') RETURNING id
    `)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o3}','${s2}',1,35000)`);
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o3}','${s3}',1,12000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o3}','${p3}',1,15000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o3}','${p6}',1,3000)`);
    await db.query(`
      INSERT INTO notifications (usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo, lida) VALUES
        ('${adminId}',    'rejected_budget', 'Orçamento recusado pelo cliente',
         'Carlos Eduardo recusou o orçamento de revisão completa.', '${o3}', 'orcamento', true),
        ('${mecanicoId}', 'rejected_budget', 'Orçamento recusado pelo cliente',
         'Carlos Eduardo recusou o orçamento de revisão completa.', '${o3}', 'orcamento', true)
    `);

    // --- Cenário 4: Daniela — ENVIADO (aguardando aprovação do cliente) ---
    const a4 = (await db.query(`
      INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos, notas_cliente)
      VALUES ('${clienteIds[3]}', '${v4}', '${mecanicoId}', 'CONFIRMADO',
              NOW() + interval '3 hours', NOW() + interval '3 hours' + interval '110 minutes', 110,
              'Problema no freio e direção puxando') RETURNING id
    `)).rows[0].id;
    const o4 = (await db.query(`
      INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, observacoes, valido_ate)
      VALUES ('${a4}', '${clienteIds[3]}', '${mecanicoId}', 'ENVIADO', 55000,
              'Pastilhas bastante desgastadas, risco de danificar o disco.', NOW() + interval '7 days') RETURNING id
    `)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o4}','${s3}',1,12000)`);
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o4}','${s5}',1,20000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o4}','${p3}',1,15000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o4}','${p4}',2,4000)`);

    // --- Cenário 5: Fábio — RASCUNHO (mecânico montando orçamento) ---
    const a5 = (await db.query(`
      INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos, notas_cliente)
      VALUES ('${clienteIds[4]}', '${v5}', '${mecanicoId}', 'CONFIRMADO',
              NOW() + interval '2 days', NOW() + interval '2 days' + interval '60 minutes', 60,
              'Luz da injeção acesa e falhando muito') RETURNING id
    `)).rows[0].id;
    const o5 = (await db.query(`
      INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, observacoes, valido_ate)
      VALUES ('${a5}', '${clienteIds[4]}', '${mecanicoId}', 'RASCUNHO', 25000,
              'Testando bicos injetores para confirmar necessidade de troca.', NOW() + interval '7 days') RETURNING id
    `)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o5}','${s6}',1,10000)`);
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o5}','${s4}',1,15000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o5}','${p9}',1,5500)`);

    // --- Cenário 6: Cliente Teste — CONCLUÍDO (histórico completo) ---
    // Agendamento e orçamento marcados como passado para popular histórico e relatórios
    const a6 = (await db.query(`
      INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos, notas_cliente)
      VALUES ('${clienteIds[5]}', '${v6}', '${mecanicoId}', 'CONCLUIDO',
              NOW() - interval '5 days', NOW() - interval '5 days' + interval '120 minutes', 120,
              'Revisão de 40.000km — troca de correia dentada') RETURNING id
    `)).rows[0].id;
    const o6 = (await db.query(`
      INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, observacoes, valido_ate)
      VALUES ('${a6}', '${clienteIds[5]}', '${mecanicoId}', 'APROVADO', 89000,
              'Revisão completa de 40 mil km. Correia dentro do prazo de substituição.', NOW() + interval '2 days') RETURNING id
    `)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o6}','${s7}',1,45000)`);
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o6}','${s2}',1,35000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o6}','${p7}',1,28000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o6}','${p5}',1,4500)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o6}','${p1}',1,6000)`);
    // Execução concluída — popula histórico interno e relatórios
    await db.query(`
      INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em, finalizado_em, notas_internas)
      VALUES ('${o6}', '${mecanicoId}', 'CONCLUIDO',
              NOW() - interval '5 days',
              NOW() - interval '5 days' + interval '110 minutes',
              'Correia substituída dentro do prazo. Revisão geral sem anomalias.')
    `);
    // Notificação de conclusão para o cliente
    await db.query(`
      INSERT INTO notifications (usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo, lida) VALUES
        ('${clienteIds[5]}', 'service_completed', 'Seu veículo está pronto!',
         'O serviço de revisão de 40.000km foi concluído. Pode retirar seu Golf.', '${o6}', 'orcamento', true)
    `);

    console.log('🏁 Seeds finalizados com sucesso!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erro crítico nos seeds:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  runSeeds();
}
