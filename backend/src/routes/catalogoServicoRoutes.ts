import { Router } from 'express';
import { CatalogoServicoController } from '../controllers/catalogoServicoController';

const catalogoServicoRouter = Router();

catalogoServicoRouter.get('/', CatalogoServicoController.index);
catalogoServicoRouter.post('/', CatalogoServicoController.store);

export { catalogoServicoRouter };
