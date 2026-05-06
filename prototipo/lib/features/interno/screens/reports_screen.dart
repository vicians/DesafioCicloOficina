import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../data/models/report_data.dart';
import '../data/report_repository.dart';

class ReportsScreen extends StatefulWidget {
  final ReportRepository repository;

  const ReportsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<ReportData> _future;
  String _period = 'year';
  late DateTime _selectedDate;
  late int _selectedMonth;
  late int _selectedYear;
  late List<int> _availableYears;

  static const List<(int, String)> _monthOptions = [
    (1, 'Janeiro'),
    (2, 'Fevereiro'),
    (3, 'Marco'),
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
    _availableYears = List.generate(8, (index) => now.year - 5 + index);
    _future = _buildFuture();
  }

  String _toTwoDigits(int value) => value.toString().padLeft(2, '0');

  Future<ReportData> _buildFuture() {
    if (_period == 'day') {
      final date =
          '${_selectedDate.year}-${_toTwoDigits(_selectedDate.month)}-${_toTwoDigits(_selectedDate.day)}';
      return widget.repository.fetchInternalReport(period: 'day', date: date);
    }

    if (_period == 'year') {
      return widget.repository.fetchInternalReport(
        period: 'year',
        year: '$_selectedYear',
      );
    }

    final month = '$_selectedYear-${_toTwoDigits(_selectedMonth)}';
    return widget.repository.fetchInternalReport(period: 'month', month: month);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _buildFuture();
    });
    await _future;
  }

  void _onPeriodChanged(String period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _future = _buildFuture();
    });
  }

  void _onMonthChanged(int month) {
    if (_selectedMonth == month) return;
    setState(() {
      _selectedMonth = month;
      _future = _buildFuture();
    });
  }

  void _onYearChanged(int year) {
    if (_selectedYear == year) return;
    setState(() {
      _selectedYear = year;
      _future = _buildFuture();
    });
  }

  Future<void> _onSelectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Selecionar dia do relatório',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedMonth = picked.month;
      _selectedYear = picked.year;
      if (!_availableYears.contains(picked.year)) {
        _availableYears = [..._availableYears, picked.year]..sort();
      }
      _future = _buildFuture();
    });
  }

  String _formatGrowth(num value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReportData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Erro ao carregar relatório',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return Center(
            child: Text(
              'Nenhum dado de relatório disponível',
              style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ReportsHeader(),
                _PeriodFilterMenu(
                  active: _period,
                  onChange: _onPeriodChanged,
                  selectedDate: _selectedDate,
                  selectedMonth: _selectedMonth,
                  selectedYear: _selectedYear,
                  years: _availableYears,
                  monthOptions: _monthOptions,
                  onSelectDate: _onSelectDate,
                  onMonthChanged: _onMonthChanged,
                  onYearChanged: _onYearChanged,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RevenueCard(data: data, growthLabel: _formatGrowth(data.revenueGrowth)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              label: 'Serviços realizados',
                              value: '${data.services}',
                              growth: _formatGrowth(data.servicesGrowth),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiCard(
                              label: 'Ticket médio',
                              value: 'R\$ ${data.avgTicket.toStringAsFixed(2).replaceAll('.', ',')}',
                              growth: _formatGrowth(data.avgTicketGrowth),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(data: data),
                      const SizedBox(height: 10),
                      _TopServicesCard(data: data),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Text(
        'Relatórios',
        style: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PeriodFilterMenu extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;
  final DateTime selectedDate;
  final int selectedMonth;
  final int selectedYear;
  final List<int> years;
  final List<(int, String)> monthOptions;
  final Future<void> Function() onSelectDate;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const _PeriodFilterMenu({
    required this.active,
    required this.onChange,
    required this.selectedDate,
    required this.selectedMonth,
    required this.selectedYear,
    required this.years,
    required this.monthOptions,
    required this.onSelectDate,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _dateLabel(DateTime date) {
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  Widget _selectorContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('year', 'Ano'),
      ('month', 'Mês'),
      ('day', 'Dia'),
    ];

    return Container(
      color: navyDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Filtros (abas)
          Wrap(
            spacing: 8,
            children: [
              for (final (key, label) in filters)
                GestureDetector(
                  onTap: () => onChange(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: key == active ? orange : Colors.white.withValues(alpha: 0.12),
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
                ),
            ],
          ),
          const Spacer(),
          // Seletores específicos por período
          if (active == 'year')
            SizedBox(
              width: 100,
              child: _selectorContainer(
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: navyMid,
                  iconEnabledColor: Colors.white,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  items: years
                      .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onYearChanged(value);
                  },
                ),
              ),
            ),
          if (active == 'month') ...[
            SizedBox(
              width: 120,
              child: _selectorContainer(
                DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: navyMid,
                  iconEnabledColor: Colors.white,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  items: monthOptions
                      .map(
                        (m) => DropdownMenuItem<int>(
                          value: m.$1,
                          child: Text(m.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onMonthChanged(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: _selectorContainer(
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: navyMid,
                  iconEnabledColor: Colors.white,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  items: years
                      .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onYearChanged(value);
                  },
                ),
              ),
            ),
          ],
          if (active == 'day')
            OutlinedButton.icon(
              onPressed: onSelectDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('Data: ${_dateLabel(selectedDate)}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
        ],
      ),
    );
  }
}



class _RevenueCard extends StatelessWidget {
  final ReportData data;
  final String growthLabel;

  const _RevenueCard({
    required this.data,
    required this.growthLabel,
  });

  @override
  Widget build(BuildContext context) {
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
                'Faturamento total',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'R\$ ${data.revenue.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.dmSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              growthLabel,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String growth;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.growth,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 11, color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            growth,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: green,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ReportData data;
  const _StatusCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = [green, blue, textMuted];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status dos serviços',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(data.byStatus.length, (i) {
            final s = data.byStatus[i];
            final pct = s.total > 0 ? (s.value / s.total * 100) : 0.0;
            final c = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: textPrimary,
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
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppProgressBar(percent: pct, color: c),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopServicesCard extends StatelessWidget {
  final ReportData data;
  const _TopServicesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.topServices.isEmpty) {
      return AppCard(
        child: Text(
          'Nenhum serviço concluído neste período.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: textSecondary,
          ),
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: i == 0 ? yellowBg : dividerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? yellow : textMuted,
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
