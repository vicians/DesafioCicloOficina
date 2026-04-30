import '../../../data/mock_data.dart';

abstract class ClientNotificationRepository {
  Future<List<NotificationItem>> fetchNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}
