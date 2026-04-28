import { Router } from 'express';
import { ProdutoController } from '../controllers/produtoController';

const produtoRouter = Router();

/**
 * @openapi
 * /produtos:
 *   get:
 *     tags:
 *       - Produtos
 *     summary: Lista todos os produtos
 *     responses:
 *       200:
 *         description: Sucesso
 */
produtoRouter.get('/', ProdutoController.index);

/**
 * @openapi
 * /produtos/search/{nome}:
 *   get:
 *     tags:
 *       - Produtos
 *     summary: Pesquisa produtos por nome
 *     parameters:
 *       - in: path
 *         name: nome
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sucesso
 */
produtoRouter.get('/search/:nome', ProdutoController.search);

/**
 * @openapi
 * /produtos:
 *   post:
 *     tags:
 *       - Produtos
 *     summary: Cria um novo produto
 *     responses:
 *       201:
 *         description: Criado
 */
produtoRouter.post('/', ProdutoController.store);

export { produtoRouter };
