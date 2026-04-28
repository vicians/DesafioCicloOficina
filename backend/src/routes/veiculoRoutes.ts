import { Router } from 'express';
import { VeiculoController } from '../controllers/veiculoController';

const veiculoRouter = Router();

// GET /veiculos?placa=&nome_cliente=
veiculoRouter.get('/', VeiculoController.index);

// Rota estática ANTES de /:id — Express faz match top-down
veiculoRouter.get('/cliente/:clienteId', VeiculoController.listByCliente);
veiculoRouter.get('/:id', VeiculoController.show);

veiculoRouter.post('/', VeiculoController.store);

export { veiculoRouter };

