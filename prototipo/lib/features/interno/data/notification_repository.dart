import '../../../data/mock_data.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> fetchNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}
