import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/client_flow_repository.dart';
import '../data/models/client_models.dart';
import 'client_screen_header.dart';

class BudgetApprovalScreen extends StatefulWidget {
  final ClientFlowRepository repository;
  const BudgetApprovalScreen({super.key, required this.repository});

  @override
  State<BudgetApprovalScreen> createState() => _BudgetApprovalScreenState();
}

class _BudgetApprovalScreenState extends State<BudgetApprovalScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _error = false;
  bool _approved = false;
  bool _refused = false;
  bool _canceled = false;
  ServiceModel? _service;

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
    _loadService();
  }

  Future<void> _loadService() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final svc = await widget.repository.fetchCurrentService();
      if (!mounted) return;
      setState(() {
        _service = svc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _approvedCtrl.dispose();
    super.dispose();
  }

  void _handleApprove() async {
    if (_service == null) return;
    setState(() => _loading = true);
    try {
      await widget.repository.approveBudget(_service!.id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _approved = true;
      });
      _approvedCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aprovar: $e')),
      );
    }
  }

  void _handleRefuse() async {
    if (_service == null) return;
    setState(() => _loading = true);
    try {
      await widget.repository.rejectBudgetChange(_service!.id);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _loading = false;
        _refused = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alteração recusada. O orçamento anterior foi mantido.',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: navyDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao rejeitar: $e'), backgroundColor: red),
      );
    }
  }

  void _handleCancel() async {
    if (_service == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar atendimento'),
        content: const Text('Deseja cancelar o agendamento e o atendimento? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancelar atendimento')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await widget.repository.cancelService(
        budgetId: _service!.id,
        agendamentoId: _service!.agendamentoId,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _canceled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atendimento cancelado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar atendimento: $e'), backgroundColor: red),
      );
    }
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final svc = _service;
    
    if (_loading) {
      return Scaffold(
        backgroundColor: bgPage,
        body: const Center(child: CircularProgressIndicator(color: orange)),
      );
    }

    if (_error) {
      return Scaffold(
        backgroundColor: bgPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar orçamento',
                style: GoogleFonts.dmSans(color: textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Tentar novamente',
                onPressed: _loadService,
                variant: AppButtonVariant.outline,
              ),
            ],
          ),
        ),
      );
    }

    if (svc == null || (svc.status != 'orcamento' && svc.status != 'enviado' && svc.status != 'rascunho' && !_approved && !_canceled)) {
      return Scaffold(
        backgroundColor: bgPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, color: textMuted.withValues(alpha: 0.5), size: 64),
              const SizedBox(height: 16),
              Text(
                'Nenhum orçamento pendente',
                style: GoogleFonts.dmSans(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Você será notificado quando um novo\norçamento estiver disponível.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final parts = svc.budgetItems.where((i) => i.type == 'part').toList();
    final labor = svc.budgetItems.where((i) => i.type == 'labor').toList();
    final partsTotal = parts.fold(0.0, (s, i) => s + i.total);
    final laborTotal = labor.fold(0.0, (s, i) => s + i.total);

    return Scaffold(
      backgroundColor: bgPage,
      body: Column(
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

    if (_canceled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: redBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: red.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Atendimento cancelado. O item foi movido para seu histórico.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: red,
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
              color: blueBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: blue.withValues(alpha: 0.3)),
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
                        color: blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.undo_rounded,
                          color: blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alteração recusada',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Seguimos com o orçamento anterior. Você pode acompanhar a execução normalmente.',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: textPrimary),
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
          label: 'Rejeitar alteração',
          fullWidth: true,
          variant: AppButtonVariant.outline,
          onPressed: _loading ? null : _handleRefuse,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Cancelar atendimento',
          fullWidth: true,
          variant: AppButtonVariant.danger,
          onPressed: _loading ? null : _handleCancel,
        ),
      ],
    );
  }

  Widget _buildHeader(ServiceModel svc) {
    final badgeStatus = _approved
      ? 'aprovado'
      : (_canceled ? 'cancelado' : (_refused ? 'confirmado' : 'orcamento'));
    return ClientScreenHeader(
      title: 'Orçamento',
      subtitle: '${svc.id} · ${svc.car} · ${svc.plate}',
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: StatusBadge(
          key: ValueKey(badgeStatus),
          status: badgeStatus,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
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
              'Orçamento aguardando sua resposta. Você pode aprovar, rejeitar a alteração ou cancelar o atendimento.',
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
