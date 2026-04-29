import { TokenPayload } from '../../utils/JWTUtils';

declare global {
  namespace Express {
    export interface Request {
      user?: TokenPayload;
    }
  }
}
