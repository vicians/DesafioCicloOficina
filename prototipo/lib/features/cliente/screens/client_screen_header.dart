import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';

class ClientScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsetsGeometry? contentPadding;
  final double childSpacing;

  const ClientScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.contentPadding,
    this.childSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = contentPadding ??
        EdgeInsets.fromLTRB(18, 14, 18, child != null ? 24 : 16);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: resolvedPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ],
                ],
              ),
              if (child != null) ...[
                SizedBox(height: childSpacing),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}