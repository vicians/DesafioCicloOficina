export interface NotificationDTO {
  id: string;
  usuario_id: string;
  tipo: string;
  titulo: string;
  mensagem: string;
  referencia_id?: string;
  referencia_tipo?: string;
  lida: boolean;
  lido_em?: Date;
  criado_em: Date;
}

export interface CreateNotificationDTO {
  usuario_id: string;
  tipo: string;
  titulo: string;
  mensagem: string;
  referencia_id?: string;
  referencia_tipo?: string;
}
