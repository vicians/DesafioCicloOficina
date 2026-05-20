import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../data/models/report_data.dart';
import '../data/report_repository.dart';

class ReportsScreen extends StatefulWidget {
  final ReportRepository repository;
  final VoidCallback? onOpenDrawer;

  const ReportsScreen({
    super.key,
    required this.repository,
    this.onOpenDrawer,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<ReportData> _future;
  String _period = 'month';
  late DateTime _selectedDate;
  late int _selectedMonth;
  late int _selectedYear;
  late List<int> _availableYears;

  static const List<(int, String)> _monthOptions = [
    (1, 'Janeiro'),
    (2, 'Fevereiro'),
    (3, 'Março'),
    (4, 'Abril'),
    (5, 'Maio'),
    (6, 'Junho'),
    (7, 'Julho'),
    (8, 'Agosto'),
    (9, 'Setembro'),
    (10, 'Outubro'),
    (11, 'Novembro'),
    (12, 'Dezembro'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _availableYears = List.generate(8, (i) => now.year - 5 + i);
    _future = _buildFuture();
  }

  String _twoDigits(int v) => v.toString().padLeft(2, '0');

  Future<ReportData> _buildFuture() {
    if (_period == 'day') {
      final date =
          '${_selectedDate.year}-${_twoDigits(_selectedDate.month)}-${_twoDigits(_selectedDate.day)}';
      return widget.repository.fetchInternalReport(period: 'day', date: date);
    }
    if (_period == 'year') {
      return widget.repository
          .fetchInternalReport(period: 'year', year: '$_selectedYear');
    }
    final month = '$_selectedYear-${_twoDigits(_selectedMonth)}';
    return widget.repository.fetchInternalReport(period: 'month', month: month);
  }

  Future<void> _reload() async {
    setState(() => _future = _buildFuture());
    await _future;
  }

  void _setPeriod(String p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _future = _buildFuture();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Selecionar dia',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedMonth = picked.month;
      _selectedYear = picked.year;
      if (!_availableYears.contains(picked.year)) {
        _availableYears = [..._availableYears, picked.year]..sort();
      }
      _future = _buildFuture();
    });
  }

  String _growthLabel(num v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}%';
  }

  String _monthName(int m) => _monthOptions[m - 1].$2;

  String get _periodLabel {
    switch (_period) {
      case 'year':
        return '$_selectedYear';
      case 'day':
        return '${_twoDigits(_selectedDate.day)}/${_twoDigits(_selectedDate.month)}/${_selectedDate.year}';
      default:
        return '${_monthName(_selectedMonth)} $_selectedYear';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReportsHeader(onOpenDrawer: widget.onOpenDrawer),
        _PeriodBar(
          active: _period,
          onSelect: _setPeriod,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
          years: _availableYears,
          monthOptions: _monthOptions,
          onMonthChanged: (m) => setState(() {
            _selectedMonth = m;
            _future = _buildFuture();
          }),
          onYearChanged: (y) => setState(() {
            _selectedYear = y;
            _future = _buildFuture();
          }),
          onPickDate: _pickDate,
          selectedDate: _selectedDate,
        ),
        Expanded(
          child: FutureBuilder<ReportData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Erro ao carregar relatório',
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _reload,
                          child: const Text('Tentar novamente')),
                    ],
                  ),
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return Center(
                  child: Text('Sem dados para o período',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: textSecondary)),
                );
              }
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _RevenueCard(
                        data: data,
                        growthLabel: _growthLabel(data.revenueGrowth),
                        growthPositive: data.revenueGrowth >= 0,
                        periodLabel: _periodLabel),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            label: 'Serviços realizados',
                            value: '${data.services}',
                            growth: _growthLabel(data.servicesGrowth),
                            positive: data.servicesGrowth >= 0,
                            context: 'vs. período anterior',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _KpiCard(
                            label: 'Ticket médio',
                            value:
                                'R\$ ${data.avgTicket.toStringAsFixed(2).replaceAll('.', ',')}',
                            growth: _growthLabel(data.avgTicketGrowth),
                            positive: data.avgTicketGrowth >= 0,
                            context: 'vs. período anterior',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StatusCard(data: data),
                    const SizedBox(height: 10),
                    _TopServicesCard(data: data),
                    const SizedBox(height: 10),
                    _TopMechanicsCard(data: data),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ReportsHeader extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const _ReportsHeader({this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Row(
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
            'Relatórios',
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
}

// ── Period Bar ────────────────────────────────────────────────────────────────

class _PeriodBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onSelect;
  final int selectedMonth;
  final int selectedYear;
  final List<int> years;
  final List<(int, String)> monthOptions;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final Future<void> Function() onPickDate;
  final DateTime selectedDate;

  const _PeriodBar({
    required this.active,
    required this.onSelect,
    required this.selectedMonth,
    required this.selectedYear,
    required this.years,
    required this.monthOptions,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onPickDate,
    required this.selectedDate,
  });

  String _twoDigits(int v) => v.toString().padLeft(2, '0');

  Widget _dropdownBox(Widget child) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('year', 'Ano'),
      ('month', 'Mês'),
      ('day', 'Dia'),
    ];

    return Container(
      color: navyDark,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab row
          Row(
            children: [
              for (final (key, label) in tabs) ...[
                GestureDetector(
                  onTap: () => onSelect(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: key == active
                          ? orange
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Selector row — always on its own line, never overflows
          if (active == 'year')
            SizedBox(
              width: 110,
              child: _dropdownBox(
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: navyMid,
                  iconEnabledColor: Colors.white,
                  style:
                      GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                  items: years
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onYearChanged(v);
                  },
                ),
              ),
            ),
          if (active == 'month')
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: _dropdownBox(
                    DropdownButton<int>(
                      value: selectedMonth,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: navyMid,
                      iconEnabledColor: Colors.white,
                      style: GoogleFonts.dmSans(
                          color: Colors.white, fontSize: 13),
                      items: monthOptions
                          .map((m) => DropdownMenuItem(
                              value: m.$1, child: Text(m.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onMonthChanged(v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: _dropdownBox(
                    DropdownButton<int>(
                      value: selectedYear,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: navyMid,
                      iconEnabledColor: Colors.white,
                      style: GoogleFonts.dmSans(
                          color: Colors.white, fontSize: 13),
                      items: years
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onYearChanged(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          if (active == 'day')
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: Text(
                  '${_twoDigits(selectedDate.day)}/${_twoDigits(selectedDate.month)}/${selectedDate.year}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                textStyle:
                    GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Revenue Card ──────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  final ReportData data;
  final String growthLabel;
  final bool growthPositive;
  final String periodLabel;

  const _RevenueCard({
    required this.data,
    required this.growthLabel,
    required this.growthPositive,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = growthPositive ? green : red;
    final chipIcon =
        growthPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navyDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Faturamento total',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  periodLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'R\$ ${data.revenue.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipColor),
                    const SizedBox(width: 4),
                    Text(
                      growthLabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'vs. período anterior',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String growth;
  final bool positive;
  final String context;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.growth,
    required this.positive,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = positive ? green : red;
    final chipIcon =
        positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(chipIcon, size: 12, color: chipColor),
              const SizedBox(width: 3),
              Text(
                growth,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: chipColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            this.context,
            style: GoogleFonts.dmSans(fontSize: 10, color: textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Status Card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final ReportData data;
  const _StatusCard({required this.data});

  static const _statusColors = [green, blue, purple, orange, textMuted];

  @override
  Widget build(BuildContext context) {
    if (data.byStatus.isEmpty) return const SizedBox.shrink();

    final total = data.byStatus.fold<int>(0, (sum, s) => sum + s.value);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status dos serviços',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Text(
                '$total total',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Segmented progress bar showing proportions
          if (total > 0) ...[
            _SegmentedBar(items: data.byStatus, colors: _statusColors),
            const SizedBox(height: 14),
          ],
          // Legend rows
          ...List.generate(data.byStatus.length, (i) {
            final s = data.byStatus[i];
            final pct = total > 0 ? (s.value / total * 100) : 0.0;
            final c = _statusColors[i % _statusColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: textPrimary),
                    ),
                  ),
                  Text(
                    '${s.value}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: textMuted),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  final List<StatusCount> items;
  final List<Color> colors;

  const _SegmentedBar({required this.items, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: Row(
          children: List.generate(items.length, (i) {
            final fraction = items[i].value / total;
            if (fraction == 0) return const SizedBox.shrink();
            return Flexible(
              flex: items[i].value,
              child: Container(
                color: colors[i % colors.length],
                margin: i < items.length - 1
                    ? const EdgeInsets.only(right: 2)
                    : EdgeInsets.zero,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Top Services Card ─────────────────────────────────────────────────────────

class _TopServicesCard extends StatelessWidget {
  final ReportData data;
  const _TopServicesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.topServices.isEmpty) {
      return AppCard(
        child: Text(
          'Nenhum serviço concluído neste período.',
          style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serviços mais realizados',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(data.topServices.length, (i) {
            final svc = data.topServices[i];
            final isFirst = i == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isFirst ? yellowBg : dividerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isFirst ? yellow : textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          svc.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'R\$ ${svc.revenue.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${svc.count}x',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Top Mechanics Card ────────────────────────────────────────────────────────

class _TopMechanicsCard extends StatelessWidget {
  final ReportData data;
  const _TopMechanicsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.topMechanics.isEmpty) {
      return AppCard(
        child: Text(
          'Nenhum mecânico realizou serviços neste período.',
          style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Desempenho dos Mecânicos',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(data.topMechanics.length, (i) {
            final mechanic = data.topMechanics[i];
            final isFirst = i == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isFirst ? yellowBg : dividerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isFirst ? yellow : textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mechanic.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'R\$ ${mechanic.revenue.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${mechanic.count} OS',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
