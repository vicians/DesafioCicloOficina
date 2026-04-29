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
 *     description: Retorna todos os serviços de mão de obra disponíveis (RN164, RN165)
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
 *     description: Adiciona uma nova opção de mão de obra ao catálogo (RN165)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nome
 *               - preco
 *               - duracao_minutos
 *             properties:
 *               nome:
 *                 type: string
 *               descricao:
 *                 type: string
 *               preco:
 *                 type: number
 *               duracao_minutos:
 *                 type: integer
 *     responses:
 *       201:
 *         description: Criado
 */
catalogoServicoRouter.post('/', CatalogoServicoController.store);

/**
 * @openapi
 * /servicos/{id}:
 *   get:
 *     tags:
 *       - Serviços
 *     summary: Busca um serviço por ID
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
catalogoServicoRouter.get('/:id', CatalogoServicoController.show);

/**
 * @openapi
 * /servicos/{id}:
 *   patch:
 *     tags:
 *       - Serviços
 *     summary: Atualiza um serviço no catálogo
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
 *               descricao:
 *                 type: string
 *               preco:
 *                 type: number
 *               duracao_minutos:
 *                 type: integer
 *               ativo:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Atualizado com sucesso
 */
catalogoServicoRouter.patch('/:id', CatalogoServicoController.update);

/**
 * @openapi
 * /servicos/{id}:
 *   delete:
 *     tags:
 *       - Serviços
 *     summary: Remove um serviço do catálogo
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
catalogoServicoRouter.delete('/:id', CatalogoServicoController.destroy);

export { catalogoServicoRouter };