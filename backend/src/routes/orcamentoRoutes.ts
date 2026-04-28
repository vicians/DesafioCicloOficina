import { Router } from 'express';
import { OrcamentoController } from '../controllers/orcamentoController';

const orcamentoRouter = Router();

orcamentoRouter.get('/', OrcamentoController.index);
orcamentoRouter.get('/:id', OrcamentoController.show);
orcamentoRouter.post('/', OrcamentoController.store);

// Itens de serviço
orcamentoRouter.post('/:id/servicos', OrcamentoController.addServico);
orcamentoRouter.delete('/:id/servicos/:item_id', OrcamentoController.removeServico);

// Itens de produto
orcamentoRouter.post('/:id/produtos', OrcamentoController.addProduto);
orcamentoRouter.delete('/:id/produtos/:item_id', OrcamentoController.removeProduto);

// Aprovação
orcamentoRouter.patch('/:id/aprovar', OrcamentoController.aprovar);

export { orcamentoRouter };

