import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

/// Botão flutuante de acesso rápido (Speed Dial).
/// Expande para revelar "Agendar serviço" e "Falar com suporte".
class QuickActionFab extends StatefulWidget {
  final Future<void> Function()? onScheduleTap;

  const QuickActionFab({
    super.key,
    this.onScheduleTap,
  });

  @override
  State<QuickActionFab> createState() => _QuickActionFabState();
}

class _QuickActionFabState extends State<QuickActionFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _rotateTurns;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    // Rotação 0° → 45°
    _rotateTurns = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Remove os sub-botões da árvore ao fim da animação de fechar
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _open = false);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _ctrl.reverse();
    } else {
      setState(() => _open = true);
      _ctrl.forward(from: 0);
    }
  }

  void _triggerAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(color: Colors.white),
        ),
        backgroundColor: navyDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleScheduleAction(BuildContext context) async {
    _toggle();

    if (widget.onScheduleTap == null) {
      _triggerAction(context, 'Agendamento em breve disponível');
      return;
    }

    await widget.onScheduleTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Sub-ações — só entram na árvore quando abertas
        if (_open)
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SubAction(
                    key: const Key('fab_schedule'),
                    icon: Icons.calendar_month_rounded,
                    label: 'Agendar serviço',
                    onTap: () => _handleScheduleAction(context),
                  ),
                  const SizedBox(height: 10),
                  _SubAction(
                    key: const Key('fab_support'),
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Falar com suporte',
                    onTap: () async {
                      _toggle();
                      final Uri url = Uri.parse('https://wa.me/5532984895095');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (context.mounted) {
                          _triggerAction(context, 'Não foi possível abrir o WhatsApp');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

        // Botão principal
        GestureDetector(
          key: const Key('fab_main'),
          onTap: _toggle,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: orange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55F97316),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: RotationTransition(
              turns: _rotateTurns,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SubAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: navyDark,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: navyDark,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: orange, size: 20),
          ),
        ],
      ),
    );
  }
}
