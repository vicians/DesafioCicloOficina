import bcrypt from 'bcrypt';

class PasswordUtils {
    private static readonly SALT_ROUNDS = 10;
    /**
     * Gera um hash seguro para a senha
     * 
     * @param password Senha em texto puro
     * @returns Promise com o hash gerado
     */
    public static async hash(password: string): Promise<string> {
        return bcrypt.hash(password, this.SALT_ROUNDS);
    }

    /**
     * Compara uma senha em texto puro com um hash
     * 
     * @param password Senha em texto puro
     * @param hash Hash salvo no banco
     * @returns Promise booleana (true se for igual)
     */
    public static async compare(password: string, hash: string): Promise<boolean> {
        return bcrypt.compare(password, hash);
    }
}

export { PasswordUtils };
