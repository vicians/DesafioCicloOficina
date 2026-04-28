import { Router } from 'express';
import { ExecucaoServicoController } from '../controllers/execucaoServicoController';

const execucaoServicoRouter = Router();

execucaoServicoRouter.get('/:id', ExecucaoServicoController.show);
execucaoServicoRouter.get('/orcamento/:orcamentoId', ExecucaoServicoController.showByOrcamento);
execucaoServicoRouter.patch('/:id/notas', ExecucaoServicoController.updateNotas);
execucaoServicoRouter.patch('/:id/finalizar', ExecucaoServicoController.finalizar);

export { execucaoServicoRouter };
