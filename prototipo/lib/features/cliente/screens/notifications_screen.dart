import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../shared/models/notification_item.dart';
import 'client_screen_header.dart';

class NotificationsScreen extends StatefulWidget {
  final List<NotificationItem> items;
  final ValueChanged<String> onMarkRead;
  final VoidCallback? onMarkAllRead;

  const NotificationsScreen({
    super.key,
    required this.items,
    required this.onMarkRead,
    this.onMarkAllRead,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.items.where((item) => item.unread).length;
    return Column(
      children: [
        ClientScreenHeader(
          title: 'Alertas',
          trailing: (unreadCount == 0 || widget.onMarkAllRead == null)
              ? null
              : GestureDetector(
                  onTap: widget.onMarkAllRead,
                  child: Text(
                    'Marcar todas como lidas',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
          contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.items.length,
            separatorBuilder: (ctx, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NotifCard(
              item: widget.items[i],
              onTap: () => widget.onMarkRead(widget.items[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotifCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(item.type);
    final iconBg = _bgFor(item.type);
    final iconColor = _colorFor(item.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.unread ? cardWhite : Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          boxShadow: item.unread ? const [cardShadow] : null,
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.time,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.unread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'progress':
        return Icons.build_rounded;
      case 'budget':
        return Icons.receipt_long_rounded;
      case 'checkin':
        return Icons.directions_car_rounded;
      case 'done':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _bgFor(String type) {
    switch (type) {
      case 'progress':
        return blueBg;
      case 'budget':
        return yellowBg;
      case 'checkin':
        return purpleBg;
      case 'done':
        return greenBg;
      default:
        return dividerColor;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'progress':
        return blue;
      case 'budget':
        return yellow;
      case 'checkin':
        return purple;
      case 'done':
        return green;
      default:
        return textMuted;
    }
  }
}
