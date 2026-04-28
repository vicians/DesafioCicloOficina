import { Request, Response, NextFunction } from 'express';
import { JWTUtils } from '../utils/JWTUtils';

export const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: 'Token not provided' });
  }

  const [, token] = authHeader.split(' ');

  try {
    const decoded = JWTUtils.verifyToken(token);
    
    // Add user info to request (optional, but common)
    // req.user = decoded; 
    
    return next();
  } catch (error) {
    return res.status(401).json({ error: 'Token invalid' });
  }
};
