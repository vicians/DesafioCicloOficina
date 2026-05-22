import { Request, Response, NextFunction } from 'express';

const rate_limit_ms = 4500;
const last_request_time = new Map<string, number>();
const active_requests = new Set<string>();

export const rate_limiter = (req: Request, res: Response, next: NextFunction) => {
  const identifier = req.body?.number || req.ip;

  if (!identifier) {
    next();
    return;
  }

  const now = Date.now();
  const last_time = last_request_time.get(identifier) || 0;

  if (active_requests.has(identifier)) {
    res.status(429).json({ error: 'Muitas requisições concorrentes. Por favor, aguarde.' });
    return;
  }

  if (now - last_time < rate_limit_ms) {
    res.status(429).json({ error: 'Muitas requisições rápidas. Por favor, aguarde.' });
    return;
  }

  last_request_time.set(identifier, now);
  active_requests.add(identifier);

  const timeout_id = setTimeout(() => {
    active_requests.delete(identifier);
  }, 30000);

  const cleanup = () => {
    clearTimeout(timeout_id);
    active_requests.delete(identifier);
  };

  res.on('finish', cleanup);
  res.on('close', cleanup);

  next();
};
