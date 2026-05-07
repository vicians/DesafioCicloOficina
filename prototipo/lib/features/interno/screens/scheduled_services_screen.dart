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
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenBudgets;

  const ScheduledServicesScreen({
    super.key,
    required this.repository,
    this.budgetRepository,
    this.onOpenServices,
    this.onOpenBudgets,
  });

  @override
  State<ScheduledServicesScreen> createState() => _ScheduledServicesScreenState();
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
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.fetchScheduledServices();
    });
    await _future;
  }

  List<ScheduledServiceItem> _applyFilters(List<ScheduledServiceItem> source) {
    return source.where((item) {
      final status = item.status.toLowerCase();
      final normalizedSearch = _search.trim().toLowerCase();

      final matchesStatus =
          _statusFilter == 'todos' || status == _statusFilter;

      if (normalizedSearch.isEmpty) {
        return matchesStatus;
      }

      final matchesSearch =
          item.clienteNome.toLowerCase().contains(normalizedSearch) ||
          item.veiculoDescricao.toLowerCase().contains(normalizedSearch) ||
          item.placa.toLowerCase().contains(normalizedSearch);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _confirmReceipt(ScheduledServiceItem item) async {
    if (_confirmingReceipt) return;

    setState(() => _confirmingReceipt = true);
    try {
      final serviceId = await widget.repository.confirmScheduleToService(
        schedule: item,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agendamento confirmado. OS aberta: $serviceId'),
          action: widget.onOpenServices == null
              ? null
              : SnackBarAction(
                  label: 'Abrir',
                  onPressed: widget.onOpenServices!,
                ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao confirmar recebimento: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _confirmingReceipt = false);
      }
    }
  }

  Future<void> _openBudget(ScheduledServiceItem item) async {
    if (_openingBudget) return;

    setState(() => _openingBudget = true);
    try {
      final budgetId = await widget.repository.openScheduleBudget(schedule: item);
      await _reload();
      if (!mounted) return;

      if (widget.budgetRepository != null) {
        final budgets = await widget.budgetRepository!.fetchOrcamentos();
        if (!mounted) return;
        InternalBudgetItem? target;
        for (final budget in budgets) {
          if (budget.id == budgetId) {
            target = budget;
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
            final refreshedBudgets = await widget.budgetRepository!.fetchOrcamentos();
            if (!mounted) return;

            InternalBudgetItem? refreshed;
            for (final budget in refreshedBudgets) {
              if (budget.id == budgetId) {
                refreshed = budget;
                break;
              }
            }

            if (refreshed != null && refreshed.status.toLowerCase() == 'aprovado') {
              await widget.budgetRepository!.sendAddons(budgetId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alterações enviadas para aprovação do cliente.'),
                ),
              );
            }
          }

          await _reload();
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Orçamento pronto: $budgetId'),
          action: widget.onOpenBudgets == null
              ? null
              : SnackBarAction(
                  label: 'Abrir',
                  onPressed: widget.onOpenBudgets!,
                ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao abrir orçamento: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingBudget = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          onSearch: (value) => setState(() => _search = value),
        ),
        _StatusFilterBar(
          active: _statusFilter,
          onChange: (value) => setState(() => _statusFilter = value),
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
                  child: Text(
                    'Erro ao carregar agendamentos',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
                  ),
                );
              }

              final filtered = _applyFilters(snapshot.data ?? const []);
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhum agendamento encontrado',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _ScheduledCard(
                      item: item,
                      onConfirmReceipt: () => _confirmReceipt(item),
                      onOpenBudget: () => _openBudget(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final ValueChanged<String> onSearch;

  const _Header({required this.onSearch});

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
          Text(
            'Agendamentos',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: onSearch,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por cliente, veiculo ou placa...',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.6),
              ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;

  const _StatusFilterBar({
    required this.active,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('todos', 'Todos'),
      ('pendente', 'Pendentes'),
      ('confirmado', 'Confirmados'),
      ('cancelado', 'Cancelados'),
    ];

    return Container(
      color: navyDark,
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (key, label) = filters[i];
          final isActive = key == active;

          return GestureDetector(
            onTap: () => onChange(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? orange : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    final agendamento = item.agendadoPara.toLocal();
    final data =
        '${agendamento.day.toString().padLeft(2, '0')}/${agendamento.month.toString().padLeft(2, '0')}/${agendamento.year}';
    final hora = '${agendamento.hour.toString().padLeft(2, '0')}h';
    final canConfirmReceipt =
        (item.status.toLowerCase() == 'pendente' ||
          item.status.toLowerCase() == 'confirmado') &&
        !item.possuiExecucao;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.clienteNome,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: item.status.toLowerCase()),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${item.veiculoDescricao} - ${item.placa}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.calendar_today_rounded, label: data),
              _MetaChip(icon: Icons.schedule_rounded, label: hora),
              _MetaChip(
                icon: Icons.timelapse_rounded,
                label: '${item.duracaoMinutos} min',
              ),
            ],
          ),
          if (canConfirmReceipt) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenBudget,
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Atualizar orçamento'),
                ),
                OutlinedButton.icon(
                  onPressed: onConfirmReceipt,
                  icon: const Icon(Icons.build_circle_outlined, size: 16),
                  label: const Text('Concluir e abrir OS'),
                ),
              ],
            ),
          ],
          if ((item.notasCliente ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.notasCliente!,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgPage,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textSecondary),
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
