import path from 'path';
import { ingestDirectory } from '../services/ingestion_service';
import dotenv from 'dotenv';

dotenv.config();

async function main() {
  // Pasta padrão: ai_service/documents (pode ser customizada via argumento)
  const targetDir = process.argv[2] || path.join(__dirname, '../../documents');
  
  console.log(`[CLI] Buscando documentos em: ${targetDir}`);
  
  try {
    await ingestDirectory(targetDir);
    console.log('[CLI] Ingestão concluída com sucesso.');
    process.exit(0);
  } catch (err) {
    console.error('[CLI] Falha crítica na ingestão:', err);
    process.exit(1);
  }
}

main();
