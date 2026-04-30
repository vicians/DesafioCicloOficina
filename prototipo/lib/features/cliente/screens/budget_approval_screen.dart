import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/mock_data.dart';

class BudgetApprovalScreen extends StatefulWidget {
  const BudgetApprovalScreen({super.key});

  @override
  State<BudgetApprovalScreen> createState() => _BudgetApprovalScreenState();
}

class _BudgetApprovalScreenState extends State<BudgetApprovalScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _approved = false;
  bool _refused = false;

  late AnimationController _approvedCtrl;
  late Animation<double> _approvedScale;

  @override
  void initState() {
    super.initState();
    _approvedCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _approvedScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _approvedCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _approvedCtrl.dispose();
    super.dispose();
  }

  void _handleApprove() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _approved = true;
    });
    _approvedCtrl.forward();
  }

  void _handleRefuse() {
    HapticFeedback.heavyImpact();
    setState(() => _refused = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recusa registrada. Entre em contato com a oficina.',
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final svc = currentService;
    final parts = svc.budgetItems.where((i) => i.type == 'part').toList();
    final labor = svc.budgetItems.where((i) => i.type == 'labor').toList();
    final partsTotal = parts.fold(0.0, (s, i) => s + i.total);
    final laborTotal = labor.fold(0.0, (s, i) => s + i.total);

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(svc),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_approved && !_refused) ...[
                      _buildAlertBanner(),
                      const SizedBox(height: 14),
                    ],
                    _buildItemsCard(parts, labor, partsTotal, laborTotal),
                    const SizedBox(height: 12),
                    _buildTotalCard(svc),
                    const SizedBox(height: 24),
                    _buildActions(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_approved) {
      return ScaleTransition(
        scale: _approvedScale,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: greenBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: green, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orçamento aprovado!',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'O serviço será iniciado em breve.',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_refused) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: redBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Entre em contato com a oficina',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Recusa registrada. Ligue para discutir o orçamento com o responsável.',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: textPrimary),
                ),
                const SizedBox(height: 14),
                Text(
                  '(11) 99999-8888',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: red,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Aprovar Tudo',
          fullWidth: true,
          loading: _loading,
          onPressed: _loading ? null : _handleApprove,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Rejeitar',
          fullWidth: true,
          variant: AppButtonVariant.outline,
          onPressed: _handleRefuse,
        ),
      ],
    );
  }

  Widget _buildHeader(ServiceModel svc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          Text(
            'Aprovação de Orçamento',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            svc.id,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            '${svc.car} · ${svc.plate}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: yellowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: yellow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: yellow, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Orçamento aguardando sua aprovação. O serviço só será iniciado após a confirmação.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: yellow,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(
    List<BudgetItem> parts,
    List<BudgetItem> labor,
    double partsTotal,
    double laborTotal,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Itens do orçamento',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: dividerColor),
          _SectionHeader(label: 'Peças'),
          ...parts.map((item) => _PartRow(item: item, fmt: _fmt)),
          _SubtotalRow(label: 'Subtotal peças', value: _fmt(partsTotal)),
          const Divider(height: 1, thickness: 1, color: dividerColor),
          _SectionHeader(label: 'Mão de obra'),
          ...labor.map((item) => _LaborRow(item: item, fmt: _fmt)),
          _SubtotalRow(label: 'Subtotal mão de obra', value: _fmt(laborTotal)),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ServiceModel svc) {
    final badgeColor = _approved ? green : (_refused ? red : yellow);
    final badgeBg = _approved ? greenBg : (_refused ? redBg : yellowBg);
    final badgeLabel = _approved ? 'Aprovado' : (_refused ? 'Recusado' : 'Pendente');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: navyDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total do orçamento',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                _fmt(svc.budgetTotal),
                style: GoogleFonts.dmSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  final BudgetItem item;
  final String Function(double) fmt;
  const _PartRow({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final hasDetail = item.qty != null && item.unitPrice != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                if (hasDetail)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${item.qty} × ${fmt(item.unitPrice!)}',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmt(item.total),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaborRow extends StatelessWidget {
  final BudgetItem item;
  final String Function(double) fmt;
  const _LaborRow({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmt(item.total),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtotalRow extends StatelessWidget {
  final String label;
  final String value;
  const _SubtotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: dividerColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
