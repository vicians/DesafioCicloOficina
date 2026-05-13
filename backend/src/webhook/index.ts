import { Router } from 'express';
import { validateWebhook, handleMessage } from './controller';

const router = Router();

// Rota GET: Validação do Webhook (Handshake com a Meta)[cite: 1]
router.get('/', validateWebhook);

// Rota POST: Recebimento e processamento das mensagens[cite: 1]
router.post('/', handleMessage);

export default router;