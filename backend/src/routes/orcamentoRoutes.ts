import { Router } from 'express';
import { OrcamentoController } from '../controllers/orcamentoController';

const orcamentoRouter = Router();

/**
 * @openapi
 * /orcamentos:
 *   get:
 *     tags:
 *       - Orçamentos
 *     summary: Lista todos os orçamentos
 *     responses:
 *       200:
 *         description: Sucesso
 */
orcamentoRouter.get('/', OrcamentoController.index);

/**
 * @openapi
 * /orcamentos:
 *   post:
 *     tags:
 *       - Orçamentos
 *     summary: Cria um novo orçamento
 *     responses:
 *       201:
 *         description: Criado
 */
orcamentoRouter.post('/', OrcamentoController.store);

export { orcamentoRouter };
