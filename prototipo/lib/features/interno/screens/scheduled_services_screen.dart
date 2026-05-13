import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/internal_flow_repository.dart';
import '../data/models/internal_budget_item.dart';
import '../data/models/scheduled_service_item.dart';
import '../data/scheduling_repository.dart';
import 'budget_detail_screen.dart';

class ScheduledServicesScreen extends StatefulWidget {
  final SchedulingRepository repository;
  final InternalFlowRepository? budgetRepository;
  final ValueNotifier<int>? refreshSignal;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenBudgets;

  const ScheduledServicesScreen({
    super.key,
    required this.repository,
    this.budgetRepository,
    this.refreshSignal,
    this.onOpenDrawer,
    this.onOpenServices,
    this.onOpenBudgets,
  });

  @override
  State<ScheduledServicesScreen> createState() =>
      _ScheduledServicesScreenState();
}

class _ScheduledServicesScreenState extends State<ScheduledServicesScreen> {
  late Future<List<ScheduledServiceItem>> _future;
  String _search = '';
  String _statusFilter = 'todos';
  bool _confirmingReceipt = false;
  bool _openingBudget = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchScheduledServices();
    widget.refreshSignal?.addListener(_onRefreshSignal);
  }

  void _onRefreshSignal() => _reload();

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onRefreshSignal);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final next = widget.repository.fetchScheduledServices();
    if (mounted) setState(() { _future = next; });
    await next;
  }

  List<ScheduledServiceItem> _applyFilters(List<ScheduledServiceItem> src) {
    final q = _search.trim().toLowerCase();
    return src.where((item) {
      final matchStatus = _statusFilter == 'todos' ||
          item.status.toLowerCase() == _statusFilter;
      if (!matchStatus) return false;
      if (q.isEmpty) return true;
      return item.clienteNome.toLowerCase().contains(q) ||
          item.veiculoDescricao.toLowerCase().contains(q) ||
          item.placa.toLowerCase().contains(q);
    }).toList();
  }

  int _countByStatus(List<ScheduledServiceItem> all, String status) =>
      all.where((i) => i.status.toLowerCase() == status).length;

  Future<void> _confirmReceipt(ScheduledServiceItem item) async {
    if (_confirmingReceipt) return;
    setState(() => _confirmingReceipt = true);
    try {
      final serviceId = await widget.repository.confirmScheduleToService(
        schedule: item,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Agendamento confirmado. OS aberta: $serviceId'),
        action: widget.onOpenServices == null
            ? null
            : SnackBarAction(
                label: 'Abrir', onPressed: widget.onOpenServices!),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao confirmar recebimento: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirmingReceipt = false);
    }
  }

  Future<void> _openBudget(ScheduledServiceItem item) async {
    if (_openingBudget) return;
    setState(() => _openingBudget = true);
    try {
      final budgetId =
          await widget.repository.openScheduleBudget(schedule: item);
      await _reload();
      if (!mounted) return;

      if (widget.budgetRepository != null) {
        final budgets = await widget.budgetRepository!.fetchOrcamentos();
        if (!mounted) return;
        InternalBudgetItem? target;
        for (final b in budgets) {
          if (b.id == budgetId) {
            target = b;
            break;
          }
        }
        if (target != null) {
          final result = await Navigator.push<Object?>(
            context,
            MaterialPageRoute(
              builder: (_) => BudgetDetailScreen(
                repository: widget.budgetRepository!,
                budget: target!,
              ),
            ),
          );
          if (!mounted) return;
          if (result == true) {
            final refreshed =
                await widget.budgetRepository!.fetchOrcamentos();
            if (!mounted) return;
            InternalBudgetItem? ref;
            for (final b in refreshed) {
              if (b.id == budgetId) {
                ref = b;
                break;
              }
            }
            if (ref != null && ref.status.toLowerCase() == 'aprovado') {
              await widget.budgetRepository!.sendAddons(budgetId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Alterações enviadas para aprovação do cliente.'),
              ));
            }
          }
          await _reload();
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Orçamento pronto: $budgetId'),
        action: widget.onOpenBudgets == null
            ? null
            : SnackBarAction(
                label: 'Abrir', onPressed: widget.onOpenBudgets!),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao abrir orçamento: $e')));
    } finally {
      if (mounted) setState(() => _openingBudget = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          onSearch: (v) => setState(() => _search = v),
          onOpenDrawer: widget.onOpenDrawer,
        ),
        Expanded(
          child: FutureBuilder<List<ScheduledServiceItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Erro ao carregar agendamentos',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: textSecondary)),
                );
              }

              final all = snapshot.data ?? const [];
              final filtered = _applyFilters(all);

              return Column(
                children: [
                  _FilterBar(
                    active: _statusFilter,
                    onChange: (v) => setState(() => _statusFilter = v),
                    pending: _countByStatus(all, 'pendente'),
                    confirmed: _countByStatus(all, 'confirmado'),
                    canceled: _countByStatus(all, 'cancelado'),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyState(onRefresh: _reload)
                        : RefreshIndicator(
                            onRefresh: _reload,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _ScheduledCard(
                                item: filtered[i],
                                onConfirmReceipt: () =>
                                    _confirmReceipt(filtered[i]),
                                onOpenBudget: () =>
                                    _openBudget(filtered[i]),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback? onOpenDrawer;

  const _Header({required this.onSearch, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
              if (onOpenDrawer != null) ...[
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
                      child: const Icon(Icons.menu_rounded,
                          size: 19, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                'Agendamentos',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: onSearch,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por cliente, veículo ou placa...',
              hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar with count badges ──────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;
  final int pending;
  final int confirmed;
  final int canceled;

  const _FilterBar({
    required this.active,
    required this.onChange,
    required this.pending,
    required this.confirmed,
    required this.canceled,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('todos', 'Todos', null),
      ('pendente', 'Pendentes', pending),
      ('confirmado', 'Confirmados', confirmed),
      ('cancelado', 'Cancelados', canceled),
    ];

    return Container(
      color: bgPage,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final key = f.$1;
            final label = f.$2;
            final count = f.$3;
            final isActive = key == active;
            final hasCount = count != null && count > 0;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChange(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? navyDark : cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? navyDark : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : textSecondary,
                        ),
                      ),
                      if (hasCount) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.22)
                                : (key == 'pendente' ? yellowBg : orangeLight),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : (key == 'pendente' ? yellow : orange),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  size: 32, color: textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum agendamento',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Não encontramos agendamentos\npara o filtro selecionado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 11),
                decoration: BoxDecoration(
                  color: navyDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Atualizar lista',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Appointment card ──────────────────────────────────────────────────────────

class _ScheduledCard extends StatelessWidget {
  final ScheduledServiceItem item;
  final VoidCallback onConfirmReceipt;
  final VoidCallback onOpenBudget;

  const _ScheduledCard({
    required this.item,
    required this.onConfirmReceipt,
    required this.onOpenBudget,
  });

  @override
  Widget build(BuildContext context) {
    final dt = item.agendadoPara.toLocal();
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final hour = '${dt.hour.toString().padLeft(2, '0')}h';

    final canAct = item.status.toLowerCase() == 'confirmado' || 
                   item.status.toLowerCase() == 'pendente';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.clienteNome,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: item.status.toLowerCase()),
            ],
          ),
          const SizedBox(height: 3),
          // Vehicle — reduced opacity for hierarchy
          Text(
            '${item.veiculoDescricao} · ${item.placa}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: textSecondary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          // Meta chips in a row that wraps gracefully
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(icon: Icons.calendar_today_rounded, label: date),
              _MetaChip(icon: Icons.schedule_rounded, label: hour),
              _MetaChip(
                icon: Icons.timelapse_rounded,
                label: '${item.duracaoMinutos} min',
              ),
            ],
          ),
          // Action buttons — only when actionable
          if (canAct) ...[
            const SizedBox(height: 12),
            const Divider(color: borderColor, height: 1),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActionButton(
                  icon: Icons.edit_note_rounded,
                  label: 'Atualizar orçamento',
                  onTap: onOpenBudget,
                  outlined: true,
                ),
                const SizedBox(height: 8),
                _ActionButton(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Concluir e abrir OS',
                  onTap: onConfirmReceipt,
                  outlined: false,
                ),
              ],
            ),
          ],
          // Client notes
          if ((item.notasCliente ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bgPage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 13, color: textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.notasCliente!,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : navyDark,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: outlined ? borderColor : navyDark,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: outlined ? textSecondary : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: outlined ? textSecondary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgPage,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
