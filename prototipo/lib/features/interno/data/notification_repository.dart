import '../../shared/models/notification_item.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> fetchNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}
