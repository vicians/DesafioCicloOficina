import { getDb } from '../../config/database';
import { v4 as uuidv4 } from 'uuid';
import { PasswordUtils } from '../../utils/passwordUtils';
import * as dotenv from 'dotenv';

dotenv.config();

// IDs únicos gerados programaticamente
// IDs fixos para garantir consistência absoluta entre Backend e Frontend
const adminId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
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
    // 1. Limpeza
    await db.query('DELETE FROM mensagens_chat; DELETE FROM execucoes_servico; DELETE FROM itens_orcamento_servico; DELETE FROM itens_orcamento_produto; DELETE FROM orcamentos; DELETE FROM agendamentos; DELETE FROM veiculos; DELETE FROM usuarios; DELETE FROM catalogo_servicos; DELETE FROM produtos; DELETE FROM oficinas;');

    // 2. Senhas Fixas para Garantia Total
    const passAdmin = await PasswordUtils.hash('admin_secret_password');
    const passMec = await PasswordUtils.hash('mecanico_secret_password');
    const passCli = await PasswordUtils.hash('cliente_secret_password');

    console.log('🔑 Senhas geradas com sucesso.');

    // 3. Tipos
    await db.query(`INSERT INTO tipos_usuario (id, nome) VALUES (1, 'ADMIN'), (2, 'CLIENTE'), (3, 'MECANICO') ON CONFLICT DO NOTHING`);

    // 4. Usuários da Loja
    await db.query(`INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone) VALUES 
      ('${adminId}', 1, 'Administrador', 'admin@omniconnect.com.br', '${passAdmin}', '000', '111'),
      ('${mecanicoId}', 3, 'Mecanico Chefe', 'mecanico@omniconnect.com.br', '${passMec}', '111', '222')`);

    // 4.1 Oficina base para exibir nome real na tela interna
    await db.query(`INSERT INTO oficinas (nome, quantidade_boxes) VALUES ('Tião Oficina Mecânica', 4)`);

    // 5. Clientes
    const clientes = [
      { id: clienteIds[0], nome: 'Gabriela Rocha', email: 'gabriela@gmail.com' },
      { id: clienteIds[1], nome: 'Beatriz Souza', email: 'beatriz@gmail.com' },
      { id: clienteIds[2], nome: 'Carlos Eduardo', email: 'carlos@gmail.com' },
      { id: clienteIds[3], nome: 'Daniela Lima', email: 'daniela@gmail.com' },
      { id: clienteIds[4], nome: 'Fábio Santos', email: 'fabio@gmail.com' },
      { id: clienteIds[5], nome: 'Cliente Teste', email: 'cliente@gmail.com' },
    ];

    for (let i = 0; i < clientes.length; i++) {
      const c = clientes[i];
      const hash = await PasswordUtils.hash('cliente_secret_password');
      await db.query(`INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone) 
                      VALUES ('${c.id}', 2, '${c.nome}', '${c.email}', '${hash}', 'cpf-00${i}', 'tel-00${i}')`);
      console.log(`✅ Usuário criado: ${c.email}`);
    }

    // 6. Catálogo de Serviços e Produtos
    const s1 = (await db.query("INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Troca de Óleo', 18000, 40) RETURNING id")).rows[0].id;
    const s2 = (await db.query("INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ('Revisão Técnica', 35000, 90) RETURNING id")).rows[0].id;
    const p1 = (await db.query("INSERT INTO produtos (nome, marca, valor, quantidade_estoque, ativo) VALUES ('Filtro de Óleo', 'Bosch', 6000, 30, true) RETURNING id")).rows[0].id;

    // 7. Veículos
    const v1 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[0]}', 'GAB-2024', 'Honda', 'Civic', 2021) RETURNING id`)).rows[0].id;
    const v2 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[2]}', 'CAR-2022', 'Toyota', 'Corolla', 2020) RETURNING id`)).rows[0].id;
    const v3 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[1]}', 'BEA-2019', 'Fiat', 'Uno', 2018) RETURNING id`)).rows[0].id;

    // 8. Cenário 1: Honda Civic - agendamento CONFIRMADO e execução EM_EXECUCAO atrasada
    const a1 = (await db.query(`INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos)
      VALUES ('${clienteIds[0]}', '${v1}', '${mecanicoId}', 'CONFIRMADO', NOW() - interval '3 days', NOW() - interval '3 days' + interval '120 minutes', 120) RETURNING id`)).rows[0].id;
    const o1 = (await db.query(`INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
      VALUES ('${a1}', '${clienteIds[0]}', '${mecanicoId}', 'APROVADO', 24000, NOW() + interval '7 days') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o1}', '${s1}', 1, 18000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o1}', '${p1}', 1, 6000)`);
    await db.query(`INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em) VALUES ('${o1}', '${mecanicoId}', 'EM_EXECUCAO', NOW() - interval '3 days')`);

    // 9. Cenário 2: Toyota Corolla - agendamento PENDENTE com orçamento RASCUNHO (teste de filtros)
    const a2 = (await db.query(`INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos)
      VALUES ('${clienteIds[2]}', '${v2}', '${mecanicoId}', 'PENDENTE', NOW() + interval '1 day', NOW() + interval '1 day' + interval '90 minutes', 90) RETURNING id`)).rows[0].id;
    const o2 = (await db.query(`INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total)
      VALUES ('${a2}', '${clienteIds[2]}', '${mecanicoId}', 'RASCUNHO', 35000) RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o2}', '${s2}', 1, 35000)`);

    // 10. Cenário 3: Fiat Uno - agendamento CANCELADO sem orçamento (teste de filtros)
    await db.query(`INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos)
      VALUES ('${clienteIds[1]}', '${v3}', '${mecanicoId}', 'CANCELADO', NOW() + interval '2 days', NOW() + interval '2 days' + interval '60 minutes', 60)`);

    // 11. Conversa inicial do cliente da OS em execução para validar a tela de chat integrada
    await db.query(`INSERT INTO mensagens_chat (cliente_id, tipo_remetente, conteudo, criado_em) VALUES
      ('${clienteIds[0]}', 'client', 'Bom dia, meu carro já entrou na oficina?', NOW() - interval '2 hours'),
      ('${clienteIds[0]}', 'employee', 'Bom dia! Sim, o veículo já está em execução e seguimos com a troca de óleo.', NOW() - interval '110 minutes'),
      ('${clienteIds[0]}', 'client', 'Perfeito, me avisem quando estiver pronto para retirada.', NOW() - interval '95 minutes')`);

    // 12. Cenário 4: Cliente Teste - Orçamento ENVIADO para aprovação
    const v4 = (await db.query(`INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano) VALUES ('${clienteIds[5]}', 'TST-1234', 'Volkswagen', 'Golf', 2022) RETURNING id`)).rows[0].id;
    const a4 = (await db.query(`INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, status, agendado_para, fim_estimado_em, duracao_total_minutos)
      VALUES ('${clienteIds[5]}', '${v4}', '${mecanicoId}', 'CONFIRMADO', NOW() + interval '1 day', NOW() + interval '1 day' + interval '60 minutes', 60) RETURNING id`)).rows[0].id;
    const o4 = (await db.query(`INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
      VALUES ('${a4}', '${clienteIds[5]}', '${mecanicoId}', 'ENVIADO', 53000, NOW() + interval '7 days') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario) VALUES ('${o4}', '${s2}', 1, 35000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario) VALUES ('${o4}', '${p1}', 3, 6000)`);

    console.log('🏁 Seeds finalizados! Tente logar com as senhas fixas agora.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erro crítico nos seeds:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  runSeeds();
}
