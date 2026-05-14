import { prisma } from '../config/prisma';

export type ChatHistoryMessage = {
  tipo_remetente: string;
  conteudo: string;
};

export async function resolveConversationId(
  conversacaoId: string | undefined,
  clienteId: string | undefined,
): Promise<string | null> {
  if (conversacaoId?.trim()) {
    return conversacaoId.trim();
  }

  if (!clienteId) {
    return null;
  }

  const conversation = await prisma.conversacoes_chat.findUnique({
    where: { cliente_id: clienteId },
    select: { id: true },
  });

  return conversation?.id ?? null;
}

export async function getRecentConversationMessages(
  conversacaoId: string | null,
  clienteId: string | undefined,
  limit: number,
): Promise<ChatHistoryMessage[]> {
  if (!conversacaoId || limit <= 0) {
    return [];
  }

  const orphanMessageFilter = clienteId
    ? [{ conversacao_id: null, cliente_id: clienteId }]
    : [];

  const messages = await prisma.mensagens_chat.findMany({
    where: {
      OR: [
        { conversacao_id: conversacaoId },
        ...orphanMessageFilter,
      ],
    },
    orderBy: { criado_em: 'desc' },
    take: limit,
    select: {
      tipo_remetente: true,
      conteudo: true,
    },
  });

  return messages.reverse();
}
