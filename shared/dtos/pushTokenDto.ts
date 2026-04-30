export interface PushTokenDTO {
  id: string;
  usuario_id: string;
  fcm_registration_token: string;
  criado_em: Date;
  atualizado_em: Date;
}

export interface UpsertPushTokenDTO {
  usuario_id: string;
  fcm_registration_token: string;
}
