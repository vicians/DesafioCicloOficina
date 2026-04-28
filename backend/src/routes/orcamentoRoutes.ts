import { Router } from 'express';
import { OrcamentoController } from '../controllers/orcamentoController';

const orcamentoRouter = Router();

orcamentoRouter.get('/', OrcamentoController.index);
orcamentoRouter.post('/', OrcamentoController.store);

export { orcamentoRouter };
