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
 *     description: Retorna uma lista de todos os orçamentos gerados (RN028, RN173)
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
 *     description: Inicia a geração de um orçamento para um cliente (RN029, RN173)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cliente_id
 *             properties:
 *               agendamento_id:
 *                 type: string
 *                 format: uuid
 *               cliente_id:
 *                 type: string
 *                 format: uuid
 *               funcionario_id:
 *                 type: string
 *                 format: uuid
 *               valido_ate:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       201:
 *         description: Criado
 */
orcamentoRouter.post('/', OrcamentoController.store);

/**
 * @openapi
 * /orcamentos/{id}:
 *   get:
 *     tags:
 *       - Orçamentos
 *     summary: Busca um orçamento por ID
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
orcamentoRouter.get('/:id', OrcamentoController.show);

/**
 * @openapi
 * /orcamentos/{id}/servicos:
 *   post:
 *     tags:
 *       - Orçamentos
 *     summary: Adiciona serviço ao orçamento
 *     description: Vincula um serviço do catálogo ao orçamento (RN176)
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
 *             required:
 *               - servico_id
 *               - quantidade
 *               - preco_unitario
 *             properties:
 *               servico_id:
 *                 type: string
 *                 format: uuid
 *               quantidade:
 *                 type: integer
 *               preco_unitario:
 *                 type: number
 *     responses:
 *       201:
 *         description: Serviço adicionado
 */
orcamentoRouter.post('/:id/servicos', OrcamentoController.addServico);

/**
 * @openapi
 * /orcamentos/{id}/servicos/{item_id}:
 *   delete:
 *     tags:
 *       - Orçamentos
 *     summary: Remove serviço do orçamento
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: path
 *         name: item_id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       204:
 *         description: Removido
 */
orcamentoRouter.delete('/:id/servicos/:item_id', OrcamentoController.removeServico);

/**
 * @openapi
 * /orcamentos/{id}/produtos:
 *   post:
 *     tags:
 *       - Orçamentos
 *     summary: Adiciona produto ao orçamento
 *     description: Vincula um produto do estoque ao orçamento (RN179)
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
 *             required:
 *               - produto_id
 *               - quantidade
 *               - preco_unitario
 *             properties:
 *               produto_id:
 *                 type: string
 *                 format: uuid
 *               quantidade:
 *                 type: integer
 *               preco_unitario:
 *                 type: number
 *     responses:
 *       201:
 *         description: Produto adicionado
 */
orcamentoRouter.post('/:id/produtos', OrcamentoController.addProduto);

/**
 * @openapi
 * /orcamentos/{id}/produtos/{item_id}:
 *   delete:
 *     tags:
 *       - Orçamentos
 *     summary: Remove produto do orçamento
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: path
 *         name: item_id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       204:
 *         description: Removido
 */
orcamentoRouter.delete('/:id/produtos/:item_id', OrcamentoController.removeProduto);

/**
 * @openapi
 * /orcamentos/{id}/rejeitar:
 *   patch:
 *     tags:
 *       - Orçamentos
 *     summary: Rejeita o orçamento
 *     description: Marca o orçamento como rejeitado pelo cliente
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Rejeitado com sucesso
 */
orcamentoRouter.patch('/:id/rejeitar', OrcamentoController.rejeitar);

/**
 * @openapi
 * /orcamentos/{id}/aprovar:
 *   patch:
 *     tags:
 *       - Orçamentos
 *     summary: Aprova o orçamento
 *     description: Transforma o orçamento aprovado em imutável e pronto para execução (RN036)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Aprovado com sucesso
 */
orcamentoRouter.patch('/:id/aprovar', OrcamentoController.aprovar);

/**
 * @openapi
 * /orcamentos/{id}/enviar-addons:
 *   patch:
 *     tags:
 *       - Orçamentos
 *     summary: Envia itens extras para aprovação do cliente
 *     description: Move um orçamento aprovado para ENVIADO quando houver add-ons.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Add-ons enviados com sucesso
 */
orcamentoRouter.patch('/:id/enviar-addons', OrcamentoController.enviarAddons);
orcamentoRouter.patch('/:id/rejeitar-addons', OrcamentoController.rejeitarAddons);

/**
 * @openapi
 * /orcamentos/{id}:
 *   patch:
 *     tags:
 *       - Orçamentos
 *     summary: Atualiza dados básicos do orçamento
 *     description: Permite atualizar observações, status ou validade (RN173)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               observacoes:
 *                 type: string
 *               status:
 *                 type: string
 *               valido_ate:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       200:
 *         description: Atualizado com sucesso
 */
orcamentoRouter.patch('/:id', OrcamentoController.update);

export { orcamentoRouter };