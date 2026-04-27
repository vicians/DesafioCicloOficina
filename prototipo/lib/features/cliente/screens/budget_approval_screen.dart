import 'package:flutter/material.dart';
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
    with TickerProviderStateMixin {
  bool _loading = false;
  bool _approved = false;
  bool _showRefuseCard = false;

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
    setState(() {
      _loading = false;
      _approved = true;
    });
    _approvedCtrl.forward();
  }

  void _handleRefuse() {
    setState(() => _showRefuseCard = !_showRefuseCard);
  }

  @override
  Widget build(BuildContext context) {
    final svc = currentService;

    if (_approved) {
      return Scaffold(
        backgroundColor: bgPage,
        body: SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: _approvedScale,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Orçamento aprovado!',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O serviço será iniciado em breve.',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Voltar ao início',
                      fullWidth: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAlertBanner(),
                    const SizedBox(height: 14),
                    _buildItemsCard(svc),
                    const SizedBox(height: 12),
                    _buildTotalCard(svc),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Aprovar orçamento',
                      fullWidth: true,
                      loading: _loading,
                      onPressed: _loading ? null : _handleApprove,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Recusar',
                      fullWidth: true,
                      variant: AppButtonVariant.outline,
                      onPressed: _handleRefuse,
                    ),
                    if (_showRefuseCard) ...[
                      const SizedBox(height: 12),
                      _buildRefuseCard(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Aprovação de orçamento',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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

  Widget _buildItemsCard(ServiceModel svc) {
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
          ...List.generate(svc.budgetItems.length, (i) {
            final item = svc.budgetItems[i];
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style:
                              GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                        ),
                      ),
                      Text(
                        'R\$ ${item.total.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < svc.budgetItems.length - 1)
                  const Divider(height: 1, thickness: 1, color: dividerColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ServiceModel svc) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'Total',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'R\$ ${svc.budgetTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            'Pendente',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefuseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entre em contato para discutir',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: red,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ligue para a oficina e fale diretamente com o responsável.',
            style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone_rounded, color: red, size: 18),
              const SizedBox(width: 8),
              Text(
                '(11) 99999-8888',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
