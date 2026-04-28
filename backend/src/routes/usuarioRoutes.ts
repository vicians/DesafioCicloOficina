import { Router } from 'express';
import { UsuarioController } from '../controllers/usuarioController';

const usuarioRouter = Router();

/**
 * @openapi
 * /usuarios:
 *   get:
 *     tags:
 *       - Usuários
 *     summary: Lista todos os usuários
 *     responses:
 *       200:
 *         description: Sucesso
 */
usuarioRouter.get('/', UsuarioController.index);

/**
 * @openapi
 * /usuarios/{id}:
 *   get:
 *     tags:
 *       - Usuários
 *     summary: Busca um usuário por ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sucesso
 */
usuarioRouter.get('/:id', UsuarioController.show);

/**
 * @openapi
 * /usuarios/cpf/{cpf}:
 *   get:
 *     tags:
 *       - Usuários
 *     summary: Busca um usuário por CPF
 *     parameters:
 *       - in: path
 *         name: cpf
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sucesso
 */
usuarioRouter.get('/cpf/:cpf', UsuarioController.showByCpf);

/**
 * @openapi
 * /usuarios:
 *   post:
 *     tags:
 *       - Usuários
 *     summary: Cria um novo usuário
 *     responses:
 *       201:
 *         description: Criado
 */
usuarioRouter.post('/', UsuarioController.store);

export { usuarioRouter };
