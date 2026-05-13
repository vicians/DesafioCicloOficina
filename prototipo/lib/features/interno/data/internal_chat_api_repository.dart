import 'dart:convert';
import 'dart:async';
import '../../../core/api/api_helper.dart';
import 'internal_chat_repository.dart';
import 'models/internal_chat_models.dart';

class InternalChatApiRepository implements InternalChatRepository {
  final String baseUrl;

  InternalChatApiRepository({
    required this.baseUrl,
  });

  @override
  Stream<List<InternalChatConversation>> streamConversations() async* {
    // Yield an initial empty list or fire immediately, Stream.periodic waits the duration first.
    // To make it fire immediately, we yield first or use a custom stream.
    // We'll just yield from periodic and start with an initial fetch.
    
    // Initial fetch
    yield await _fetchConversations();
    
    yield* Stream.periodic(const Duration(seconds: 4)).asyncMap((_) async {
      return await _fetchConversations();
    });
  }

  Future<List<InternalChatConversation>> _fetchConversations() async {
    try {
      final response = await ApiHelper.get(
        '$baseUrl/conversacoes',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => InternalChatConversation.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Stream<List<InternalChatMessage>> streamMessages(String conversationId) async* {
    yield await _fetchMessages(conversationId);
    
    yield* Stream.periodic(const Duration(seconds: 4)).asyncMap((_) async {
      return await _fetchMessages(conversationId);
    });
  }

  Future<List<InternalChatMessage>> _fetchMessages(String conversationId) async {
    try {
      final response = await ApiHelper.get(
        '$baseUrl/conversacoes/$conversationId/mensagens',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => InternalChatMessage.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> sendMessage(String conversationId, String text, String senderType) async {
    await ApiHelper.post(
      '$baseUrl/conversacoes/$conversationId/mensagens',
      {
        'conteudo': text,
        'tipo_remetente': senderType,
      },
    ).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    await ApiHelper.patch(
      '$baseUrl/conversacoes/$conversationId/lidas',
      {'lida': true},
    ).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> toggleHandoff(String conversationId, bool isBotPaused) async {
    await ApiHelper.patch(
      '$baseUrl/conversacoes/$conversationId/handoff',
      {'ia_pausada': isBotPaused},
    ).timeout(const Duration(seconds: 5));
  }
}
