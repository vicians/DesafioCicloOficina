import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../data/mock_data.dart';

class InternalNotificationsScreen extends StatelessWidget {
  final List<NotificationItem> items;
  final ValueChanged<String> onMarkRead;

  const InternalNotificationsScreen({
    super.key,
    required this.items,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navyDark, navyMid],
            ),
          ),
          child: Text(
            'Alertas',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma notificação nova',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _NotifCard(
                    item: items[i],
                    onTap: () => onMarkRead(items[i].id),
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
      case 'new_schedule':
        return Icons.event_available_rounded;
      case 'approved_budget':
        return Icons.receipt_long_rounded;
      case 'low_stock':
        return Icons.inventory_2_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _bgFor(String type) {
    switch (type) {
      case 'new_schedule':
        return blueBg;
      case 'approved_budget':
        return greenBg;
      case 'low_stock':
        return yellowBg;
      default:
        return dividerColor;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'new_schedule':
        return blue;
      case 'approved_budget':
        return green;
      case 'low_stock':
        return yellow;
      default:
        return textMuted;
    }
  }
}
