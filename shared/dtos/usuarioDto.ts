export interface UsuarioDTO {
  id: string;
  tipo_id: number;
  cpf_cnpj: string;
  nome: string;
  telefone: string;
  email?: string;
  criado_em?: Date;
}

export interface CreateUsuarioDTO {
  tipo_id: number;
  cpf_cnpj: string;
  nome: string;
  telefone: string;
  email?: string;
  senha_hash: string;
}

export interface LoginDTO {
  email_ou_telefone: string;
  senha_hash: string;
}
