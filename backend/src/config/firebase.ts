import admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';

let initialized = false;

/**
 * Inicializa o Firebase Admin SDK uma única vez.
 * Requer a variável de ambiente FIREBASE_SERVICE_ACCOUNT_PATH apontando
 * para o arquivo JSON do service account (não versionado no repositório).
 */
export const initFirebase = (): void => {
  if (initialized) return;

  const credPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!credPath) {
    console.warn('[Firebase] FIREBASE_SERVICE_ACCOUNT_PATH não definido — push notifications desativado.');
    return;
  }

  const resolved = path.resolve(credPath);
  if (!fs.existsSync(resolved)) {
    console.warn(`[Firebase] Arquivo de credenciais não encontrado em "${resolved}" — push notifications desativado.`);
    return;
  }

  const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf-8'));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialized = true;
  console.log('[Firebase] Admin SDK inicializado com sucesso.');
};

export const getMessaging = (): admin.messaging.Messaging | null => {
  if (!initialized) return null;
  return admin.messaging();
};
