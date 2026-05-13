import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { TokenPayload } from '../utils/JWTUtils';

export const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: 'Unauthorized: Token is missing' });
  }

  const parts = authHeader.split(' ');

  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Unauthorized: Token is malformed' });
  }

  const token = parts[1];
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    console.error('JWT_SECRET is not defined in environment variables');
    return res.status(500).json({ error: 'Internal server error' });
  }

  try {
    const decoded = jwt.verify(token, secret) as TokenPayload;
    
    // Inject user context into the request
    req.user = decoded;
    
    return next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Unauthorized: Token has expired' });
    }
    return res.status(401).json({ error: 'Unauthorized: Token is invalid or malformed' });
  }
};
