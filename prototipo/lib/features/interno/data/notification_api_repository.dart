import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../data/mock_data.dart';
import 'notification_repository.dart';

class NotificationApiRepository implements NotificationRepository {
  final String baseUrl;
  final int internalUserTypeId;
  final http.Client _client;
  String? _resolvedUsuarioId;

  NotificationApiRepository({
    required this.baseUrl,
    required this.internalUserTypeId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<String?> _resolveUsuarioId() async {
    if (_resolvedUsuarioId != null) return _resolvedUsuarioId;

    final uri = Uri.parse('$baseUrl/usuarios').replace(
      queryParameters: {'tipo_id': internalUserTypeId.toString()},
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final List<dynamic> users = jsonDecode(response.body) as List<dynamic>;
    if (users.isEmpty) return null;

    final first = users.first as Map<String, dynamic>;
    final id = first['id'] as String?;
    if (id == null || id.isEmpty) return null;

    _resolvedUsuarioId = id;
    return _resolvedUsuarioId;
  }

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final usuarioId = await _resolveUsuarioId();
    if (usuarioId == null) return [];

    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: {'usuario_id': usuarioId},
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((json) {
      final map = json as Map<String, dynamic>;
      return NotificationItem(
        id: map['id'] as String,
        type: map['tipo'] as String,
        title: map['titulo'] as String,
        body: map['mensagem'] as String,
        time: _formatTime(map['criado_em'] as String?),
        unread: !(map['lida'] as bool? ?? false),
      );
    }).toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    final usuarioId = await _resolveUsuarioId();
    if (usuarioId == null) {
      throw Exception('usuario_id interno não resolvido para markAsRead');
    }

    final response = await _client.patch(
      Uri.parse('$baseUrl/notifications/$id/read').replace(
        queryParameters: const {},
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usuario_id': usuarioId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao marcar notificação como lida: ${response.statusCode}');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final usuarioId = await _resolveUsuarioId();
    if (usuarioId == null) {
      throw Exception('usuario_id interno não resolvido para markAllAsRead');
    }

    final response = await _client.patch(
      Uri.parse('$baseUrl/notifications/read-all').replace(
        queryParameters: const {},
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usuario_id': usuarioId}),
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
