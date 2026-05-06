import 'models/internal_chat_models.dart';

abstract class InternalChatRepository {
  Stream<List<InternalChatConversation>> streamConversations();
  Stream<List<InternalChatMessage>> streamMessages(String conversationId);
  Future<void> sendMessage(String conversationId, String text, String senderType);
  Future<void> markAsRead(String conversationId);
  Future<void> toggleHandoff(String conversationId, bool isBotPaused);
}
