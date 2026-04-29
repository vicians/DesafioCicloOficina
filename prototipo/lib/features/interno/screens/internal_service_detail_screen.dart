import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';

class InternalServiceDetailScreen extends StatefulWidget {
  final InternalService service;

  const InternalServiceDetailScreen({super.key, required this.service});

  @override
  State<InternalServiceDetailScreen> createState() =>
      _InternalServiceDetailScreenState();
}

class _InternalServiceDetailScreenState
    extends State<InternalServiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late List<ChatMessage> _messages;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showStatusSheet = false;
  late String _currentStatus;
  late String _pendingStatus;

  final _statuses = [
    ('aguardando', 'Aguardando'),
    ('andamento', 'Em andamento'),
    ('revisao', 'Em revisão'),
    ('concluido', 'Concluído'),
    ('cancelado', 'Cancelado'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _messages = chatMessages;
    _currentStatus = widget.service.status;
    _pendingStatus = _currentStatus;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages = [
        ..._messages,
        ChatMessage(
          id: _messages.length + 1,
          from: 'employee',
          text: text,
          time: _timeNow(),
          read: true,
        ),
      ];
      _msgCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: Stack(
        children: [
          Column(
            children: [
              _DetailHeader(
                service: widget.service,
                tabCtrl: _tabCtrl,
                currentStatus: _currentStatus,
                onStatusTap: () => setState(() {
                  _pendingStatus = _currentStatus;
                  _showStatusSheet = true;
                }),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _ChatTab(
                      messages: _messages,
                      scrollCtrl: _scrollCtrl,
                      msgCtrl: _msgCtrl,
                      onSend: _sendMessage,
                    ),
                    _TimelineTab(svc: currentService),
                    _DataTab(svc: widget.service),
                  ],
                ),
              ),
            ],
          ),
          if (_showStatusSheet) ...[
            GestureDetector(
              onTap: () => setState(() => _showStatusSheet = false),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StatusSheet(
                statuses: _statuses,
                current: _pendingStatus,
                onSelect: (s) => setState(() {
                  _pendingStatus = s;
                }),
                onConfirm: () => setState(() {
                  _currentStatus = _pendingStatus;
                  _showStatusSheet = false;
                }),
                onCancel: () => setState(() => _showStatusSheet = false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final InternalService service;
  final TabController tabCtrl;
  final String currentStatus;
  final VoidCallback onStatusTap;

  const _DetailHeader({
    required this.service,
    required this.tabCtrl,
    required this.currentStatus,
    required this.onStatusTap,
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
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                          service.client,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${service.id} · ${service.plate}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: currentStatus),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onStatusTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Atualizar status',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Mensagens'),
                Tab(text: 'Timeline'),
                Tab(text: 'Dados'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollCtrl;
  final TextEditingController msgCtrl;
  final VoidCallback onSend;

  const _ChatTab({
    required this.messages,
    required this.scrollCtrl,
    required this.msgCtrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (ctx, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ChatBubble(msg: messages[i]),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
          decoration: const BoxDecoration(
            color: cardWhite,
            border: Border(top: BorderSide(color: dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: msgCtrl,
                  style:
                      GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mensagem...',
                    hintStyle:
                        GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.from == 'system') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: dividerColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
          ),
        ),
      );
    }

    final isEmployee = msg.from == 'employee';
    return Align(
      alignment: isEmployee ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isEmployee ? navyDark : cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft:
                Radius.circular(isEmployee ? 14 : 4),
            bottomRight:
                Radius.circular(isEmployee ? 4 : 14),
          ),
          boxShadow: const [cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: isEmployee ? Colors.white : textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              msg.time,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: isEmployee
                    ? Colors.white.withValues(alpha: 0.5)
                    : textMuted,
              ),
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
      children: List.generate(svc.timeline.length, (i) {
        final step = svc.timeline[i];
        final isLast = i == svc.timeline.length - 1;

        Color circleColor;
        Widget icon;

        if (step.done) {
          circleColor = green;
          icon = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
        } else if (step.active) {
          circleColor = orange;
          icon = Container(
            width: 10,
            height: 10,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          );
        } else {
          circleColor = borderColor;
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
                                  spreadRadius: 5,
                                )
                              ]
                            : null,
                      ),
                      child: Center(child: icon),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color:
                              step.done ? green : borderColor,
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
      }),
    );
  }
}

class _DataTab extends StatelessWidget {
  final InternalService svc;
  const _DataTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Cliente', svc.client),
      ('Ordem de serviço', svc.id),
      ('Veículo', svc.car),
      ('Placa', svc.plate),
      ('Serviço', svc.service),
      ('Mecânico', svc.mechanic),
      ('Horário', svc.time),
      ('Valor', 'R\$ ${svc.value.toStringAsFixed(2).replaceAll('.', ',')}'),
    ];

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
            children: List.generate(rows.length, (i) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            rows[i].$1,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            rows[i].$2,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1)
                    const Divider(
                        height: 1, thickness: 1, color: dividerColor),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [cardShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progresso',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AppProgressBar(percent: svc.progress.toDouble()),
              const SizedBox(height: 6),
              Text(
                '${svc.progress}% concluído',
                style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusSheet extends StatelessWidget {
  final List<(String, String)> statuses;
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _StatusSheet({
    required this.statuses,
    required this.current,
    required this.onSelect,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: const BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Atualizar status',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...statuses.map((s) {
            final isActive = s.$1 == current;
            return GestureDetector(
              onTap: () => onSelect(s.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive ? navyDark.withValues(alpha: 0.06) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? navyDark : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.$2,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive ? navyDark : textPrimary,
                        ),
                      ),
                    ),
                    if (isActive)
                      const Icon(Icons.check_rounded,
                          color: navyDark, size: 18),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          AppButton(
            label: 'Confirmar mudança de status',
            fullWidth: true,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Cancelar',
            fullWidth: true,
            variant: AppButtonVariant.ghost,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
