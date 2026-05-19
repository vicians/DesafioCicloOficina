import { Request, Response, NextFunction } from 'express';

/**
 * Middleware para validar a comunicação interna entre serviços.
 * Verifica se o header 'X-Internal-Token' corresponde à variável de ambiente 'INTERNAL_AUTH_TOKEN'.
 */
export const internalAuthMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const internalToken = req.headers['x-internal-token'];
  const expectedToken = process.env.INTERNAL_AUTH_TOKEN;

  if (!expectedToken) {
    console.error('[AUTH] INTERNAL_AUTH_TOKEN não configurado no ambiente.');
    return res.status(500).json({ error: 'Erro interno de configuração de segurança.' });
  }

  if (internalToken !== expectedToken) {
    console.warn(`[AUTH] Acesso negado para o IP: ${req.ip} - Token inválido ou ausente.`);
    return res.status(401).json({ error: 'Unauthorized' });
  }

  next();
};
