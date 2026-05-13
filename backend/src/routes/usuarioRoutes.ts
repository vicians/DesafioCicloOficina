import { Router } from 'express';
import { UsuarioController } from '../controllers/usuarioController';
import { authMiddleware } from '../middlewares/AuthMiddleware';
import { authorizeRole } from '../middlewares/RoleMiddleware';

const usuarioRouter = Router();

/**
 * @openapi
 * /usuarios:
 *   get:
 *     tags:
 *       - Usuários
 *     summary: Lista todos os usuários
 *     description: Retorna a lista de usuários cadastrados (Clientes e Funcionários) (RN159)
 *     responses:
 *       200:
 *         description: Sucesso
 */
usuarioRouter.get('/', authMiddleware, authorizeRole(['1']), UsuarioController.index);

/**
 * @openapi
 * /usuarios:
 *   post:
 *     tags:
 *       - Usuários
 *     summary: Cria um novo usuário
 *     description: Registra um novo cliente ou funcionário (RN001, RN005)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - tipo_id
 *               - cpf_cnpj
 *               - nome
 *               - telefone
 *               - email
 *             properties:
 *               tipo_id:
 *                 type: integer
 *                 description: ID do tipo de usuário (RN156)
 *               cpf_cnpj:
 *                 type: string
 *               nome:
 *                 type: string
 *               telefone:
 *                 type: string
 *               email:
 *                 type: string
 *               senha_hash:
 *                 type: string
 *     responses:
 *       201:
 *         description: Criado
 */
usuarioRouter.post('/', authMiddleware, authorizeRole(['1']), UsuarioController.store);

/**
 * @openapi
 * /usuarios/{id}:
 *   get:
 *     tags:
 *       - Usuários
 *     summary: Busca um usuário por ID
 *     security:
 *       - bearerAuth: []
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
usuarioRouter.get('/:id', authMiddleware, UsuarioController.show);

/**
 * @openapi
 * /usuarios/{id}:
 *   put:
 *     tags:
 *       - Usuários
 *     summary: Atualiza um usuário
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
 *               telefone:
 *                 type: string
 *               email:
 *                 type: string
 *               tipo_id:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Atualizado com sucesso
 */
usuarioRouter.put('/:id', authMiddleware, UsuarioController.update);

export { usuarioRouter };