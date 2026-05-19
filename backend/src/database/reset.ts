import { getDb } from '../config/database';
import { runMigrations } from './migrations/migrations';

async function resetDatabase() {
  const db = getDb();
  console.log('Limpando banco de dados (DROP SCHEMA)...');
  
  try {
    // Em servidores compartilhados ou sem superusuário, deletar o schema "public" falha.
    // Em vez disso, limpamos todas as tabelas, views e types individualmente.
    console.log('Deletando todas as tabelas...');
    await db.query(`
      DO $$ DECLARE
        r RECORD;
      BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
          EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;
      END $$;
    `);

    console.log('Deletando todas as views...');
    await db.query(`
      DO $$ DECLARE
        r RECORD;
      BEGIN
        FOR r IN (SELECT viewname FROM pg_views WHERE schemaname = 'public') LOOP
          EXECUTE 'DROP VIEW IF EXISTS ' || quote_ident(r.viewname) || ' CASCADE';
        END LOOP;
      END $$;
    `);

    console.log('Deletando custom types (enums)...');
    await db.query(`
      DO $$ DECLARE
        r RECORD;
      BEGIN
        FOR r IN (
          SELECT t.typname 
          FROM pg_type t 
          JOIN pg_namespace n ON n.oid = t.typnamespace 
          WHERE n.nspname = 'public' AND t.typtype = 'e'
        ) LOOP
          EXECUTE 'DROP TYPE IF EXISTS ' || quote_ident(r.typname) || ' CASCADE';
        END LOOP;
      END $$;
    `);
    
    console.log('Banco limpo. Iniciando migrations...');
    await runMigrations();
    process.exit(0);
  } catch (error) {
    console.error('Erro ao resetar banco:', error);
    process.exit(1);
  }
}

resetDatabase();
