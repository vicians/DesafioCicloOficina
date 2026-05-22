import { getDb } from '../../config/database';
import { PasswordUtils } from '../../utils/passwordUtils';
import * as dotenv from 'dotenv';

dotenv.config();

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v) throw new Error(`Variável de ambiente obrigatória ausente: ${key}`);
  return v;
}

const env = {
  adminId: requireEnv('ADMIN_ID'),
  adminNome: requireEnv('ADMIN_NOME'),
  adminEmail: requireEnv('ADMIN_EMAIL'),
  adminSenha: requireEnv('ADMIN_SENHA'),
  adminCpf: requireEnv('ADMIN_CPF'),
  adminTel: requireEnv('ADMIN_TELEFONE'),

  mecId: requireEnv('MECANICO_ID'),
  mecNome: requireEnv('MECANICO_NOME'),
  mecEmail: requireEnv('MECANICO_EMAIL'),
  mecSenha: requireEnv('MECANICO_SENHA'),
  mecCpf: requireEnv('MECANICO_CPF'),
  mecTel: requireEnv('MECANICO_TELEFONE'),

  mecanicos: [
    { id: requireEnv('MECANICO2_ID'), nome: requireEnv('MECANICO2_NOME'), email: requireEnv('MECANICO2_EMAIL'), senha: requireEnv('MECANICO2_SENHA'), cpf: requireEnv('MECANICO2_CPF'), tel: requireEnv('MECANICO2_TELEFONE') },
    { id: requireEnv('MECANICO3_ID'), nome: requireEnv('MECANICO3_NOME'), email: requireEnv('MECANICO3_EMAIL'), senha: requireEnv('MECANICO3_SENHA'), cpf: requireEnv('MECANICO3_CPF'), tel: requireEnv('MECANICO3_TELEFONE') },
    { id: requireEnv('MECANICO4_ID'), nome: requireEnv('MECANICO4_NOME'), email: requireEnv('MECANICO4_EMAIL'), senha: requireEnv('MECANICO4_SENHA'), cpf: requireEnv('MECANICO4_CPF'), tel: requireEnv('MECANICO4_TELEFONE') },
  ],

  // Clientes — ordem: Gabriela(6), Beatriz(2), Carlos(3), Daniela(4), Fábio(5), Teste(base)
  clientes: [
    { id: requireEnv('CLIENTE6_ID'), nome: requireEnv('CLIENTE6_NOME'), email: requireEnv('CLIENTE6_EMAIL'), cpf: requireEnv('CLIENTE6_CPF'), tel: requireEnv('CLIENTE6_TELEFONE'), senha: requireEnv('CLIENTE6_SENHA') },
    { id: requireEnv('CLIENTE2_ID'), nome: requireEnv('CLIENTE2_NOME'), email: requireEnv('CLIENTE2_EMAIL'), cpf: requireEnv('CLIENTE2_CPF'), tel: requireEnv('CLIENTE2_TELEFONE'), senha: requireEnv('CLIENTE2_SENHA') },
    { id: requireEnv('CLIENTE3_ID'), nome: requireEnv('CLIENTE3_NOME'), email: requireEnv('CLIENTE3_EMAIL'), cpf: requireEnv('CLIENTE3_CPF'), tel: requireEnv('CLIENTE3_TELEFONE'), senha: requireEnv('CLIENTE3_SENHA') },
    { id: requireEnv('CLIENTE4_ID'), nome: requireEnv('CLIENTE4_NOME'), email: requireEnv('CLIENTE4_EMAIL'), cpf: requireEnv('CLIENTE4_CPF'), tel: requireEnv('CLIENTE4_TELEFONE'), senha: requireEnv('CLIENTE4_SENHA') },
    { id: requireEnv('CLIENTE5_ID'), nome: requireEnv('CLIENTE5_NOME'), email: requireEnv('CLIENTE5_EMAIL'), cpf: requireEnv('CLIENTE5_CPF'), tel: requireEnv('CLIENTE5_TELEFONE'), senha: requireEnv('CLIENTE5_SENHA') },
    { id: requireEnv('CLIENTE_ID'), nome: requireEnv('CLIENTE_NOME'), email: requireEnv('CLIENTE_EMAIL'), cpf: requireEnv('CLIENTE_CPF'), tel: requireEnv('CLIENTE_TELEFONE'), senha: requireEnv('CLIENTE_SENHA') },
  ],
};

export const runSeeds = async () => {
  const db = getDb();
  console.log('🚀 Iniciando Seeds de Demonstração...');

  try {
    await db.query(`
      DELETE FROM notifications; DELETE FROM mensagens_chat; DELETE FROM conversacoes_chat;
      DELETE FROM execucoes_servico; DELETE FROM itens_orcamento_servico; DELETE FROM itens_orcamento_produto;
      DELETE FROM orcamentos; DELETE FROM agendamentos; DELETE FROM veiculos;
      DELETE FROM usuarios; DELETE FROM catalogo_servicos; DELETE FROM produtos; DELETE FROM oficinas;
    `);

    const passAdmin = await PasswordUtils.hash(env.adminSenha);
    const passMec = await PasswordUtils.hash(env.mecSenha);

    await db.query(`INSERT INTO tipos_usuario (id, nome) VALUES (1,'ADMIN'),(2,'CLIENTE'),(3,'MECANICO') ON CONFLICT DO NOTHING`);

    await db.query(`
      INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone) VALUES
        ('${env.adminId}', 1, '${env.adminNome}', '${env.adminEmail}', '${passAdmin}', '${env.adminCpf}', '${env.adminTel}'),
        ('${env.mecId}',   3, '${env.mecNome}',   '${env.mecEmail}',   '${passMec}',   '${env.mecCpf}',   '${env.mecTel}')
    `);
    for (const m of env.mecanicos) {
      const hash = await PasswordUtils.hash(m.senha);
      await db.query(`INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone) VALUES ('${m.id}', 3, '${m.nome}', '${m.email}', '${hash}', '${m.cpf}', '${m.tel}')`);
    }
    await db.query(`INSERT INTO oficinas (nome, quantidade_boxes) VALUES ('Tião Oficina Mecânica', 4)`);

    for (const c of env.clientes) {
      const hash = await PasswordUtils.hash(c.senha);
      await db.query(`
        INSERT INTO usuarios (id, tipo_id, nome, email, senha_hash, cpf_cnpj, telefone)
        VALUES ('${c.id}', 2, '${c.nome}', '${c.email}', '${hash}', '${c.cpf}', '${c.tel}')
      `);
    }

    const cids = env.clientes.map(c => c.id);

    const s1 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Troca de Óleo',18000,40) RETURNING id`)).rows[0].id;
    const s2 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Revisão Técnica Completa',35000,90) RETURNING id`)).rows[0].id;
    const s3 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Alinhamento e Balanceamento',12000,60) RETURNING id`)).rows[0].id;
    const s4 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Limpeza de Bico Injetor',15000,60) RETURNING id`)).rows[0].id;
    const s5 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Troca de Pastilhas de Freio',20000,50) RETURNING id`)).rows[0].id;
    const s6 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Escaneamento Eletrônico',10000,30) RETURNING id`)).rows[0].id;
    const s7 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Troca de Correia Dentada',45000,120) RETURNING id`)).rows[0].id;
    const s8 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Higienização do Ar-Condicionado',9000,45) RETURNING id`)).rows[0].id;
    const s9 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Troca de Amortecedor',38000,90) RETURNING id`)).rows[0].id;
    const s10 = (await db.query(`INSERT INTO catalogo_servicos (nome,preco,duracao_minutos) VALUES ('Substituição de Velas de Ignição',14000,40) RETURNING id`)).rows[0].id;

    const p1 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Filtro de Óleo','Bosch',6000,30,true,'Filtros','unid.') RETURNING id`)).rows[0].id;
    const p2 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Óleo Sintético 5W40','Castrol',5000,100,true,'Lubrificantes','L') RETURNING id`)).rows[0].id;
    const p3 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Pastilha de Freio Diant.','Bosch',15000,20,true,'Freios','par') RETURNING id`)).rows[0].id;
    const p4 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Fluido de Freio DOT4','Varga',4000,50,true,'Freios','L') RETURNING id`)).rows[0].id;
    const p5 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Filtro de Ar','Fram',4500,25,true,'Filtros','unid.') RETURNING id`)).rows[0].id;
    const p6 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Aditivo para Radiador','Paraflu',3500,40,true,'Refrigeração','L') RETURNING id`)).rows[0].id;
    const p7 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Correia Dentada Kit','Gates',28000,8,true,'Motor','kit') RETURNING id`)).rows[0].id;
    const p8 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Vela de Ignição','NGK',2500,60,true,'Ignição','unid.') RETURNING id`)).rows[0].id;
    const p9 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Filtro de Combustível','Mann',5500,15,true,'Filtros','unid.') RETURNING id`)).rows[0].id;
    const p10 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Amortecedor Dianteiro','Monroe',32000,6,true,'Suspensão','unid.') RETURNING id`)).rows[0].id;
    const p11 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Fluido de Direção','Delphi',3200,30,true,'Direção','L') RETURNING id`)).rows[0].id;
    const p12 = (await db.query(`INSERT INTO produtos (nome,marca,valor,quantidade_estoque,ativo,categoria,unidade) VALUES ('Gás Refrigerante R134a','DuPont',8500,5,true,'Ar-Cond.','kg') RETURNING id`)).rows[0].id;

    const v1 = (await db.query(`INSERT INTO veiculos (cliente_id,placa,marca,modelo,ano) VALUES ('${cids[0]}','GAB-2024','Honda','Civic',2021) RETURNING id`)).rows[0].id;
    const v2 = (await db.query(`INSERT INTO veiculos (cliente_id,placa,marca,modelo,ano) VALUES ('${cids[1]}','BEA-2019','Fiat','Uno',2018) RETURNING id`)).rows[0].id;
    const v3 = (await db.query(`INSERT INTO veiculos (cliente_id,placa,marca,modelo,ano) VALUES ('${cids[2]}','CAR-2022','Toyota','Corolla',2020) RETURNING id`)).rows[0].id;
    const v4 = (await db.query(`INSERT INTO veiculos (cliente_id,placa,marca,modelo,ano) VALUES ('${cids[3]}','DAN-2023','Jeep','Renegade',2022) RETURNING id`)).rows[0].id;
    const v5 = (await db.query(`INSERT INTO veiculos (cliente_id,placa,marca,modelo,ano) VALUES ('${cids[4]}','FAB-2020','Chevrolet','Onix',2019) RETURNING id`)).rows[0].id;
    const v6 = (await db.query(`INSERT INTO veiculos (cliente_id,placa,marca,modelo,ano) VALUES ('${cids[5]}','TST-1234','Volkswagen','Golf',2022) RETURNING id`)).rows[0].id;

    // Cenário 1: cids[0] — EM EXECUÇÃO
    const a1 = (await db.query(`INSERT INTO agendamentos (cliente_id,veiculo_id,funcionario_id,status,agendado_para,fim_estimado_em,duracao_total_minutos,notas_cliente) VALUES ('${cids[0]}','${v1}','${env.mecId}','CONFIRMADO',NOW()-interval '2 hours',NOW()+interval '2 hours',240,'Troca de óleo e escaneamento eletrônico') RETURNING id`)).rows[0].id;
    const o1 = (await db.query(`INSERT INTO orcamentos (agendamento_id,cliente_id,funcionario_id,status,valor_total,observacoes,valido_ate) VALUES ('${a1}','${cids[0]}','${env.mecId}','APROVADO',49000,'Revisão aprovada pelo cliente. Prosseguindo com a troca.',NOW()+interval '7 days') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id,servico_id,quantidade,preco_unitario) VALUES ('${o1}','${s1}',1,18000),('${o1}','${s6}',1,10000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id,produto_id,quantidade,preco_unitario) VALUES ('${o1}','${p1}',1,6000),('${o1}','${p2}',3,5000)`);
    await db.query(`INSERT INTO execucoes_servico (orcamento_id,funcionario_id,status,iniciado_em) VALUES ('${o1}','${env.mecId}','EM_EXECUCAO',NOW()-interval '1 hour')`);
    const conv1 = (await db.query(`INSERT INTO conversacoes_chat (cliente_id,ia_pausada) VALUES ('${cids[0]}',true) RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO mensagens_chat (conversacao_id,cliente_id,tipo_remetente,conteudo,criado_em) VALUES ('${conv1}','${cids[0]}','client','Bom dia, meu carro já entrou na oficina?',NOW()-interval '90 minutes'),('${conv1}','${cids[0]}','employee','Bom dia! Sim, já está em execução. Fazendo escaneamento e troca de óleo.',NOW()-interval '85 minutes'),('${conv1}','${cids[0]}','client','Perfeito, me avisem quando estiver pronto.',NOW()-interval '80 minutes'),('${conv1}','${cids[0]}','employee','Claro! Estimamos concluir em cerca de 1 hora.',NOW()-interval '75 minutes')`);
    await db.query(`INSERT INTO notifications (usuario_id,tipo,titulo,mensagem,referencia_id,referencia_tipo,lida) VALUES ('${env.adminId}','approved_budget','Orçamento aprovado pelo cliente','${env.clientes[0].nome} aprovou o orçamento e o serviço foi iniciado.','${o1}','orcamento',false),('${env.mecId}','approved_budget','Orçamento aprovado pelo cliente','${env.clientes[0].nome} aprovou o orçamento e o serviço foi iniciado.','${o1}','orcamento',true)`);

    // Cenário 2: cids[1] — PENDENTE
    const a2 = (await db.query(`INSERT INTO agendamentos (cliente_id,veiculo_id,funcionario_id,status,agendado_para,fim_estimado_em,duracao_total_minutos,notas_cliente) VALUES ('${cids[1]}','${v2}','${env.mecId}','PENDENTE',NOW()+interval '1 day',NOW()+interval '1 day'+interval '45 minutes',45,'Carro fazendo barulho no motor, precisa de avaliação') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO notifications (usuario_id,tipo,titulo,mensagem,referencia_id,referencia_tipo,lida) VALUES ('${env.adminId}','new_appointment','Novo agendamento recebido','${env.clientes[1].nome} agendou uma avaliação para amanhã.','${a2}','agendamento',false),('${env.mecId}','new_appointment','Novo agendamento recebido','${env.clientes[1].nome} agendou uma avaliação para amanhã.','${a2}','agendamento',false)`);

    // Cenário 3: cids[2] — CANCELADO / REJEITADO
    const a3 = (await db.query(`INSERT INTO agendamentos (cliente_id,veiculo_id,funcionario_id,status,agendado_para,fim_estimado_em,duracao_total_minutos,notas_cliente) VALUES ('${cids[2]}','${v3}','${env.mecId}','CANCELADO',NOW()-interval '3 days',NOW()-interval '3 days'+interval '90 minutes',90,'Revisão completa e alinhamento') RETURNING id`)).rows[0].id;
    const o3 = (await db.query(`INSERT INTO orcamentos (agendamento_id,cliente_id,funcionario_id,status,valor_total,observacoes,valido_ate) VALUES ('${a3}','${cids[2]}','${env.mecId}','REJEITADO',65000,'Cliente achou caro, cancelou o serviço.',NOW()-interval '1 day') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id,servico_id,quantidade,preco_unitario) VALUES ('${o3}','${s2}',1,35000),('${o3}','${s3}',1,12000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id,produto_id,quantidade,preco_unitario) VALUES ('${o3}','${p3}',1,15000),('${o3}','${p6}',1,3000)`);
    await db.query(`INSERT INTO notifications (usuario_id,tipo,titulo,mensagem,referencia_id,referencia_tipo,lida) VALUES ('${env.adminId}','rejected_budget','Orçamento recusado pelo cliente','${env.clientes[2].nome} recusou o orçamento de revisão completa.','${o3}','orcamento',true),('${env.mecId}','rejected_budget','Orçamento recusado pelo cliente','${env.clientes[2].nome} recusou o orçamento de revisão completa.','${o3}','orcamento',true)`);

    // Cenário 4: cids[3] — ENVIADO
    const a4 = (await db.query(`INSERT INTO agendamentos (cliente_id,veiculo_id,funcionario_id,status,agendado_para,fim_estimado_em,duracao_total_minutos,notas_cliente) VALUES ('${cids[3]}','${v4}','${env.mecId}','CONFIRMADO',NOW()+interval '3 hours',NOW()+interval '3 hours'+interval '110 minutes',110,'Problema no freio e direção puxando') RETURNING id`)).rows[0].id;
    const o4 = (await db.query(`INSERT INTO orcamentos (agendamento_id,cliente_id,funcionario_id,status,valor_total,observacoes,valido_ate) VALUES ('${a4}','${cids[3]}','${env.mecId}','ENVIADO',55000,'Pastilhas bastante desgastadas, risco de danificar o disco.',NOW()+interval '7 days') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id,servico_id,quantidade,preco_unitario) VALUES ('${o4}','${s3}',1,12000),('${o4}','${s5}',1,20000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id,produto_id,quantidade,preco_unitario) VALUES ('${o4}','${p3}',1,15000),('${o4}','${p4}',2,4000)`);

    // Cenário 5: cids[4] — orçamento APROVADO, pronto para gerar OS
    const a5 = (await db.query(`INSERT INTO agendamentos (cliente_id,veiculo_id,funcionario_id,status,agendado_para,fim_estimado_em,duracao_total_minutos,notas_cliente) VALUES ('${cids[4]}','${v5}','${env.mecId}','CONFIRMADO',NOW()+interval '2 days',NOW()+interval '2 days'+interval '60 minutes',60,'Luz da injeção acesa e falhando muito') RETURNING id`)).rows[0].id;
    const o5 = (await db.query(`INSERT INTO orcamentos (agendamento_id,cliente_id,funcionario_id,status,valor_total,observacoes,valido_ate) VALUES ('${a5}','${cids[4]}','${env.mecId}','APROVADO',30500,'Testando bicos injetores para confirmar necessidade de troca.',NOW()+interval '7 days') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id,servico_id,quantidade,preco_unitario) VALUES ('${o5}','${s6}',1,10000),('${o5}','${s4}',1,15000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id,produto_id,quantidade,preco_unitario) VALUES ('${o5}','${p9}',1,5500)`);




    // Cenário 6: cids[5] — CONCLUÍDO
    const a6 = (await db.query(`INSERT INTO agendamentos (cliente_id,veiculo_id,funcionario_id,status,agendado_para,fim_estimado_em,duracao_total_minutos,notas_cliente) VALUES ('${cids[5]}','${v6}','${env.mecId}','CONCLUIDO',NOW()-interval '5 days',NOW()-interval '5 days'+interval '120 minutes',120,'Revisão de 40.000km — troca de correia dentada') RETURNING id`)).rows[0].id;
    const o6 = (await db.query(`INSERT INTO orcamentos (agendamento_id,cliente_id,funcionario_id,status,valor_total,observacoes,valido_ate) VALUES ('${a6}','${cids[5]}','${env.mecId}','APROVADO',89000,'Revisão completa de 40 mil km. Correia dentro do prazo de substituição.',NOW()+interval '2 days') RETURNING id`)).rows[0].id;
    await db.query(`INSERT INTO itens_orcamento_servico (orcamento_id,servico_id,quantidade,preco_unitario) VALUES ('${o6}','${s7}',1,45000),('${o6}','${s2}',1,35000)`);
    await db.query(`INSERT INTO itens_orcamento_produto (orcamento_id,produto_id,quantidade,preco_unitario) VALUES ('${o6}','${p7}',1,28000),('${o6}','${p5}',1,4500),('${o6}','${p1}',1,6000)`);
    await db.query(`INSERT INTO execucoes_servico (orcamento_id,funcionario_id,status,iniciado_em,finalizado_em,notas_internas) VALUES ('${o6}','${env.mecId}','CONCLUIDO',NOW()-interval '5 days',NOW()-interval '5 days'+interval '110 minutes','Correia substituída dentro do prazo. Revisão geral sem anomalias.')`);
    await db.query(`INSERT INTO notifications (usuario_id,tipo,titulo,mensagem,referencia_id,referencia_tipo,lida) VALUES ('${cids[5]}','service_completed','Seu veículo está pronto!','O serviço de revisão de 40.000km foi concluído. Pode retirar seu veículo.','${o6}','orcamento',true)`);

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
