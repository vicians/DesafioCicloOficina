import { Router } from 'express';
import { CatalogoServicoController } from '../controllers/catalogoServicoController';

const catalogoServicoRouter = Router();

catalogoServicoRouter.get('/', CatalogoServicoController.index);
catalogoServicoRouter.get('/:id', CatalogoServicoController.show);
catalogoServicoRouter.post('/', CatalogoServicoController.store);
catalogoServicoRouter.patch('/:id', CatalogoServicoController.update);
catalogoServicoRouter.delete('/:id', CatalogoServicoController.destroy);

export { catalogoServicoRouter };

