import { getDb } from '../config/database';
import { runMigrations } from './migrations/migrations';

async function resetDatabase() {
  const db = getDb();
  console.log('Limpando banco de dados (DROP SCHEMA)...');
  
  try {
    // Dropa tudo no schema public e recria
    await db.query('DROP SCHEMA public CASCADE');
    await db.query('CREATE SCHEMA public');
    await db.query('GRANT ALL ON SCHEMA public TO postgres');
    await db.query('GRANT ALL ON SCHEMA public TO public');
    
    console.log('Banco limpo. Iniciando migrations...');
    await runMigrations();
    process.exit(0);
  } catch (error) {
    console.error('Erro ao resetar banco:', error);
    process.exit(1);
  }
}

resetDatabase();
