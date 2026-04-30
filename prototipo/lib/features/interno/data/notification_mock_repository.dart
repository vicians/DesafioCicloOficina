import '../../../data/mock_data.dart';
import 'notification_repository.dart';

class NotificationMockRepository implements NotificationRepository {
  final List<NotificationItem> _items;

  NotificationMockRepository()
      : _items = internalNotificationsData.map((n) {
          return NotificationItem(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            time: n.time,
            unread: n.unread,
          );
        }).toList();

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index != -1) {
      _items[index].unread = false;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    for (final item in _items) {
      item.unread = false;
    }
  }
}
