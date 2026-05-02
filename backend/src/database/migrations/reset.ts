import { getDb } from '../../config/database';

/**
 * Reseta o banco de dados (PostgreSQL) recriando o schema public.
 * ATENÇÃO: Isso apaga TODAS as tabelas e dados irreversivelmente.
 */
export const runReset = async () => {
  const db = getDb();
  
  console.log('⚠️  Iniciando reset do banco de dados...');
  console.log('Dropando o schema public...');

  try {
    // Ao dropar o schema com CASCADE, todas as tabelas, views e functions vão junto.
    await db.query(`DROP SCHEMA public CASCADE;`);
    
    // Recriamos o schema para as migrations poderem rodar do zero.
    await db.query(`CREATE SCHEMA public;`);
    
    // Restauramos as permissões padrão do postgres
    await db.query(`GRANT ALL ON SCHEMA public TO postgres;`);
    await db.query(`GRANT ALL ON SCHEMA public TO public;`);
    
    console.log('✅ Banco de dados limpo com sucesso!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erro ao resetar banco de dados:', error);
    process.exit(1);
  }
};

// Executa a função se o arquivo for chamado diretamente via ts-node
if (require.main === module) {
  runReset();
}
