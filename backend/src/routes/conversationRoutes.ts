import { Router } from 'express';
import { ConversationController } from '../controllers/conversationController';

const conversationRouter = Router();

conversationRouter.get('/', ConversationController.list);
conversationRouter.get('/:id/mensagens', ConversationController.getMessages);
conversationRouter.post('/:id/mensagens', ConversationController.sendMessage);
conversationRouter.patch('/:id/handoff', ConversationController.toggleHandoff);
conversationRouter.patch('/:id/lidas', ConversationController.markAsRead);

export { conversationRouter };
