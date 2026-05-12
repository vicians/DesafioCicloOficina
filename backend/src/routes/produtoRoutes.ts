import { Router } from 'express';
import { ProdutoController } from '../controllers/produtoController';
import { authMiddleware } from '../middlewares/AuthMiddleware';
import { authorizeRole } from '../middlewares/RoleMiddleware';

const produtoRouter = Router();

/**
 * @openapi
 * /produtos:
 *   get:
 *     tags:
 *       - Produtos
 *     summary: Lista todos os produtos
 *     description: Retorna a lista de produtos/peças em estoque (RN167, RN168)
 *     responses:
 *       200:
 *         description: Sucesso
 */
produtoRouter.get('/', authMiddleware, ProdutoController.index);

/**
 * @openapi
 * /produtos:
 *   post:
 *     tags:
 *       - Produtos
 *     summary: Cria um novo produto
 *     description: Adiciona um novo item ao estoque da oficina (RN168)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nome
 *               - valor
 *               - quantidade_estoque
 *             properties:
 *               nome:
 *                 type: string
 *               marca:
 *                 type: string
 *               valor:
 *                 type: number
 *               quantidade_estoque:
 *                 type: integer
 *     responses:
 *       201:
 *         description: Criado
 */
produtoRouter.post('/', authMiddleware, authorizeRole(['1', '3']), ProdutoController.store);

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
produtoRouter.get('/search/:nome', authMiddleware, ProdutoController.search);

/**
 * @openapi
 * /produtos/{id}:
 *   get:
 *     tags:
 *       - Produtos
 *     summary: Busca um produto por ID
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
produtoRouter.get('/:id', authMiddleware, ProdutoController.show);

/**
 * @openapi
 * /produtos/{id}:
 *   patch:
 *     tags:
 *       - Produtos
 *     summary: Atualiza um produto
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
 *             properties:
 *               nome:
 *                 type: string
 *               marca:
 *                 type: string
 *               valor:
 *                 type: number
 *               quantidade_estoque:
 *                 type: integer
 *               ativo:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Atualizado com sucesso
 */
produtoRouter.patch('/:id', authMiddleware, authorizeRole(['1', '3']), ProdutoController.update);

/**
 * @openapi
 * /produtos/{id}:
 *   delete:
 *     tags:
 *       - Produtos
 *     summary: Remove um produto
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       204:
 *         description: Removido com sucesso
 */
produtoRouter.delete('/:id', authMiddleware, authorizeRole(['1']), ProdutoController.destroy);

export { produtoRouter };