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
 *     description: Retorna a lista de todos os veículos cadastrados no sistema. Suporta filtragem por placa ou nome do cliente via query parameters. (RN162)
 *     parameters:
 *       - in: query
 *         name: placa
 *         schema:
 *           type: string
 *         description: Filtra por placa do veículo
 *       - in: query
 *         name: nome_cliente
 *         schema:
 *           type: string
 *         description: Filtra por nome do cliente
 *     responses:
 *       200:
 *         description: Sucesso
 */
veiculoRouter.get('/', VeiculoController.index);

/**
 * @openapi
 * /veiculos:
 *   post:
 *     tags:
 *       - Veículos
 *     summary: Cria um novo veículo
 *     description: Registra um novo veículo vinculado a um cliente (RN003, RN004, RN006)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cliente_id
 *               - placa
 *               - marca
 *               - modelo
 *               - ano
 *               - quilometragem_atual
 *             properties:
 *               cliente_id:
 *                 type: string
 *                 format: uuid
 *               placa:
 *                 type: string
 *               marca:
 *                 type: string
 *               modelo:
 *                 type: string
 *               ano:
 *                 type: integer
 *               quilometragem_atual:
 *                 type: integer
 *     responses:
 *       201:
 *         description: Criado
 */
veiculoRouter.post('/', VeiculoController.store);

/**
 * @openapi
 * /veiculos/cliente/{clienteId}:
 *   get:
 *     tags:
 *       - Veículos
 *     summary: Lista veículos por cliente
 *     description: Retorna os veículos associados a um cliente específico (RN009)
 *     parameters:
 *       - in: path
 *         name: clienteId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
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
 *           format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 */
veiculoRouter.get('/:id', VeiculoController.show);

export { veiculoRouter };