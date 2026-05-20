import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../data/client_flow_repository.dart';
import '../data/models/client_models.dart';
import 'client_screen_header.dart';
import 'service_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final ClientFlowRepository repository;
  final VoidCallback? onOpenDrawer;
  const HistoryScreen({super.key, required this.repository, this.onOpenDrawer});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryItem>> _dataFuture;

  // Status que indicam execução ainda em curso (não finalizados).
  static const _activeStatuses = {
    'aguardando', 'em_execucao', 'andamento', 'revisao_tecnica', 'revisao',
    'aguardando_retirada', 'pendente',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.repository.addListener(_loadData);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_loadData);
    super.dispose();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      _dataFuture = widget.repository.fetchServiceHistory();
    });
  }

  Future<void> _openDetail(HistoryItem item) async {
    final svc = await widget.repository.fetchServiceById(item.id);
    if (!mounted) return;
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os detalhes.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: svc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: orange));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar os dados. Tente novamente.',
              style: GoogleFonts.dmSans(color: Colors.red),
            ),
          );
        }

        final all = snapshot.data ?? [];
        final active = all.where((h) => _activeStatuses.contains(h.status)).toList();
        final finished = all.where((h) => !_activeStatuses.contains(h.status)).toList();
        final total = all.length;

        return Column(
          children: [
            ClientScreenHeader(
              title: 'Histórico',
              subtitle: '$total serviços registrados',
              leading: widget.onOpenDrawer != null
                  ? ClientMenuButton(onTap: widget.onOpenDrawer!)
                  : null,
              contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _loadData(),
                color: orange,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (active.isNotEmpty) ...[
                      const _SectionLabel(label: 'EM ANDAMENTO'),
                      const SizedBox(height: 8),
                      ...active.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ActiveHistoryCard(item: h, onTap: () => _openDetail(h)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const _SectionLabel(label: 'CONCLUÍDOS E CANCELADOS'),
                    const SizedBox(height: 8),
                    if (finished.isEmpty)
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
                      ...finished.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CompletedCard(item: h, onTap: () => _openDetail(h)),
                        ),
                      ),
                  ],
                ),
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
  final HistoryItem item;
  final VoidCallback? onTap;
  const _ActiveHistoryCard({required this.item, this.onTap});

  String _statusLabel(String s) {
    switch (s) {
      case 'aguardando': return 'Aguardando';
      case 'em_execucao':
      case 'andamento': return 'Em execução';
      case 'revisao_tecnica':
      case 'revisao': return 'Em revisão';
      case 'aguardando_retirada': return 'Pronto p/ retirada';
      default: return 'Em andamento';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: blueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.build_rounded, color: blue, size: 20),
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
                    style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: blueBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: blue, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel(item.status),
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
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback? onTap;
  const _CompletedCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCanceled = item.status == 'cancelado';
    final iconBg = isCanceled ? redBg : greenBg;
    final iconColor = isCanceled ? red : green;
    final iconData = isCanceled ? Icons.cancel_outlined : Icons.check_circle_outline_rounded;
    final badgeBg = isCanceled ? redBg : greenBg;
    final badgeColor = isCanceled ? red : green;
    final badgeLabel = isCanceled ? 'Cancelado' : 'Concluído';

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
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
                    style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
                if (item.total != '—') ...[
                  const SizedBox(height: 4),
                  Text(
                    item.total,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
