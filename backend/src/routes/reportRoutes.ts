import { Router } from 'express';
import { ReportController } from '../controllers/reportController';

const reportRouter = Router();

/**
 * @openapi
 * /reports/internal:
 *   get:
 *     tags:
 *       - Relatórios
 *     summary: Gera relatório interno mensal da oficina
 *     description: Retorna KPIs de faturamento, serviços e status com base em execuções e orçamentos.
 *     parameters:
 *       - in: query
 *         name: month
 *         required: false
 *         schema:
 *           type: string
 *           example: 2026-05
 *         description: Mês de referência no formato YYYY-MM. Se omitido, usa o mês atual.
 *     responses:
 *       200:
 *         description: Sucesso
 */
reportRouter.get('/internal', ReportController.internal);

export { reportRouter };
