import { Router } from 'express';
import { VeiculoController } from '../controllers/veiculoController';

const veiculoRouter = Router();

veiculoRouter.get('/', VeiculoController.index);
veiculoRouter.get('/:id', VeiculoController.show);
veiculoRouter.get('/placa/:placa', VeiculoController.showByPlaca);

veiculoRouter.get('/cliente/:clienteId', VeiculoController.listByCliente);
veiculoRouter.post('/', VeiculoController.store);

export { veiculoRouter };
