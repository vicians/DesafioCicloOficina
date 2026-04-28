import { Router } from 'express';
import { UsuarioController } from '../controllers/usuarioController';

const usuarioRouter = Router();

usuarioRouter.get('/', UsuarioController.index);
usuarioRouter.get('/:id', UsuarioController.show);
usuarioRouter.get('/cpf/:cpf', UsuarioController.showByCpf);

usuarioRouter.post('/', UsuarioController.store);

export { usuarioRouter };
