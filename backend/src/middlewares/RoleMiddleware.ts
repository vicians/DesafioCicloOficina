import { Request, Response, NextFunction } from 'express';

export const authorizeRole = (allowedRoles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = req.user;

    if (!user) {
      return res.status(401).json({ error: 'Unauthorized: Context missing or user not authenticated' });
    }

    if (!user.role) {
      return res.status(403).json({ error: 'Forbidden: User role is not defined' });
    }

    if (!allowedRoles.includes(user.role)) {
      return res.status(403).json({ error: `Forbidden: Role ${user.role} not allowed for this resource.` });
    }

    return next();
  };
};
