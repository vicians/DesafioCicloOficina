import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppProgressBar extends StatelessWidget {
  final double percent;
  final Color? color;
  final double height;

  const AppProgressBar({
    super.key,
    required this.percent,
    this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? orange;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        decoration: const BoxDecoration(color: borderColor),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (percent / 100).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c, c.withValues(alpha: 0.73)],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}
