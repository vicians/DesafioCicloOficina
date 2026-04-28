import { Router } from 'express';
import { AgendamentoController } from '../controllers/agendamentoController';

const agendamentoRouter = Router();

/**
 * @openapi
 * /agendamentos:
 *   get:
 *     tags:
 *       - Agendamentos
 *     summary: Lista todos os agendamentos
 *     responses:
 *       200:
 *         description: Sucesso
 */
agendamentoRouter.get('/', AgendamentoController.index);

/**
 * @openapi
 * /agendamentos/cliente/{clienteId}:
 *   get:
 *     tags:
 *       - Agendamentos
 *     summary: Lista agendamentos por cliente
 *     parameters:
 *       - in: path
 *         name: clienteId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sucesso
 */
agendamentoRouter.get('/cliente/:clienteId', AgendamentoController.listByCliente);

/**
 * @openapi
 * /agendamentos:
 *   post:
 *     tags:
 *       - Agendamentos
 *     summary: Cria um novo agendamento
 *     responses:
 *       201:
 *         description: Criado
 */
agendamentoRouter.post('/', AgendamentoController.store);
agendamentoRouter.patch('/:id/status', AgendamentoController.updateStatus);
agendamentoRouter.patch('/:id/iniciar', AgendamentoController.iniciarExecucao);

export { agendamentoRouter };
