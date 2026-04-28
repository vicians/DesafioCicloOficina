import { Router } from 'express';
import { CatalogoServicoController } from '../controllers/catalogoServicoController';

const catalogoServicoRouter = Router();

/**
 * @openapi
 * /servicos:
 *   get:
 *     tags:
 *       - Serviços
 *     summary: Lista todos os serviços do catálogo
 *     responses:
 *       200:
 *         description: Sucesso
 */
catalogoServicoRouter.get('/', CatalogoServicoController.index);

/**
 * @openapi
 * /servicos:
 *   post:
 *     tags:
 *       - Serviços
 *     summary: Cria um novo serviço no catálogo
 *     responses:
 *       201:
 *         description: Criado
 */
catalogoServicoRouter.post('/', CatalogoServicoController.store);

export { catalogoServicoRouter };
