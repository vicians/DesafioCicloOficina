import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

enum AppButtonVariant { primary, outline, danger, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool fullWidth;
  final bool small;
  final bool loading;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = false,
    this.small = false,
    this.loading = false,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null && !widget.loading;

    Color bg;
    Color fg;
    BorderSide? border;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = orange;
        fg = Colors.white;
        shadows = _pressed ? null : [orangeButtonShadow];
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = orange;
        border = const BorderSide(color: orange, width: 1.5);
        break;
      case AppButtonVariant.danger:
        bg = redBg;
        fg = red;
        border = BorderSide(color: red.withValues(alpha: 0.27), width: 1.5);
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = textSecondary;
        break;
    }

    final paddingH = widget.small ? 14.0 : 18.0;
    final paddingV = widget.small ? 8.0 : 13.0;
    final fontSize = widget.small ? 12.0 : 14.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.fullWidth ? double.infinity : null,
        transform: _pressed
            ? Matrix4.diagonal3Values(0.97, 0.97, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: disabled ? 0.6 : 1),
          borderRadius: BorderRadius.circular(12),
          border: border != null ? Border.fromBorderSide(border) : null,
          boxShadow: (!_pressed && !disabled) ? shadows : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        child: Row(
          mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.loading)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            if (widget.icon != null && !widget.loading)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: widget.icon!,
              ),
            Text(
              widget.label,
              style: GoogleFonts.dmSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fg.withValues(alpha: disabled ? 0.6 : 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
