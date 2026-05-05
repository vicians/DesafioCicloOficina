import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/client_flow_repository.dart';
import '../data/models/client_models.dart';
import 'client_screen_header.dart';

class HistoryScreen extends StatelessWidget {
  final ClientFlowRepository repository;
  const HistoryScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        repository.fetchCurrentService(),
        repository.fetchServiceHistory(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: orange));
        }

        final results = snapshot.data as List?;
        final svc = results?[0] as ServiceModel?;
        final history = results?[1] as List<HistoryItem>? ?? [];

        return Column(
          children: [
            ClientScreenHeader(
              title: 'Histórico',
              subtitle: '${history.length + (svc != null ? 1 : 0)} serviços registrados',
              trailing: svc != null ? StatusBadge(status: svc.status) : null,
              contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (svc != null) ...[
                    const _SectionLabel(label: 'EM ANDAMENTO'),
                    const SizedBox(height: 8),
                    _ActiveHistoryCard(svc: svc),
                    const SizedBox(height: 20),
                  ],
                  const _SectionLabel(label: 'CONCLUÍDOS'),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Nenhum histórico disponível.',
                          style: GoogleFonts.dmSans(color: textMuted),
                        ),
                      ),
                    )
                  else
                    ...history.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CompletedCard(item: h),
                      ),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ActiveHistoryCard extends StatelessWidget {
  final ServiceModel svc;
  const _ActiveHistoryCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                      svc.id,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: textMuted),
                    ),
                    Text(
                      svc.title,
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
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: blueBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: blue, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Em andamento',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(percent: svc.progress.toDouble()),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${svc.progress}% concluído',
                style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
              ),
              Text(
                'Previsão: ${svc.estimatedEnd}',
                style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final HistoryItem item;
  const _CompletedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: greenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_rounded, color: green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  item.date,
                  style:
                      GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Text(
            item.total,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
