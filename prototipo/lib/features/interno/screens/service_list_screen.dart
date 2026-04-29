import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import '../data/internal_flow_repository.dart';
import 'internal_service_detail_screen.dart';

// ── ServiceListScreen ─────────────────────────────────────────────────────────

class ServiceListScreen extends StatefulWidget {
  final String? initialFilter;
  final InternalFlowRepository repository;

  const ServiceListScreen({
    super.key,
    required this.repository,
    this.initialFilter,
  });

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _statusFilter = 'todos';
  String _periodFilter = 'todos';
  String _search = '';
  late Future<List<InternalService>> _servicesFuture;

  final _statusFilters = const [
    ('todos', 'Todos'),
    ('aguardando', 'Aguardando'),
    ('andamento', 'Andamento'),
    ('revisao', 'Em revisão'),
  ];

  final _periodFilters = const [
    ('todos', 'Todos'),
    ('hoje', 'Hoje'),
    ('7dias', '7 dias'),
    ('30dias', '30 dias'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _statusFilter = widget.initialFilter ?? 'todos';
    _tabCtrl.addListener(() => setState(() {}));
    _servicesFuture = widget.repository.fetchServicos();
    widget.repository.addListener(_reloadServices);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_reloadServices);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _reloadServices() {
    setState(() {
      _servicesFuture = widget.repository.fetchServicos();
    });
  }

  bool _matchesSearch(InternalService s) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return s.client.toLowerCase().contains(q) ||
        s.car.toLowerCase().contains(q) ||
        s.plate.toLowerCase().contains(q) ||
        s.id.toLowerCase().contains(q);
  }

  List<InternalService> _ativosFrom(List<InternalService> services) {
    return services
        .where((s) => s.status != 'concluido' && s.status != 'cancelado')
        .where(_matchesSearch)
        .where((s) => _statusFilter == 'todos' || s.status == _statusFilter)
        .toList();
  }

  List<InternalService> _finalizadosFrom(List<InternalService> services) {
    return services
        .where((s) => s.status == 'concluido' || s.status == 'cancelado')
        .where(_matchesSearch)
        .where((s) {
          if (_periodFilter == 'todos') return true;
          if (s.finishedAt == null) return false;
          final parts = s.finishedAt!.split('/');
          if (parts.length != 3) return false;
          final dt = DateTime.tryParse(
              '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
          if (dt == null) return false;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final finDay = DateTime(dt.year, dt.month, dt.day);
          final diff = today.difference(finDay).inDays;
          if (_periodFilter == 'hoje') return diff == 0;
          if (_periodFilter == '7dias') return diff <= 7;
          if (_periodFilter == '30dias') return diff <= 30;
          return true;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAtivos = _tabCtrl.index == 0;
    return FutureBuilder<List<InternalService>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar serviços',
              style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
            ),
          );
        }

        final services = snapshot.data ?? const <InternalService>[];
        return Column(
          children: [
            _ScreenHeader(
              search: _search,
              onSearch: (v) => setState(() => _search = v),
              tabCtrl: _tabCtrl,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isAtivos
                  ? _FilterBar(
                      key: const ValueKey('status'),
                      filters: _statusFilters,
                      active: _statusFilter,
                      onSelect: (f) => setState(() => _statusFilter = f),
                    )
                  : _FilterBar(
                      key: const ValueKey('period'),
                      filters: _periodFilters,
                      active: _periodFilter,
                      onSelect: (f) => setState(() => _periodFilter = f),
                    ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ServiceListView(
                    items: _ativosFrom(services),
                    showProgress: true,
                    emptyMessage: 'Nenhum serviço ativo no momento',
                  ),
                  _ServiceListView(
                    items: _finalizadosFrom(services),
                    showProgress: false,
                    emptyMessage: 'Nenhum serviço finalizado encontrado',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final TabController tabCtrl;

  const _ScreenHeader({
    required this.search,
    required this.onSearch,
    required this.tabCtrl,
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serviços da Oficina',
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
                    hintText: 'Buscar por cliente, veículo, placa ou OS...',
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
          ),
          TabBar(
            controller: tabCtrl,
            indicatorColor: orange,
            indicatorWeight: 2.5,
            labelColor: orange,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
            labelStyle:
                GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Ativos'),
              Tab(text: 'Finalizados'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<(String, String)> filters;
  final String active;
  final ValueChanged<String> onSelect;

  const _FilterBar({
    super.key,
    required this.filters,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgPage,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = f.$1 == active;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onSelect(f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? navyDark : cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? navyDark : borderColor,
                    ),
                  ),
                  child: Text(
                    f.$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : textSecondary,
                    ),
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

// ── List View ─────────────────────────────────────────────────────────────────

class _ServiceListView extends StatelessWidget {
  final List<InternalService> items;
  final bool showProgress;
  final String emptyMessage;

  const _ServiceListView({
    required this.items,
    required this.showProgress,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build_outlined, size: 48, color: textMuted),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _ServiceCard(svc: items[i], showProgress: showProgress),
    );
  }
}

// ── Service Card ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final InternalService svc;
  final bool showProgress;
  const _ServiceCard({required this.svc, required this.showProgress});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalServiceDetailScreen(service: svc),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cliente + badge de status
          Row(
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
                      '${svc.id} · ${svc.car} · ${svc.plate}',
                      style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: svc.status),
            ],
          ),
          const SizedBox(height: 8),

          // Descrição do serviço
          Text(
            svc.service,
            style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 10),

          // Barra de progresso (apenas Ativos)
          if (showProgress) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progresso',
                  style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                ),
                Text(
                  '${svc.progress}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AppProgressBar(percent: svc.progress.toDouble()),
            const SizedBox(height: 10),
          ],

          // Rodapé: mecânico (Ativos) ou data de finalização (Finalizados) + valor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showProgress)
                Row(
                  children: [
                    AppAvatar(
                      initials: svc.mechanic.isNotEmpty && svc.mechanic != '—'
                          ? svc.mechanic[0].toUpperCase()
                          : '?',
                      size: 24,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      svc.mechanic,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: textSecondary),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: green),
                    const SizedBox(width: 4),
                    Text(
                      svc.finishedAt != null
                          ? 'Finalizado em ${svc.finishedAt}'
                          : 'Finalizado',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              Text(
                'R\$ ${svc.value.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
