import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';

// ── SettingsScreen ────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const SettingsScreen({super.key, this.onOpenDrawer});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedAvatarIndex = 0;

  static const _avatarOptions = [
    _AvatarOption(icon: Icons.person_rounded, color: Color(0xFF1C2F4A), label: 'Padrão'),
    _AvatarOption(icon: Icons.engineering_rounded, color: Color(0xFF2563EB), label: 'Mecânico'),
    _AvatarOption(icon: Icons.manage_accounts_rounded, color: Color(0xFF7C3AED), label: 'Gerente'),
    _AvatarOption(icon: Icons.support_agent_rounded, color: Color(0xFF16A34A), label: 'Atendente'),
    _AvatarOption(icon: Icons.admin_panel_settings_rounded, color: Color(0xFFF97316), label: 'Admin'),
    _AvatarOption(icon: Icons.face_rounded, color: Color(0xFFD97706), label: 'Casual'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Foto de perfil'),
                const SizedBox(height: 12),
                _AvatarGallery(
                  options: _avatarOptions,
                  selectedIndex: _selectedAvatarIndex,
                  onSelect: (i) => setState(() => _selectedAvatarIndex = i),
                ),
                const SizedBox(height: 24),
                const Divider(color: dividerColor),
                const SizedBox(height: 20),
                _SectionTitle('Conta'),
                const SizedBox(height: 12),
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  label: 'Nome de exibição',
                  value: 'Tião (Gerente)',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.store_outlined,
                  label: 'Nome da oficina',
                  value: 'Tião Oficina',
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                const Divider(color: dividerColor),
                const SizedBox(height: 20),
                _SectionTitle('Notificações'),
                const SizedBox(height: 12),
                _SettingsToggle(
                  icon: Icons.inventory_2_outlined,
                  label: 'Alertas de estoque baixo',
                  subtitle: 'Aviso quando itens ficam abaixo do mínimo',
                  value: true,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 8),
                _SettingsToggle(
                  icon: Icons.calendar_today_outlined,
                  label: 'Novos agendamentos',
                  subtitle: 'Notificação ao receber um novo agendamento',
                  value: true,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 8),
                _SettingsToggle(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orçamentos pendentes',
                  subtitle: 'Lembrete de orçamentos sem resposta',
                  value: false,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 24),
                _buildVersionFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Row(
        children: [
          if (widget.onOpenDrawer != null) ...[
            Semantics(
              label: 'Abrir menu',
              button: true,
              child: GestureDetector(
                onTap: widget.onOpenDrawer,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_rounded, size: 19, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurações',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Perfil e preferências',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFooter() {
    return Center(
      child: Text(
        'Tião Oficina · v1.0.0',
        style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
      ),
    );
  }
}

// ── Avatar Gallery ─────────────────────────────────────────────────────────────

class _AvatarOption {
  final IconData icon;
  final Color color;
  final String label;
  const _AvatarOption({required this.icon, required this.color, required this.label});
}

class _AvatarGallery extends StatelessWidget {
  final List<_AvatarOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _AvatarGallery({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione um ícone de perfil',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(options.length, (i) {
              final opt = options[i];
              final isSelected = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? navyDark : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: opt.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: opt.color, width: 2)
                              : null,
                        ),
                        child: Icon(opt.icon, color: opt.color, size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        opt.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? navyDark : textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: navyDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Salvar foto de perfil',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

// ── Settings Row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: const [cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgPage,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: navyDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Settings Toggle ───────────────────────────────────────────────────────────

class _SettingsToggle extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SettingsToggle> createState() => _SettingsToggleState();
}

class _SettingsToggleState extends State<_SettingsToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: const [cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgPage,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, size: 18, color: navyDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _value,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged(v);
            },
            activeThumbColor: navyDark,
            activeTrackColor: navyDark.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: textMuted,
      ),
    );
  }
}
