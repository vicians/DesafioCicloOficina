import { Router } from 'express';
import { VeiculoController } from '../controllers/veiculoController';

const veiculoRouter = Router();

/**
 * @openapi
 * /veiculos:
 *   get:
 *     tags:
 *       - Veículos
 *     summary: Lista todos os veículos
 *     responses:
 *       200:
 *         description: Sucesso
 */
veiculoRouter.get('/', VeiculoController.index);

/**
 * @openapi
 * /veiculos/cliente/{clienteId}:
 *   get:
 *     tags:
 *       - Veículos
 *     summary: Lista veículos por cliente
 *     parameters:
 *       - in: path
 *         name: clienteId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sucesso
 */
veiculoRouter.get('/cliente/:clienteId', VeiculoController.listByCliente);

/**
 * @openapi
 * /veiculos/{id}:
 *   get:
 *     tags:
 *       - Veículos
 *     summary: Busca um veículo por ID
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
veiculoRouter.get('/:id', VeiculoController.show);

/**
 * @openapi
 * /veiculos/placa/{placa}:
 *   get:
 *     tags:
 *       - Veículos
 *     summary: Busca um veículo por placa
 *     parameters:
 *       - in: path
 *         name: placa
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Sucesso
 */
veiculoRouter.get('/placa/:placa', VeiculoController.showByPlaca);

/**
 * @openapi
 * /veiculos:
 *   post:
 *     tags:
 *       - Veículos
 *     summary: Cria um novo veículo
 *     responses:
 *       201:
 *         description: Criado
 */
veiculoRouter.post('/', VeiculoController.store);

export { veiculoRouter };

