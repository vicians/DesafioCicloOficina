import { Router } from 'express';
import { OficinaController } from '../controllers/oficinaController';
import { authMiddleware } from '../middlewares/AuthMiddleware';
import { authorizeRole } from '../middlewares/RoleMiddleware';

const oficinaRouter = Router();

oficinaRouter.get('/', authMiddleware, OficinaController.index);
oficinaRouter.get('/:id', authMiddleware, OficinaController.show);
oficinaRouter.patch('/:id', authMiddleware, authorizeRole(['1']), OficinaController.update);

export { oficinaRouter };
