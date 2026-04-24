import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = 16,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => widget.onTap != null ? setState(() => _hovered = true) : null,
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _hovered
              ? Matrix4.translationValues(0.0, -1.0, 0.0)
              : Matrix4.identity(),
          padding: widget.padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.color ?? cardWhite,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              _hovered ? cardShadowHover : cardShadow,
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
