import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/models/client_models.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    return Scaffold(
      backgroundColor: bgPage,
      body: Column(
        children: [
          _DetailHeader(svc: svc, tabCtrl: _tabCtrl),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _TimelineTab(svc: svc),
                _BudgetTab(svc: svc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final ServiceModel svc;
  final TabController tabCtrl;

  const _DetailHeader({required this.svc, required this.tabCtrl});

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
                          svc.id,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          svc.car,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: svc.status),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: tabCtrl,
              indicatorColor: orange,
              indicatorWeight: 2.5,
              labelColor: orange,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
              labelStyle: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Acompanhamento'),
                Tab(text: 'Orçamento'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final ServiceModel svc;
  const _TimelineTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...List.generate(svc.timeline.length, (i) {
          final step = svc.timeline[i];
          final isLast = i == svc.timeline.length - 1;
          return _TimelineStep(step: step, isLast: isLast);
        }),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final TimelineStep step;
  final bool isLast;

  const _TimelineStep({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    Color circleColor;
    Color lineColor;
    Widget icon;

    if (step.done) {
      circleColor = green;
      lineColor = green;
      icon = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
    } else if (step.active) {
      circleColor = orange;
      lineColor = borderColor;
      icon = Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
    } else {
      circleColor = borderColor;
      lineColor = borderColor;
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
                              blurRadius: 0,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: icon),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: lineColor,
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
  }
}

class _BudgetTab extends StatelessWidget {
  final ServiceModel svc;
  const _BudgetTab({required this.svc});

  @override
  Widget build(BuildContext context) {
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
              ...List.generate(svc.budgetItems.length, (i) {
                final item = svc.budgetItems[i];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: textPrimary,
                              ),
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
                      const Divider(
                          height: 1, thickness: 1, color: dividerColor),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                    'Total do orçamento',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'R\$ ${svc.budgetTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Aprovado',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: greenBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: green, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Orçamento aprovado em 22 abr 2026',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
