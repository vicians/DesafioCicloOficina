import { Router } from 'express';
import { AgendamentoController } from '../controllers/agendamentoController';

const agendamentoRouter = Router();

agendamentoRouter.get('/', AgendamentoController.index);
agendamentoRouter.get('/cliente/:clienteId', AgendamentoController.listByCliente);
agendamentoRouter.post('/', AgendamentoController.store);

export { agendamentoRouter };
