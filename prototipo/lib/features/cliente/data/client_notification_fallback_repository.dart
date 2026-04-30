import '../../../data/mock_data.dart';
import 'client_notification_repository.dart';

class ClientNotificationFallbackRepository implements ClientNotificationRepository {
  final ClientNotificationRepository primary;
  final ClientNotificationRepository fallback;

  ClientNotificationFallbackRepository({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      return await primary.fetchNotifications();
    } catch (_) {
      return fallback.fetchNotifications();
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await primary.markAsRead(id);
    } catch (_) {
      await fallback.markAsRead(id);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await primary.markAllAsRead();
    } catch (_) {
      await fallback.markAllAsRead();
    }
  }
}
