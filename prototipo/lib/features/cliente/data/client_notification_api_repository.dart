import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../data/mock_data.dart';
import 'client_notification_repository.dart';

class ClientNotificationApiRepository implements ClientNotificationRepository {
  final String baseUrl;
  final String clientId;
  final http.Client _client;

  ClientNotificationApiRepository({
    required this.baseUrl,
    required this.clientId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: {'usuario_id': clientId},
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final items = data.map((json) {
      final map = json as Map<String, dynamic>;
      final rawIso = map['criado_em'] as String?;
      return NotificationItem(
        id: map['id'] as String,
        type: map['tipo'] as String,
        title: map['titulo'] as String,
        body: map['mensagem'] as String,
        time: _formatTime(rawIso),
        timestamp: rawIso != null ? DateTime.tryParse(rawIso) : null,
        unread: !(map['lida'] as bool? ?? false),
      );
    }).toList();

    items.sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
    return items;
  }

  @override
  Future<void> markAsRead(String id) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usuario_id': clientId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao marcar notificação como lida: ${response.statusCode}');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usuario_id': clientId}),
    );

    if (response.statusCode != 204) {
      throw Exception('Falha ao marcar todas notificações como lidas: ${response.statusCode}');
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Agora há pouco';
      if (diff.inHours < 1) return 'Há ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Hoje, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inDays == 1) return 'Ontem, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
