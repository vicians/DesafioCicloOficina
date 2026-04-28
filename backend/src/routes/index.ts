import { Router } from 'express';
import { produtoRouter } from './produtoRoutes';
import { usuarioRouter } from './usuarioRoutes';
import { veiculoRouter } from './veiculoRoutes';
import { agendamentoRouter } from './agendamentoRoutes';
import { orcamentoRouter } from './orcamentoRoutes';
import { catalogoServicoRouter } from './catalogoServicoRoutes';
import { execucaoServicoRouter } from './execucaoServicoRoutes';

const routes = Router();

routes.use('/produtos', produtoRouter);
routes.use('/usuarios', usuarioRouter);
routes.use('/veiculos', veiculoRouter);
routes.use('/agendamentos', agendamentoRouter);
routes.use('/orcamentos', orcamentoRouter);
routes.use('/servicos', catalogoServicoRouter);
routes.use('/execucoes', execucaoServicoRouter);

export default routes;
