import '../../shared/models/notification_item.dart';

abstract class ClientNotificationRepository {
  Future<List<NotificationItem>> fetchNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}
