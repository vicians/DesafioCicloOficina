import { Router } from 'express';
import { AgendamentoController } from '../controllers/agendamentoController';
import { authMiddleware } from '../middlewares/AuthMiddleware';
import { authorizeRole } from '../middlewares/RoleMiddleware';

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
agendamentoRouter.get('/', authMiddleware, authorizeRole(['1', '3']), AgendamentoController.index);

/**
 * @openapi
 * /agendamentos:
 *   post:
 *     tags:
 *       - Agendamentos
 *     summary: Cria um novo agendamento
 *     description: Registra uma nova solicitação de serviço (RN011, RN012, RN022)
 *     security:
 *       - bearerAuth: []
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
agendamentoRouter.post('/', authMiddleware, AgendamentoController.store);

/**
 * @openapi
 * /agendamentos/disponibilidade:
 *   get:
 *     tags:
 *       - Agendamentos
 *     summary: Consulta horários indisponíveis por data
 *     description: Retorna os horários ocupados no dia para o fluxo de agendamento do cliente.
 *     parameters:
 *       - in: query
 *         name: data
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *         description: Data no formato YYYY-MM-DD
 *     responses:
 *       200:
 *         description: Sucesso
 */
agendamentoRouter.get('/disponibilidade', AgendamentoController.disponibilidade);

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
agendamentoRouter.get('/cliente/:clienteId', authMiddleware, AgendamentoController.listByCliente);

/**
 * @openapi
 * /agendamentos/{id}/status:
 *   patch:
 *     tags:
 *       - Agendamentos
 *     summary: Atualiza o status do agendamento
 *     description: "Altera o estado de um agendamento (Ex: PENDENTE, CONFIRMADO, CONCLUIDO, CANCELADO)"
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
 *                 enum: [PENDENTE, CONFIRMADO, CONCLUIDO, CANCELADO]
 *     responses:
 *       200:
 *         description: Atualizado com sucesso
 */
agendamentoRouter.patch('/:id/status', authMiddleware, authorizeRole(['1', '3']), AgendamentoController.updateStatus);

/**
 * @openapi
 * /agendamentos/{id}/confirmar-recebimento:
 *   patch:
 *     tags:
 *       - Agendamentos
 *     summary: Confirma recebimento na oficina e abre a OS
 *     description: Converte o agendamento recebido em execução de serviço (OS), sem exigir nova aprovação do orçamento inicial.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       201:
 *         description: OS aberta com sucesso
 */
agendamentoRouter.patch('/:id/confirmar-recebimento', authMiddleware, authorizeRole(['1', '3']), AgendamentoController.confirmarRecebimento);

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
agendamentoRouter.patch('/:id/iniciar', authMiddleware, authorizeRole(['1', '3']), AgendamentoController.iniciarExecucao);

export { agendamentoRouter };