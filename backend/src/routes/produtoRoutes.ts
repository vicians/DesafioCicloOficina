import { Router } from 'express';
import { ProdutoController } from '../controllers/produtoController';

const produtoRouter = Router();

produtoRouter.get('/', ProdutoController.index);
produtoRouter.get('/search/:nome', ProdutoController.search);
produtoRouter.get('/:id', ProdutoController.show);
produtoRouter.post('/', ProdutoController.store);
produtoRouter.patch('/:id', ProdutoController.update);
produtoRouter.delete('/:id', ProdutoController.destroy);

export { produtoRouter };
