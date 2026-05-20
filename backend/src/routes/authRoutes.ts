import { Router } from 'express';
import { generateMagicLink, validateMagicLink, login, register } from '../controllers/authController';

export const authRouter = Router();

authRouter.post('/magic-link', generateMagicLink);
authRouter.get('/magic-link/:token', validateMagicLink);
authRouter.post('/login', login);
authRouter.post('/register', register);
