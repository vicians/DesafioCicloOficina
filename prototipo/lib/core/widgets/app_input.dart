import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class AppInput extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final bool obscureText;
  final TextEditingController? controller;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const AppInput({
    super.key,
    this.label,
    this.placeholder,
    this.obscureText = false,
    this.controller,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 5, end: -5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 20),
    ]).animate(_shakeCtrl);
  }

  @override
  void didUpdateWidget(AppInput old) {
    super.didUpdateWidget(old);
    if (widget.errorText != null && old.errorText == null) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderCol = hasError ? red : (_focused ? navyDark : borderColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.label!,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (ctx, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child: child,
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onTap: () => setState(() => _focused = true),
            onTapOutside: (_) => setState(() => _focused = false),
            style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderCol, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderCol, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: red, width: 1.5),
              ),
              filled: true,
              fillColor: cardWhite,
              contentPadding: EdgeInsets.fromLTRB(
                widget.prefixIcon != null ? 0 : 13,
                13,
                13,
                13,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              widget.errorText!,
              style: GoogleFonts.dmSans(fontSize: 11, color: red),
            ),
          ),
      ],
    );
  }
}
