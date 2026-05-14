import { Router } from 'express';
import { produtoRouter } from './produtoRoutes';
import { usuarioRouter } from './usuarioRoutes';
import { veiculoRouter } from './veiculoRoutes';
import { agendamentoRouter } from './agendamentoRoutes';
import { orcamentoRouter } from './orcamentoRoutes';
import { catalogoServicoRouter } from './catalogoServicoRoutes';
import { execucaoServicoRouter } from './execucaoServicoRoutes';
import { reportRouter } from './reportRoutes';
import { notificationRouter } from './notificationRoutes';
import { pushTokenRouter } from './pushTokenRoutes';
import { authRouter } from './authRoutes';
import { chatMessageRouter } from './chatMessageRoutes';
import { conversationRouter } from './conversationRoutes';
import { oficinaRouter } from './oficinaRoutes';

const routes = Router();

routes.use('/produtos', produtoRouter);
routes.use('/usuarios', usuarioRouter);
routes.use('/veiculos', veiculoRouter);
routes.use('/agendamentos', agendamentoRouter);
routes.use('/orcamentos', orcamentoRouter);
routes.use('/servicos', catalogoServicoRouter);
routes.use('/execucoes', execucaoServicoRouter);
routes.use('/reports', reportRouter);
routes.use('/notifications', notificationRouter);
routes.use('/push-tokens', pushTokenRouter);
routes.use('/auth', authRouter);
routes.use('/chat', chatMessageRouter);
routes.use('/conversacoes', conversationRouter);
routes.use('/oficina', oficinaRouter);

export default routes;
