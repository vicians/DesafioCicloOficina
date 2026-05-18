import 'dotenv/config';
import { app } from './app';
import { initFirebase } from './config/firebase';
import { runMigrations } from './database/migrations/migrations';

initFirebase();

const PORT = process.env.PORT || 3000;
const URL = process.env.URL || 'http://localhost';

async function start() {
  // Roda migrations automaticamente a cada startup.
  // Todas as queries usam IF NOT EXISTS / ADD COLUMN IF NOT EXISTS,
  // portanto são idempotentes e seguras em produção.
  await runMigrations();

  app.listen(PORT, () => {
    console.log(`Server is running on ${URL}:${PORT}`);
  });
}

start().catch(err => {
  console.error('Falha ao iniciar servidor:', err);
  process.exit(1);
});