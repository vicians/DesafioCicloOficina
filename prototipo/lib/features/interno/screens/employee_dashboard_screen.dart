import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/models/internal_service.dart';
import '../data/models/internal_budget_item.dart';
import '../data/models/scheduled_service_item.dart';
import '../data/internal_flow_repository.dart';
import '../data/scheduling_repository.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final InternalFlowRepository repository;
  final SchedulingRepository schedulingRepository;
  final ValueNotifier<int>? refreshSignal;
  final bool isManager;
  final VoidCallback onLogout;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenAlerts;
  final int unreadAlertsCount;
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenBudgets;

  const EmployeeDashboardScreen({
    super.key,
    required this.repository,
    required this.schedulingRepository,
    required this.isManager,
    required this.onLogout,
    this.refreshSignal,
    this.onOpenDrawer,
    this.onOpenAlerts,
    this.unreadAlertsCount = 0,
    this.onOpenServices,
    this.onOpenBudgets,
  });

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  bool _showLogoutSheet = false;
  late Future<_DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
    widget.repository.addListener(_reload);
    widget.refreshSignal?.addListener(_reload);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reload);
    widget.refreshSignal?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
  }

  Future<_DashboardData> _loadDashboardData() async {
    final results = await Future.wait([
      widget.repository.fetchServicos(),
      widget.repository.fetchOrcamentos(),
      widget.schedulingRepository.fetchScheduledServices(),
    ]);

    return _DashboardData(
      services: results[0] as List<InternalService>,
      budgets: results[1] as List<InternalBudgetItem>,
      scheduledServices: results[2] as List<ScheduledServiceItem>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(orange),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar dados do painel.',
              style: GoogleFonts.dmSans(color: textSecondary),
            ),
          );
        }

        final data = snapshot.data;
        final internalServices = data?.services ?? const <InternalService>[];
        final budgets = data?.budgets ?? const <InternalBudgetItem>[];
        final scheduledServices =
            data?.scheduledServices ?? const <ScheduledServiceItem>[];
        final now = DateTime.now();

        // Mantem os KPIs alinhados com as regras das telas de Serviços e Agendamentos.
        final activeExecutions = internalServices
            .where((s) => s.status != 'concluido' && s.status != 'cancelado')
            .toList();

        final openAppointments = scheduledServices
            .where(
              (item) =>
                  item.status.toLowerCase() == 'pendente' ||
                  item.status.toLowerCase() == 'confirmado',
            )
            .length;

        final pendingBudgets = budgets.where((b) => b.isPending).toList();

        // Agendamentos que cobrem hoje: [agendadoPara, agendadoPara + duracaoMinutos)
        // deve se sobrepor com [todayStart, todayEnd). Assim serviços que começaram
        // ontem e terminam hoje, ou que começam hoje e terminam amanhã, são incluídos.
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd   = todayStart.add(const Duration(days: 1));

        final todayScheduledIds = scheduledServices
            .where((s) {
              final inicio = s.agendadoPara;
              final fim    = inicio.add(Duration(minutes: s.duracaoMinutos));
              return inicio.isBefore(todayEnd) && fim.isAfter(todayStart);
            })
            .map((s) => s.id)
            .toSet();

        // Orçamentos pendentes cujo agendamento toca hoje
        final todayBudgetsRevenue = pendingBudgets
            .where((b) => b.agendamentoId != null && todayScheduledIds.contains(b.agendamentoId))
            .fold<double>(0, (sum, item) => sum + item.value);

        // Execuções ativas que ainda não foram finalizadas e já iniciaram até hoje.
        // InternalService não expõe agendamentoId, então usa openedAtDate como proxy:
        // inclui qualquer execução iniciada até o fim de hoje sem finalizado_em.
        final todayServicesRevenue = internalServices
            .where((s) => s.status != 'concluido' && s.status != 'cancelado')
            .where((s) {
              final d = s.openedAtDate;
              if (d == null) return false;
              return !d.isAfter(todayEnd) && s.finishedAtDate == null;
            })
            .fold<double>(0, (sum, item) => sum + item.value);

        final predictedRevenue = todayServicesRevenue + todayBudgetsRevenue;

        // Lógica simples de atraso: aberto há mais de 2 dias e não concluído
        final delayedServices = internalServices.where((s) {
          if (s.status == 'concluido' || s.status == 'cancelado') return false;
          try {
            final parts = s.openedAt.split('/');
            final openedDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            return now.difference(openedDate).inDays > 2;
          } catch (_) {
            return false;
          }
        }).toList();

        return Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHeader(
                    isManager: widget.isManager,
                    activeExecutions: activeExecutions.length,
                    openAppointments: openAppointments,
                    pendingBudgets: pendingBudgets.length,
                    predictedRevenue: predictedRevenue,
                    onLogoutTap: () => setState(() => _showLogoutSheet = true),
                    onOpenDrawer: widget.onOpenDrawer,
                    onOpenAlerts: widget.onOpenAlerts,
                    unreadAlertsCount: widget.unreadAlertsCount,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AlertBanner(
                          delayedCount: delayedServices.length,
                          pendingBudgets: pendingBudgets,
                          onOpenBudgets: widget.onOpenBudgets,
                          onOpenServices: widget.onOpenServices,
                        ),
                        const SizedBox(height: 14),
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
                            .where(
                              (s) =>
                                  s.status != 'concluido' &&
                                  s.status != 'cancelado',
                            )
                            .map(
                              (svc) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ServiceCard(
                                  svc: svc,
                                  onTap: widget.onOpenServices,
                                ),
                              ),
                            ),
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
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isManager;
  final int activeExecutions;
  final int openAppointments;
  final int pendingBudgets;
  final double predictedRevenue;
  final VoidCallback onLogoutTap;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenAlerts;
  final int unreadAlertsCount;

  const _DashboardHeader({
    required this.isManager,
    required this.activeExecutions,
    required this.openAppointments,
    required this.pendingBudgets,
    required this.predictedRevenue,
    required this.onLogoutTap,
    this.onOpenDrawer,
    this.onOpenAlerts,
    this.unreadAlertsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
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
              // Hamburger (manager only)
              if (isManager && onOpenDrawer != null) ...[
                Semantics(
                  label: 'Abrir menu',
                  button: true,
                  child: GestureDetector(
                    onTap: onOpenDrawer,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Avatar + name/role
              if (isManager) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 1.5,
                    ),
                    color: const Color(0xFF1E3A8A),
                  ),
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 1.55,
                      child: Image.asset(
                        'assets/images/tiao_avatar.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, stack) => Center(
                          child: Text(
                            'T',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerente',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      Text(
                        'Tião (Gerente)',
                        style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Bell with badge (manager)
                Semantics(
                  label: 'Notificações, $unreadAlertsCount não lidas',
                  button: true,
                  child: GestureDetector(
                    onTap: onOpenAlerts,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                        if (unreadAlertsCount > 0)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: red,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: navyDark, width: 1.5),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                              child: Text(
                                unreadAlertsCount > 9
                                    ? '9+'
                                    : '$unreadAlertsCount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Employee: title + logout button
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
                        'Mecânico',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Sair',
                  button: true,
                  child: GestureDetector(
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
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _KpiBox(label: 'Ativos', value: '$activeExecutions'),
              const SizedBox(width: 8),
              _KpiBox(label: 'Agendados', value: '$openAppointments'),
              const SizedBox(width: 8),
              _KpiBox(label: 'Orçamentos', value: '$pendingBudgets'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faturamento Previsto',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'R\$ ${predictedRevenue.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hoje',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: orange,
                    ),
                  ),
                ),
              ],
            ),
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

class _AlertBanner extends StatelessWidget {
  final int delayedCount;
  final List<InternalBudgetItem> pendingBudgets;
  final VoidCallback? onOpenBudgets;
  final VoidCallback? onOpenServices;

  const _AlertBanner({
    required this.delayedCount,
    required this.pendingBudgets,
    this.onOpenBudgets,
    this.onOpenServices,
  });

  @override
  Widget build(BuildContext context) {
    if (delayedCount > 0) {
      return GestureDetector(
        onTap: onOpenServices,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: redBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_off_rounded, color: red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serviços com atraso crítico',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: red,
                      ),
                    ),
                    Text(
                      '$delayedCount serviços necessitam atenção imediata',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: red),
            ],
          ),
        ),
      );
    }

    if (pendingBudgets.isNotEmpty) {
      final budget = pendingBudgets.first;
      return GestureDetector(
        onTap: onOpenBudgets,
        child: Container(
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
                      '${budget.client} · ${budget.car}',
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
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _DashboardData {
  final List<InternalService> services;
  final List<InternalBudgetItem> budgets;
  final List<ScheduledServiceItem> scheduledServices;

  const _DashboardData({
    required this.services,
    required this.budgets,
    required this.scheduledServices,
  });
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
                        fontSize: 12,
                        color: textSecondary,
                      ),
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
