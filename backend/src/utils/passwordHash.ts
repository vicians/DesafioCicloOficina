import bcrypt from 'bcrypt';

/**
 * Gera um hash seguro para a senha
 * 
 * @param password Senha em texto puro
 * @returns Promise com o hash gerado
 */
export const hashPassword = async (password: string): Promise<string> => {
    const saltRounds = 10;
    return bcrypt.hash(password, saltRounds);
};

/**
 * Compara uma senha em texto puro com um hash
 * 
 * @param password Senha em texto puro
 * @param hash Hash salvo no banco
 * @returns Promise booleana (true se for igual)
 */
export const comparePassword = async (password: string, hash: string): Promise<boolean> => {
    return bcrypt.compare(password, hash);
};
