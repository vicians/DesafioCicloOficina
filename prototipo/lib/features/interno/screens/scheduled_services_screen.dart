import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/models/scheduled_service_item.dart';
import '../data/scheduling_repository.dart';

class ScheduledServicesScreen extends StatefulWidget {
  final SchedulingRepository repository;
  final bool isManager;
  final VoidCallback? onOpenBudgets;

  const ScheduledServicesScreen({
    super.key,
    required this.repository,
    this.isManager = false,
    this.onOpenBudgets,
  });

  @override
  State<ScheduledServicesScreen> createState() => _ScheduledServicesScreenState();
}

class _ScheduledServicesScreenState extends State<ScheduledServicesScreen> {
  late Future<List<ScheduledServiceItem>> _future;
  String _search = '';
  String _statusFilter = 'todos';
  bool _sendingToBudget = false;

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

  Future<void> _sendToBudget(ScheduledServiceItem item) async {
    if (_sendingToBudget) return;

    setState(() => _sendingToBudget = true);
    try {
      final budgetId = await widget.repository.sendScheduleToBudgets(
        schedule: item,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviado para orçamentos: $budgetId'),
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
          content: Text('Falha ao enviar para orçamentos: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingToBudget = false);
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
                      isManager: widget.isManager,
                      onSendToBudget: () => _sendToBudget(item),
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
  final bool isManager;
  final VoidCallback onSendToBudget;

  const _ScheduledCard({
    required this.item,
    required this.isManager,
    required this.onSendToBudget,
  });

  @override
  Widget build(BuildContext context) {
    final agendamento = item.agendadoPara.toLocal();
    final data =
        '${agendamento.day.toString().padLeft(2, '0')}/${agendamento.month.toString().padLeft(2, '0')}/${agendamento.year}';
    final hora = '${agendamento.hour.toString().padLeft(2, '0')}h';
    final canSendToBudget =
        isManager && item.status.toLowerCase() == 'concluido' && !item.possuiOrcamento;

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
          if (canSendToBudget) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onSendToBudget,
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('Enviar para orçamentos'),
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
