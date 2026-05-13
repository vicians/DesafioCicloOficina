import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/pulsing_dot.dart';
import '../data/client_flow_repository.dart';
import '../data/models/client_models.dart';
import 'register_vehicle_screen.dart';
import 'client_screen_header.dart';
import 'service_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final ClientFlowRepository repository;

  const HomeScreen({
    super.key,
    required this.repository,
    this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<ServiceModel?> _serviceFuture;
  late Future<List<HistoryItem>> _historyFuture;
  late Future<String> _nameFuture;
  late Future<List<Map<String, dynamic>>> _vehiclesFuture;

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
      _serviceFuture = widget.repository.fetchCurrentService();
      _historyFuture = widget.repository.fetchServiceHistory();
      _nameFuture = widget.repository.fetchProfileName();
      _vehiclesFuture = widget.repository.fetchVehicles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_serviceFuture, _historyFuture, _nameFuture, _vehiclesFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: orange));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Erro ao carregar o painel. Tente novamente.',
                style: GoogleFonts.dmSans(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final results = snapshot.data as List?;
        final svc = results?[0] as ServiceModel?;
        final history = results?[1] as List<HistoryItem>? ?? [];
        final clientName = results?[2] as String? ?? 'Cliente';
        final vehicles = results?[3] as List<Map<String, dynamic>>? ?? [];

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                svc: svc,
                clientName: clientName,
                onLogout: widget.onLogout,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (svc != null) ...[
                      if (svc.status == 'orcamento' || svc.status == 'enviado')
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  svc.status == 'enviado'
                                      ? 'Alteração de orçamento pendente de aprovação.'
                                      : 'Ação necessária: Aprove o orçamento para iniciar o serviço.',
                                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (svc.status == 'enviado')
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: orangeLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: orange.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, color: orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A oficina alterou o orçamento. Revise e aprove para continuar.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      AppButton(
                        label: (svc.status == 'orcamento' || svc.status == 'enviado') ? 'Revisar orçamento' : 'Ver detalhes do serviço',
                        fullWidth: true,
                        onPressed: () => Navigator.push(
                          context,
                          _fadeRoute(ServiceDetailScreen(service: svc)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          _fadeRoute(ServiceDetailScreen(service: svc)),
                        ),
                        child: _NextStepCard(svc: svc),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      _NoServiceCard(
                        hasVehicles: vehicles.isNotEmpty,
                        onRegisterVehicle: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterVehicleScreen(repository: widget.repository),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Serviços anteriores',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      Text(
                        'Nenhum histórico disponível.',
                        style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                      )
                    else
                      ...history.take(3).map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HistoryCard(item: h),
                          )),
                    const SizedBox(height: 88),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoServiceCard extends StatelessWidget {
  final bool hasVehicles;
  final VoidCallback onRegisterVehicle;

  const _NoServiceCard({required this.hasVehicles, required this.onRegisterVehicle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            hasVehicles ? Icons.info_outline_rounded : Icons.directions_car_rounded,
            color: textMuted,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            hasVehicles ? 'Nenhum serviço ativo' : 'Bem-vindo à Tião Oficina!',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          Text(
            hasVehicles
                ? 'Agende uma revisão para seu veículo.'
                : 'Para começar, cadastre seu veículo.',
            style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
            textAlign: TextAlign.center,
          ),
          if (!hasVehicles) ...[
            const SizedBox(height: 20),
            AppButton(
              label: 'Cadastrar meu veículo',
              fullWidth: true,
              onPressed: onRegisterVehicle,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ServiceModel? svc;
  final String clientName;
  final VoidCallback? onLogout;
  const _Header({
    this.svc,
    required this.clientName,
    this.onLogout,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ClientScreenHeader(
      title: 'Tião Oficina',
      subtitle: 'Olá, $clientName',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(initials: _getInitials(clientName), size: 40),
          if (onLogout != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
      childSpacing: 14,
      child: svc != null ? _ActiveServiceCard(svc: svc!) : const _WelcomePlaceholder(),
    );
  }
}

class _WelcomePlaceholder extends StatelessWidget {
  const _WelcomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seja bem-vindo(a)!',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Como podemos ajudar seu veículo hoje?',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveServiceCard extends StatelessWidget {
  final ServiceModel svc;
  const _ActiveServiceCard({required this.svc});

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'orcamento':
      case 'enviado': return 'ORÇAMENTO PENDENTE';
      case 'andamento':
      case 'em_execucao': return 'EM ANDAMENTO';
      case 'revisao':
      case 'revisao_tecnica': return 'EM REVISÃO';
      case 'aguardando_retirada': return 'AGUARDANDO RETIRADA';
      case 'concluido': return 'CONCLUÍDO';
      default: return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'orcamento':
      case 'enviado': return Colors.redAccent;
      case 'aguardando_retirada':
      case 'concluido': return green;
      default: return orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(svc.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulsingDot(size: 10, color: statusColor),
              const SizedBox(width: 8),
              Text(
                _getStatusText(svc.status),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            svc.title,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${svc.car} · ${svc.plate}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          AppProgressBar(percent: svc.progress.toDouble()),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${svc.progress}% concluído',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                'Até ${svc.estimatedEnd}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  final ServiceModel svc;
  const _NextStepCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final nextStep = svc.timeline.firstWhere(
      (s) => s.active,
      orElse: () => svc.timeline.firstWhere((s) => !s.done, orElse: () => svc.timeline.last),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próxima etapa',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: blue,
                  ),
                ),
                Text(
                  nextStep.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: greenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_rounded, color: green, size: 20),
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

Route _fadeRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (context, a, b) => page,
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, anim, sec, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
