import { Router } from 'express';
import { ExecucaoServicoController } from '../controllers/execucaoServicoController';

const execucaoServicoRouter = Router();

/**
 * @openapi
 * /execucoes/{id}:
 *   get:
 *     tags:
 *       - Execuções de Serviço
 *     summary: Busca uma execução de serviço por ID
 *     description: Retorna os detalhes de uma execução (Ordem de Serviço) (RN041, RN044)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 */
execucaoServicoRouter.get('/:id', ExecucaoServicoController.show);

/**
 * @openapi
 * /execucoes/orcamento/{orcamentoId}:
 *   get:
 *     tags:
 *       - Execuções de Serviço
 *     summary: Busca execução por ID do orçamento
 *     parameters:
 *       - in: path
 *         name: orcamentoId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 */
execucaoServicoRouter.get('/orcamento/:orcamentoId', ExecucaoServicoController.showByOrcamento);

/**
 * @openapi
 * /execucoes/{id}/notas:
 *   patch:
 *     tags:
 *       - Execuções de Serviço
 *     summary: Atualiza notas internas da execução
 *     description: Registra observações técnicas durante o serviço (RN043, RN116)
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
 *               - notas_internas
 *             properties:
 *               notas_internas:
 *                 type: string
 *     responses:
 *       200:
 *         description: Notas atualizadas com sucesso
 */
execucaoServicoRouter.patch('/:id/notas', ExecucaoServicoController.updateNotas);

/**
 * @openapi
 * /execucoes/{id}/finalizar:
 *   patch:
 *     tags:
 *       - Execuções de Serviço
 *     summary: Finaliza a execução do serviço
 *     description: Altera o status para CONCLUIDO e registra data de término (RN044)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Finalizado com sucesso
 */
execucaoServicoRouter.patch('/:id/finalizar', ExecucaoServicoController.finalizar);

export { execucaoServicoRouter };