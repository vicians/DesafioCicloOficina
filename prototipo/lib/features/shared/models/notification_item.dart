class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final String time;
  final DateTime? timestamp;
  bool unread;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.timestamp,
    required this.unread,
  });
}
