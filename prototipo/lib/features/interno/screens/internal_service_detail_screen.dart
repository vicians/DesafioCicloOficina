import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/models/internal_service.dart';
import '../data/internal_flow_repository.dart';
import '../data/models/internal_budget_item.dart';
import 'service_client_chat_screen.dart';

class TimelineStep {
  final int id;
  final String time;
  final String date;
  final String title;
  final String desc;
  final bool done;
  final bool active;

  const TimelineStep({
    required this.id,
    required this.time,
    required this.date,
    required this.title,
    required this.desc,
    required this.done,
    required this.active,
  });
}

class InternalServiceDetailScreen extends StatefulWidget {
  final InternalService service;
  final InternalFlowRepository repository;

  const InternalServiceDetailScreen({
    super.key,
    required this.service,
    required this.repository,
  });

  @override
  State<InternalServiceDetailScreen> createState() =>
      _InternalServiceDetailScreenState();
}

class _InternalServiceDetailScreenState
    extends State<InternalServiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _showStatusSheet = false;
  late InternalService _service;
  late String _currentStatus;
  late String _pendingStatus;
  bool _isUpdating = false;

  final _statuses = [
    ('aguardando', 'Aguardando'),
    ('em_execucao', 'Em execução'),
    ('revisao_tecnica', 'Em revisão'),
    ('aguardando_retirada', 'Aguardando retirada'),
    ('concluido', 'Concluído'),
    ('cancelado', 'Cancelado'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _service = widget.service;
    _currentStatus = _service.status;
    _pendingStatus = _currentStatus;
    widget.repository.addListener(_reloadService);
    
    // Fetch full details immediately to ensure parts/labor are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadService();
    });
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reloadService);
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadService() async {
    final latest = await widget.repository.fetchServicoById(widget.service.id);
    if (!mounted || latest == null) return;
    setState(() {
      _service = latest;
      _currentStatus = latest.status;
      _pendingStatus = latest.status;
    });
  }

  Future<void> _confirmStatusChange() async {
    if (_service.sourceType != 'execucao') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Atualização manual de status está disponível apenas para OS em execução.'),
        ),
      );
      return;
    }

    if (_pendingStatus == 'cancelado' && _currentStatus != 'cancelado') {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Confirmar cancelamento',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            content: Text(
              'Deseja cancelar esse serviço?',
              style: GoogleFonts.dmSans(color: textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Voltar',
                  style: GoogleFonts.dmSans(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Sim, cancelar',
                  style: GoogleFonts.dmSans(
                    color: red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    if (_pendingStatus == _currentStatus) {
      setState(() => _showStatusSheet = false);
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final updated = await widget.repository.updateServicoStatus(
        _service.id,
        _pendingStatus,
      );
      if (!mounted) return;
      setState(() {
        _service = updated;
        _currentStatus = updated.status;
        _pendingStatus = updated.status;
        _showStatusSheet = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao atualizar status: $error')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _openClientConversation() {
    final clientId = _service.clientId;
    if (clientId == null || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente sem identificador para carregar conversa.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceClientChatScreen(
          repository: widget.repository,
          clientId: clientId,
          clientName: _service.client,
        ),
      ),
    );
  }

  List<TimelineStep> _timelineFor(InternalService svc) {
    final openedDate = _shortDate(svc.openedAt);
    final finishedDate = svc.finishedAt != null ? _shortDate(svc.finishedAt!) : '—';
    final isWaiting = svc.status == 'aguardando';
    final isInProgress = svc.status == 'em_execucao';
    final isReview = svc.status == 'revisao_tecnica';
    final isAwaitingPickup = svc.status == 'aguardando_retirada';
    final isDone = svc.status == 'concluido';
    final isCanceled = svc.status == 'cancelado';

    return [
      TimelineStep(
        id: 1,
        time: svc.time,
        date: openedDate,
        title: 'OS aberta',
        desc: 'Atendimento registrado para ${svc.client}',
        done: true,
        active: false,
      ),
      TimelineStep(
        id: 2,
        time: isWaiting ? svc.time : '—',
        date: openedDate,
        title: 'Aguardando início',
        desc: 'OS aguardando início do atendimento',
        done: !isWaiting && !isCanceled,
        active: isWaiting,
      ),
      TimelineStep(
        id: 3,
        time: (isInProgress || isReview || isAwaitingPickup || isDone) ? svc.time : '—',
        date: openedDate,
        title: 'Serviço em execução',
        desc: 'Equipe técnica executando o serviço principal',
        done: isReview || isAwaitingPickup || isDone,
        active: isInProgress,
      ),
      TimelineStep(
        id: 4,
        time: (isReview || isAwaitingPickup || isDone) ? svc.time : '—',
        date: openedDate,
        title: 'Revisão técnica',
        desc: 'Conferência e validação final do serviço',
        done: isAwaitingPickup || isDone,
        active: isReview,
      ),
      TimelineStep(
        id: 5,
        time: (isAwaitingPickup || isDone) ? svc.time : '—',
        date: isDone ? finishedDate : openedDate,
        title: 'Aguardando retirada',
        desc: 'Cliente avisado para retirada do veículo',
        done: isDone,
        active: isAwaitingPickup,
      ),
      TimelineStep(
        id: 6,
        time: (isDone || isCanceled) ? svc.time : '—',
        date: (isDone || isCanceled) ? finishedDate : '—',
        title: isCanceled ? 'OS cancelada' : 'OS concluída',
        desc: isCanceled
            ? 'Atendimento encerrado como cancelado'
            : 'Atendimento concluído e finalizado no sistema',
        done: isDone || isCanceled,
        active: false,
      ),
    ];
  }

  String _shortDate(String rawDate) {
    final parts = rawDate.split('/');
    if (parts.length != 3) return rawDate;
    final month = switch (parts[1]) {
      '01' => 'jan',
      '02' => 'fev',
      '03' => 'mar',
      '04' => 'abr',
      '05' => 'mai',
      '06' => 'jun',
      '07' => 'jul',
      '08' => 'ago',
      '09' => 'set',
      '10' => 'out',
      '11' => 'nov',
      '12' => 'dez',
      _ => parts[1],
    };
    return '${int.tryParse(parts[0]) ?? parts[0]} $month';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: Stack(
        children: [
          Column(
            children: [
              _DetailHeader(
                service: _service,
                tabCtrl: _tabCtrl,
                currentStatus: _currentStatus,
                canUpdateStatus: _service.sourceType == 'execucao',
                onOpenChat: _openClientConversation,
                onStatusTap: () => setState(() {
                  _pendingStatus = _currentStatus;
                  _showStatusSheet = true;
                }),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TimelineTab(steps: _timelineFor(_service)),
                    _DataTab(svc: _service),
                  ],
                ),
              ),
            ],
          ),
          if (_showStatusSheet) ...[
            GestureDetector(
              onTap: () => setState(() => _showStatusSheet = false),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StatusSheet(
                statuses: _statuses,
                current: _pendingStatus,
                onSelect: (s) => setState(() {
                  _pendingStatus = s;
                }),
                onConfirm: _confirmStatusChange,
                onCancel: () => setState(() => _showStatusSheet = false),
                isLoading: _isUpdating,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final InternalService service;
  final TabController tabCtrl;
  final String currentStatus;
  final bool canUpdateStatus;
  final VoidCallback onOpenChat;
  final VoidCallback onStatusTap;

  const _DetailHeader({
    required this.service,
    required this.tabCtrl,
    required this.currentStatus,
    required this.canUpdateStatus,
    required this.onOpenChat,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.client,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${service.id} · ${service.plate}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: currentStatus),
                      const SizedBox(height: 6),
                      if (canUpdateStatus)
                        GestureDetector(
                          onTap: onStatusTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Atualizar status',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          service.sourceType == 'agendamento'
                              ? 'Status do agendamento'
                              : 'Aguardando aprovação',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppButton(
                label: 'Ir para conversa do cliente',
                fullWidth: true,
                variant: AppButtonVariant.primary,
                icon: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: onOpenChat,
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: tabCtrl,
              indicatorColor: orange,
              indicatorWeight: 2.5,
              labelColor: orange,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
              labelStyle: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'Dados'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final List<TimelineStep> steps;
  const _TimelineTab({required this.steps});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;

        Color circleColor;
        Widget icon;

        if (step.done) {
          circleColor = green;
          icon = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
        } else if (step.active) {
          circleColor = orange;
          icon = Container(
            width: 10,
            height: 10,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          );
        } else {
          circleColor = borderColor;
          icon = const SizedBox.shrink();
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        boxShadow: step.active
                            ? [
                                BoxShadow(
                                  color: orange.withValues(alpha: 0.17),
                                  spreadRadius: 5,
                                )
                              ]
                            : null,
                      ),
                      child: Center(child: icon),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color:
                              step.done ? green : borderColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: step.active || step.done
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: step.done || step.active
                                    ? textPrimary
                                    : textMuted,
                              ),
                            ),
                          ),
                          if (step.time != '—')
                            Text(
                              '${step.time}, ${step.date}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: textMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.desc,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DataTab extends StatelessWidget {
  final InternalService svc;
  const _DataTab({required this.svc});

  String _formatMoney(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Cliente', svc.client),
      ('Ordem de serviço', svc.id),
      ('Veículo', svc.car),
      ('Placa', svc.plate),
      ('Mecânico', svc.mechanic),
      ('Horário', svc.time),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [cardShadow],
          ),
          child: Column(
            children: [
              ...List.generate(rows.length, (i) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              rows[i].$1,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              rows[i].$2,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < rows.length - 1)
                      const Divider(height: 1, thickness: 1, color: dividerColor),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [cardShadow],
          ),
          child: Column(
            children: [
              if (svc.budgetServices.isNotEmpty)
                _DataSection(
                  title: 'Serviços do orçamento',
                  child: Column(
                    children: List.generate(svc.budgetServices.length, (index) {
                      final item = svc.budgetServices[index];
                      return _BudgetLine(
                        item: item,
                        formatMoney: _formatMoney,
                        showDivider: index < svc.budgetServices.length - 1,
                      );
                    }),
                  ),
                ),
              if (svc.budgetServices.isNotEmpty && svc.budgetProducts.isNotEmpty)
                const Divider(height: 1, thickness: 1, color: dividerColor),
              if (svc.budgetProducts.isNotEmpty)
                _DataSection(
                  title: 'Produtos do orçamento',
                  child: Column(
                    children: List.generate(svc.budgetProducts.length, (index) {
                      final item = svc.budgetProducts[index];
                      return _BudgetLine(
                        item: item,
                        formatMoney: _formatMoney,
                        showDivider: index < svc.budgetProducts.length - 1,
                      );
                    }),
                  ),
                ),
              if (svc.budgetServices.isNotEmpty || svc.budgetProducts.isNotEmpty)
                const Divider(height: 1, thickness: 1, color: dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Valor total',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatMoney(svc.value),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: navyDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (svc.employeeObservation.trim().isNotEmpty) ...[
                const Divider(height: 1, thickness: 1, color: dividerColor),
                _DataSection(
                  title: 'Comentários do funcionário',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      svc.employeeObservation,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [cardShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progresso',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AppProgressBar(percent: svc.progress.toDouble()),
              const SizedBox(height: 6),
              Text(
                '${svc.progress}% concluído',
                style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _DataSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DataSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  final BudgetLineItem item;
  final String Function(double value) formatMoney;
  final bool showDivider;

  const _BudgetLine({
    required this.item,
    required this.formatMoney,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.qty} x ${formatMoney(item.unitPrice)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatMoney(item.total),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 1, color: dividerColor),
          ),
      ],
    );
  }
}

class _StatusSheet extends StatelessWidget {
  final List<(String, String)> statuses;
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isLoading;

  const _StatusSheet({
    required this.statuses,
    required this.current,
    required this.onSelect,
    required this.onConfirm,
    required this.onCancel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelSelected = current == 'cancelado';

    return Container(
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
          const SizedBox(height: 16),
          Text(
            'Atualizar status',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...statuses.map((s) {
            final isActive = s.$1 == current;
            final isCancelOption = s.$1 == 'cancelado';
            return GestureDetector(
              onTap: () => onSelect(s.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isCancelOption
                          ? redBg
                          : navyDark.withValues(alpha: 0.06))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? (isCancelOption ? red : navyDark)
                        : (isCancelOption ? red.withValues(alpha: 0.35) : borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.$2,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isCancelOption
                              ? red
                              : (isActive ? navyDark : textPrimary),
                        ),
                      ),
                    ),
                    if (isActive)
                      Icon(
                        Icons.check_rounded,
                        color: isCancelOption ? red : navyDark,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          AppButton(
            label: isLoading
              ? 'Atualizando...'
              : (isCancelSelected
                ? 'Cancelar serviço'
                : 'Confirmar mudança de status'),
            fullWidth: true,
            loading: isLoading,
            variant: isCancelSelected
              ? AppButtonVariant.danger
              : AppButtonVariant.primary,
            onPressed: isLoading ? null : onConfirm,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Cancelar',
            fullWidth: true,
            variant: AppButtonVariant.ghost,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
