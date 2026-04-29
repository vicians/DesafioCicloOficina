import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final bool isManager;
  final VoidCallback onLogout;
  final VoidCallback? onOpenServices;

  const EmployeeDashboardScreen({
    super.key,
    required this.isManager,
    required this.onLogout,
    this.onOpenServices,
  });

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  bool _showLogoutSheet = false;

  @override
  Widget build(BuildContext context) {
    final activeServices = internalServices
        .where((s) =>
            s.status == 'andamento' ||
            s.status == 'revisao' ||
            s.status == 'aguardando_retirada')
        .toList();
    final waitingServices =
        internalServices.where((s) => s.status == 'aguardando').toList();
    final todayServices = internalServices.length;
    final pendingBudget =
        internalServices.where((s) => s.status == 'orcamento').toList();

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DashboardHeader(
                isManager: widget.isManager,
                activeCount: activeServices.length,
                waitingCount: waitingServices.length,
                todayCount: todayServices,
                onLogoutTap: () => setState(() => _showLogoutSheet = true),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pendingBudget.isNotEmpty) ...[
                      _PendingBudgetBanner(service: pendingBudget.first),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'Atendimentos ativos',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...internalServices
                        .where((s) =>
                            s.status != 'concluido' &&
                            s.status != 'cancelado')
                        .map((svc) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ServiceCard(
                                svc: svc,
                                onTap: widget.onOpenServices,
                              ),
                            )),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_showLogoutSheet) ...[
          GestureDetector(
            onTap: () => setState(() => _showLogoutSheet = false),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _LogoutSheet(
              onConfirm: widget.onLogout,
              onCancel: () => setState(() => _showLogoutSheet = false),
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isManager;
  final int activeCount;
  final int waitingCount;
  final int todayCount;
  final VoidCallback onLogoutTap;

  const _DashboardHeader({
    required this.isManager,
    required this.activeCount,
    required this.waitingCount,
    required this.todayCount,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isManager ? 'Gerente' : 'Mecânico',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onLogoutTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _KpiBox(label: 'Ativos', value: '$activeCount'),
              const SizedBox(width: 8),
              _KpiBox(label: 'Aguardando', value: '$waitingCount'),
              const SizedBox(width: 8),
              _KpiBox(label: 'Hoje', value: '$todayCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  const _KpiBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBudgetBanner extends StatelessWidget {
  final InternalService service;
  const _PendingBudgetBanner({required this.service});

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orçamento aguardando aprovação',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: yellow,
                  ),
                ),
                Text(
                  '${service.client} · ${service.id}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: yellow),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final InternalService svc;
  final VoidCallback? onTap;

  const _ServiceCard({required this.svc, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.client,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${svc.car} · ${svc.plate}',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: svc.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            svc.service,
            style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 10),
          AppProgressBar(percent: svc.progress.toDouble()),
          const SizedBox(height: 6),
          Text(
            '${svc.progress}% — Mecânico: ${svc.mechanic}',
            style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
          ),
        ],
      ),
    );
  }
}

class _LogoutSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LogoutSheet({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: const BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sair do sistema',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Deseja encerrar sua sessão?',
            style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Confirmar saída',
            fullWidth: true,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Cancelar',
            fullWidth: true,
            variant: AppButtonVariant.outline,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
