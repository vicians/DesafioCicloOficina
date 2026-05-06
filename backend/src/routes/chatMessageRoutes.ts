import { Router } from 'express';
import { ChatMessageController } from '../controllers/chatMessageController';

const chatMessageRouter = Router();

chatMessageRouter.get('/clientes/:clienteId/mensagens', ChatMessageController.listByCliente);
chatMessageRouter.post('/clientes/:clienteId/mensagens', ChatMessageController.sendByCliente);

export { chatMessageRouter };
