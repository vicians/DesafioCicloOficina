import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';

// ── Animated side drawer (cliente) ───────────────────────────────────────────

class ClientSideDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenEditProfile;
  final VoidCallback onOpenChangePassword;
  final VoidCallback onLogoutRequest;

  const ClientSideDrawer({
    super.key,
    required this.onClose,
    required this.onOpenEditProfile,
    required this.onOpenChangePassword,
    required this.onLogoutRequest,
  });

  @override
  State<ClientSideDrawer> createState() => _ClientSideDrawerState();
}

class _ClientSideDrawerState extends State<ClientSideDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.82;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Stack(
        children: [
          // Scrim
          GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withValues(alpha: 0.52 * _fade.value),
            ),
          ),
          // Panel
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: width,
            child: FractionalTranslation(
              translation: Offset(-1 + _slide.value, 0),
              child: _DrawerPanel(
                onClose: _close,
                onOpenEditProfile: () async {
                  await _ctrl.reverse();
                  widget.onOpenEditProfile();
                },
                onOpenChangePassword: () async {
                  await _ctrl.reverse();
                  widget.onOpenChangePassword();
                },
                onLogoutRequest: () async {
                  await _ctrl.reverse();
                  widget.onLogoutRequest();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Panel content ─────────────────────────────────────────────────────────────

class _DrawerPanel extends StatelessWidget {
  final Future<void> Function() onClose;
  final Future<void> Function() onOpenEditProfile;
  final Future<void> Function() onOpenChangePassword;
  final Future<void> Function() onLogoutRequest;

  const _DrawerPanel({
    required this.onClose,
    required this.onOpenEditProfile,
    required this.onOpenChangePassword,
    required this.onLogoutRequest,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        color: cardWhite,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 28,
            offset: Offset(6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [navyDark, navyMid],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MENU',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    Semantics(
                      label: 'Fechar menu',
                      button: true,
                      child: GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/icone.jpeg',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minha Conta',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cliente · Tião Oficina',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Conta'),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Alteração de Dados',
                    description: 'Nome, e-mail e telefone',
                    onTap: onOpenEditProfile,
                  ),
                  _DrawerItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Alteração de Senha',
                    description: 'Atualizar sua senha',
                    onTap: onOpenChangePassword,
                  ),
                ],
              ),
            ),
          ),

          // ── Footer logout ────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: dividerColor)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Semantics(
              label: 'Sair da conta',
              button: true,
              child: GestureDetector(
                onTap: onLogoutRequest,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: redBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: red.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 18, color: red),
                      const SizedBox(width: 12),
                      Text(
                        'Sair da conta',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: textMuted,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Future<void> Function() onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: _pressed ? bgPage : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgPage,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 19, color: navyDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    widget.description,
                    style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: textMuted),
          ],
        ),
      ),
    );
  }
}
