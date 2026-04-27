import { getDb } from '../../config/database';
import { v4 as uuidv4 } from 'uuid';
import { hashPassword } from '../../utils/passwordHash';

// IDs únicos gerados programaticamente
const adminId = uuidv4();
const mecanicoId = uuidv4();
const clienteId = uuidv4();

export const runSeeds = async () => {
  const db = getDb();

  console.log('Iniciando Seeds...');

  // Gerar hashes das senhas (variáveis em português do .env)
  const adminSenhaHash = await hashPassword(process.env.ADMIN_SENHA as string);
  const mecanicoSenhaHash = await hashPassword(process.env.MECANICO_SENHA as string);
  const clienteSenhaHash = await hashPassword(process.env.CLIENTE_SENHA as string);

  const usuarios = [
    {
      id: adminId,
      tipo_id: 1, // ADMIN
      nome: process.env.ADMIN_NOME,
      cpf_cnpj: process.env.ADMIN_CPF,
      telefone: process.env.ADMIN_TELEFONE,
      email: process.env.ADMIN_EMAIL,
      senha_hash: adminSenhaHash,
    },
    {
      id: mecanicoId,
      tipo_id: 3, // MECANICO
      nome: process.env.MECANICO_NOME,
      cpf_cnpj: process.env.MECANICO_CPF,
      telefone: process.env.MECANICO_TELEFONE,
      email: process.env.MECANICO_EMAIL,
      senha_hash: mecanicoSenhaHash,
    },
    {
      id: clienteId,
      tipo_id: 2, // CLIENTE
      nome: process.env.CLIENTE_NOME,
      cpf_cnpj: process.env.CLIENTE_CPF,
      telefone: process.env.CLIENTE_TELEFONE,
      email: process.env.CLIENTE_EMAIL,
      senha_hash: clienteSenhaHash,
    },
  ];

  try {
    // 1. Inserir Tipos de Usuário (Base para as FKs)
    await db.query(`
      INSERT INTO tipos_usuario (id, nome, descricao)
      VALUES 
        (1, 'ADMIN', 'Administrador do sistema'),
        (2, 'CLIENTE', 'Cliente final da oficina'),
        (3, 'MECANICO', 'Mecânico executante')
      ON CONFLICT (id) DO NOTHING
    `);

    // Verificar existência de dados para evitar duplicação
    const contagemUsuarios = await db.query('SELECT COUNT(*) as count FROM usuarios');

    if (parseInt(contagemUsuarios.rows[0].count) > 0) {
      console.log('⚠️  Dados já existentes. Pulando inserção de usuários...');
    } else {
      // 2. Inserir usuários (Admin, Mecânico e Cliente)
      for (const usuario of usuarios) {
        await db.query(
          `INSERT INTO usuarios (id, tipo_id, nome, cpf_cnpj, telefone, email, senha_hash)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            usuario.id,
            usuario.tipo_id,
            usuario.nome,
            usuario.cpf_cnpj,
            usuario.telefone,
            usuario.email,
            usuario.senha_hash
          ],
        );
      }
      console.log('✓ Usuários (Admin, Mecânico, Cliente) inseridos');
    }

    // 3. Inserir Oficina
    const contagemOficina = await db.query('SELECT COUNT(*) as count FROM oficinas');
    if (parseInt(contagemOficina.rows[0].count) === 0) {
      await db.query(`
        INSERT INTO oficinas (nome, quantidade_boxes)
        VALUES ('Oficina Central OmniConnect', 5)
      `);
      console.log('✓ Oficina inserida');
    }

    // 4. Inserir Catálogo de Serviços
    const contagemServicos = await db.query('SELECT COUNT(*) as count FROM catalogo_servicos');
    if (parseInt(contagemServicos.rows[0].count) === 0) {
      await db.query(`
        INSERT INTO catalogo_servicos (nome, preco, duracao_minutos)
        VALUES 
          ('Troca de Óleo', 15000, 40),
          ('Revisão de Freios', 25000, 90)
      `);
      console.log('✓ Serviços inseridos');
    }

    console.log('\n✅ Seeds finalizados com sucesso!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erro na execução dos seeds:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  runSeeds();
}
