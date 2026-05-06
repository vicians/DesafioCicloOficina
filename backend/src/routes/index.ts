import { Router } from 'express';
import { produtoRouter } from './produtoRoutes';
import { usuarioRouter } from './usuarioRoutes';
import { veiculoRouter } from './veiculoRoutes';
import { agendamentoRouter } from './agendamentoRoutes';
import { orcamentoRouter } from './orcamentoRoutes';
import { catalogoServicoRouter } from './catalogoServicoRoutes';
import { execucaoServicoRouter } from './execucaoServicoRoutes';
import { notificationRouter } from './notificationRoutes';
import { pushTokenRouter } from './pushTokenRoutes';
import { authRouter } from './authRoutes';
import { chatMessageRouter } from './chatMessageRoutes';
import { conversationRouter } from './conversationRoutes';

const routes = Router();

routes.use('/produtos', produtoRouter);
routes.use('/usuarios', usuarioRouter);
routes.use('/veiculos', veiculoRouter);
routes.use('/agendamentos', agendamentoRouter);
routes.use('/orcamentos', orcamentoRouter);
routes.use('/servicos', catalogoServicoRouter);
routes.use('/execucoes', execucaoServicoRouter);
routes.use('/notifications', notificationRouter);
routes.use('/push-tokens', pushTokenRouter);
routes.use('/auth', authRouter);
routes.use('/chat', chatMessageRouter);
routes.use('/conversacoes', conversationRouter);

export default routes;
