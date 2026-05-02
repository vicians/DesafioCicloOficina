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
 *     description: Retorna uma lista de todos os agendamentos registrados (RN023)
 *     responses:
 *       200:
 *         description: Sucesso
 */
agendamentoRouter.get('/', AgendamentoController.index);

/**
 * @openapi
 * /agendamentos:
 *   post:
 *     tags:
 *       - Agendamentos
 *     summary: Cria um novo agendamento
 *     description: Registra uma nova solicitação de serviço (RN011, RN012, RN022)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cliente_id
 *               - veiculo_id
 *               - agendado_para
 *             properties:
 *               cliente_id:
 *                 type: string
 *                 format: uuid
 *               veiculo_id:
 *                 type: string
 *                 format: uuid
 *               agendado_para:
 *                 type: string
 *                 format: date-time
 *               notas_cliente:
 *                 type: string
 *     responses:
 *       201:
 *         description: Criado
 */
agendamentoRouter.post('/', AgendamentoController.store);

/**
 * @openapi
 * /agendamentos/cliente/{clienteId}:
 *   get:
 *     tags:
 *       - Agendamentos
 *     summary: Lista agendamentos por cliente
 *     description: Filtra agendamentos vinculados a um cliente específico (RN009)
 *     parameters:
 *       - in: path
 *         name: clienteId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 */
agendamentoRouter.get('/cliente/:clienteId', AgendamentoController.listByCliente);

/**
 * @openapi
 * /agendamentos/{id}/status:
 *   patch:
 *     tags:
 *       - Agendamentos
 *     summary: Atualiza o status do agendamento
 *     description: "Altera o estado de um agendamento (Ex: PENDENTE, EM_AVALIACAO, CONFIRMADO, CANCELADO)"
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [PENDENTE, EM_AVALIACAO, AGUARDANDO_APROVACAO, CONFIRMADO, EM_EXECUCAO, CONCLUIDO, CANCELADO]
 *     responses:
 *       200:
 *         description: Atualizado com sucesso
 */
agendamentoRouter.patch('/:id/status', AgendamentoController.updateStatus);

/**
 * @openapi
 * /agendamentos/{id}/iniciar:
 *   patch:
 *     tags:
 *       - Agendamentos
 *     summary: Inicia a execução do agendamento
 *     description: Transforma um agendamento confirmado em uma execução de serviço (RN041)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Execução iniciada com sucesso
 */
agendamentoRouter.patch('/:id/iniciar', AgendamentoController.iniciarExecucao);

export { agendamentoRouter };