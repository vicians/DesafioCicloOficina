import { getDb } from '../../config/database';

/**
 * Executa as migrations do banco de dados (PostgreSQL)
 * 
 * IMPORTANTE: Preços são armazenados como INTEGER em centavos
 * Exemplo: R$ 10,50 = 1050, R$ 0,99 = 99, R$ 100,00 = 10000
 */
export const runMigrations = async () => {
  const db = getDb();

  console.log('Iniciando Migrations...');

  // Adicionar a extensão para gerar UUID se não existir
  await db.query(`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`);

  // ========================================
  // TABELA: oficinas
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS oficinas (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nome VARCHAR NOT NULL,
      quantidade_boxes INTEGER NOT NULL,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // ========================================
  // TABELA: tipos_usuario
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS tipos_usuario (
      id SERIAL PRIMARY KEY,
      nome VARCHAR NOT NULL,
      descricao TEXT
    )
  `);

  // ========================================
  // TABELA: usuarios
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS usuarios (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tipo_id INTEGER NOT NULL REFERENCES tipos_usuario(id) ON DELETE RESTRICT,
      cpf_cnpj VARCHAR UNIQUE,
      nome VARCHAR NOT NULL,
      telefone VARCHAR UNIQUE,
      email VARCHAR UNIQUE,
      senha_hash VARCHAR,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Torna cpf_cnpj e telefone opcionais para suportar auto-cadastro de clientes
  await db.query(`ALTER TABLE usuarios ALTER COLUMN cpf_cnpj DROP NOT NULL`).catch(() => {});
  await db.query(`ALTER TABLE usuarios ALTER COLUMN telefone DROP NOT NULL`).catch(() => {});

  // ========================================
  // TABELA: veiculos
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS veiculos (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      cliente_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      placa VARCHAR UNIQUE NOT NULL,
      marca VARCHAR,
      modelo VARCHAR,
      ano INTEGER,
      quilometragem_atual INTEGER,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // ========================================
  // TABELA: catalogo_servicos
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS catalogo_servicos (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nome VARCHAR NOT NULL,
      descricao TEXT,
      preco INTEGER NOT NULL,
      duracao_minutos INTEGER NOT NULL,
      ativo BOOLEAN DEFAULT true
    )
  `);

  // ========================================
  // TABELA: produtos
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS produtos (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nome VARCHAR NOT NULL,
      marca VARCHAR,
      valor INTEGER NOT NULL,
      quantidade_estoque INTEGER NOT NULL DEFAULT 0,
      ativo BOOLEAN DEFAULT true
    )
  `);

  // ========================================
  // TABELA: agendamentos
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS agendamentos (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      cliente_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      veiculo_id UUID NOT NULL REFERENCES veiculos(id) ON DELETE CASCADE,
      funcionario_id UUID REFERENCES usuarios(id),
      agendado_para TIMESTAMPTZ NOT NULL,
      duracao_total_minutos INTEGER NOT NULL,
      fim_estimado_em TIMESTAMPTZ NOT NULL,
      status VARCHAR NOT NULL,
      notas_cliente TEXT,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Migração para bases existentes com colunas TIMESTAMP sem fuso
  await db.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'agendamentos'
          AND column_name = 'agendado_para'
          AND data_type = 'timestamp without time zone'
      ) THEN
        ALTER TABLE agendamentos
          ALTER COLUMN agendado_para   TYPE TIMESTAMPTZ USING agendado_para   AT TIME ZONE 'UTC',
          ALTER COLUMN fim_estimado_em TYPE TIMESTAMPTZ USING fim_estimado_em AT TIME ZONE 'UTC';
      END IF;
    END $$;
  `);

  // ========================================
  // TABELA: orcamentos
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS orcamentos (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agendamento_id UUID REFERENCES agendamentos(id) ON DELETE SET NULL,
      cliente_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      funcionario_id UUID REFERENCES usuarios(id),
      status VARCHAR NOT NULL,
      valor_total INTEGER NOT NULL,
      observacoes TEXT,
      valido_ate TIMESTAMP,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Migração para bases existentes sem a coluna observacoes
  await db.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'orcamentos'
          AND column_name = 'observacoes'
      ) THEN
        ALTER TABLE orcamentos ADD COLUMN observacoes TEXT;
      END IF;
    END $$;
  `);

  // ========================================
  // TABELA: itens_orcamento_servico
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS itens_orcamento_servico (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      orcamento_id UUID NOT NULL REFERENCES orcamentos(id) ON DELETE CASCADE,
      servico_id UUID NOT NULL REFERENCES catalogo_servicos(id) ON DELETE RESTRICT,
      quantidade INTEGER NOT NULL DEFAULT 1,
      preco_unitario INTEGER NOT NULL,
      em_revisao BOOLEAN DEFAULT false
    )
  `);

  await db.query(`
    ALTER TABLE itens_orcamento_servico ADD COLUMN IF NOT EXISTS em_revisao BOOLEAN DEFAULT false
  `);

  // ========================================
  // TABELA: itens_orcamento_produto
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS itens_orcamento_produto (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      orcamento_id UUID NOT NULL REFERENCES orcamentos(id) ON DELETE CASCADE,
      produto_id UUID NOT NULL REFERENCES produtos(id) ON DELETE RESTRICT,
      quantidade INTEGER NOT NULL,
      preco_unitario INTEGER NOT NULL,
      em_revisao BOOLEAN DEFAULT false
    )
  `);

  await db.query(`
    ALTER TABLE itens_orcamento_produto ADD COLUMN IF NOT EXISTS em_revisao BOOLEAN DEFAULT false
  `);

  // ========================================
  // TABELA: execucoes_servico
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS execucoes_servico (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      orcamento_id UUID NOT NULL UNIQUE REFERENCES orcamentos(id) ON DELETE CASCADE,
      funcionario_id UUID REFERENCES usuarios(id),
      status VARCHAR NOT NULL,
      iniciado_em TIMESTAMP,
      finalizado_em TIMESTAMP,
      notas_internas TEXT
    )
  `);

  // ========================================
  // TABELA: conversacoes_chat
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS conversacoes_chat (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      cliente_id UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
      ia_pausada BOOLEAN DEFAULT false,
      atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // ========================================
  // TABELA: mensagens_chat
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS mensagens_chat (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      cliente_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      tipo_remetente VARCHAR NOT NULL,
      conteudo TEXT NOT NULL,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await db.query(`
    ALTER TABLE mensagens_chat
    ADD COLUMN IF NOT EXISTS conversacao_id UUID REFERENCES conversacoes_chat(id) ON DELETE CASCADE
  `);

  await db.query(`
    ALTER TABLE mensagens_chat
    ADD COLUMN IF NOT EXISTS lida BOOLEAN DEFAULT false
  `);

  // ========================================
  // TABELA: notifications
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      tipo VARCHAR NOT NULL,
      titulo VARCHAR NOT NULL,
      mensagem TEXT NOT NULL,
      referencia_id UUID,
      referencia_tipo VARCHAR,
      push_enviado BOOLEAN DEFAULT false,
      push_enviado_em TIMESTAMP,
      lida BOOLEAN DEFAULT false,
      lido_em TIMESTAMP,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Compatibilidade para bases já criadas sem os campos de entrega de push
  await db.query(`
    ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS push_enviado BOOLEAN DEFAULT false
  `);

  await db.query(`
    ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS push_enviado_em TIMESTAMP
  `);

  // ========================================
  // TABELA: user_push_tokens
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS user_push_tokens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      fcm_registration_token TEXT NOT NULL UNIQUE,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Compatibilidade para bases já criadas com a coluna antiga "token"
  await db.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'user_push_tokens'
          AND column_name = 'token'
      ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'user_push_tokens'
          AND column_name = 'fcm_registration_token'
      ) THEN
        ALTER TABLE user_push_tokens RENAME COLUMN token TO fcm_registration_token;
      END IF;
    END $$;
  `);

  // ========================================
  // TABELA: magic_links (autenticação sem senha para app cliente)
  // ========================================
  await db.query(`
    CREATE TABLE IF NOT EXISTS magic_links (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      token VARCHAR(64) NOT NULL UNIQUE,
      expires_at TIMESTAMP NOT NULL,
      used BOOLEAN DEFAULT false,
      criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await db.query(`ALTER TABLE produtos ADD COLUMN IF NOT EXISTS categoria VARCHAR`);
  await db.query(`ALTER TABLE produtos ADD COLUMN IF NOT EXISTS min_estoque INTEGER DEFAULT 10`);
  await db.query(`ALTER TABLE produtos ADD COLUMN IF NOT EXISTS unidade VARCHAR DEFAULT 'unid.'`);

  console.log('Migrations concluídas com sucesso!');
};

// Executa a função se o arquivo for chamado diretamente via ts-node
if (require.main === module) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Erro nas migrations:', err);
      process.exit(1);
    });
}
