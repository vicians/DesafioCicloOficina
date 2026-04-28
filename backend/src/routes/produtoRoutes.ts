import { Router } from 'express';
import { ProdutoController } from '../controllers/produtoController';

const produtoRouter = Router();

produtoRouter.get('/', ProdutoController.index);
produtoRouter.get('/search/:nome', ProdutoController.search);

produtoRouter.post('/', ProdutoController.store);

export { produtoRouter };
