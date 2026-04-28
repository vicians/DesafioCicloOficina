import jwt from 'jsonwebtoken';

// COMO AINDA NÃO TEMOS OS MODELS VOU DEIXAR ISSO AQUI MESMO POR HORA.
interface TokenPayload {
  id: string;
  email: string;
  role?: string;
}

class JWTUtils {
  private static readonly SECRET = process.env.JWT_SECRET || 'fallback_secret';
  private static readonly EXPIRES_IN = process.env.JWT_EXPIRATION || '1d';

  public static generateToken(payload: TokenPayload): string {
    return jwt.sign(payload, this.SECRET, {
      expiresIn: this.EXPIRES_IN as any,
    });
  }

  public static verifyToken(token: string): TokenPayload {
    try {
      return jwt.verify(token, this.SECRET) as TokenPayload;
    } catch (error) {
      throw new Error('Invalid or expired token');
    }
  }
}

export { JWTUtils, TokenPayload };
