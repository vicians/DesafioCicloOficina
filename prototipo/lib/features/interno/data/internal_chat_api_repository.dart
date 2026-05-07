import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'internal_chat_repository.dart';
import 'models/internal_chat_models.dart';

class InternalChatApiRepository implements InternalChatRepository {
  final String baseUrl;
  final http.Client _client;

  InternalChatApiRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers {
    // TODO: fetch JWT token from local storage
    const token = 'YOUR_JWT_TOKEN_HERE';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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
      final response = await _client.get(
        Uri.parse('$baseUrl/conversacoes'),
        headers: _headers,
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
      final response = await _client.get(
        Uri.parse('$baseUrl/conversacoes/$conversationId/mensagens'),
        headers: _headers,
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
    await _client.post(
      Uri.parse('$baseUrl/conversacoes/$conversationId/mensagens'),
      headers: _headers,
      body: jsonEncode({
        'conteudo': text,
        'tipo_remetente': senderType,
      }),
    ).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    await _client.patch(
      Uri.parse('$baseUrl/conversacoes/$conversationId/lidas'),
      headers: _headers,
      body: jsonEncode({'lida': true}),
    ).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> toggleHandoff(String conversationId, bool isBotPaused) async {
    await _client.patch(
      Uri.parse('$baseUrl/conversacoes/$conversationId/handoff'),
      headers: _headers,
      body: jsonEncode({'ia_pausada': isBotPaused}),
    ).timeout(const Duration(seconds: 5));
  }
}
