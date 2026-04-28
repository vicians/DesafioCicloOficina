import { Router } from 'express';
import { UsuarioController } from '../controllers/usuarioController';

const usuarioRouter = Router();

// GET /usuarios?nome=&cpf_cnpj=&tipo_id=
usuarioRouter.get('/', UsuarioController.index);
usuarioRouter.get('/:id', UsuarioController.show);
usuarioRouter.post('/', UsuarioController.store);
usuarioRouter.put('/:id', UsuarioController.update);

export { usuarioRouter };

