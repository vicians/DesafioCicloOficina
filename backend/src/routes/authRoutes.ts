import { Router } from 'express';
import { generateMagicLink, validateMagicLink } from '../controllers/authController';

export const authRouter = Router();

authRouter.post('/magic-link', generateMagicLink);
authRouter.get('/magic-link/:token', validateMagicLink);
