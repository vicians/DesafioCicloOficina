import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../data/internal_flow_repository.dart';
import '../data/models/internal_chat_message.dart';

class ServiceClientChatScreen extends StatefulWidget {
  final InternalFlowRepository repository;
  final String clientId;
  final String clientName;

  const ServiceClientChatScreen({
    super.key,
    required this.repository,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ServiceClientChatScreen> createState() => _ServiceClientChatScreenState();
}

class _ServiceClientChatScreenState extends State<ServiceClientChatScreen> {
  late Future<List<InternalChatMessage>> _future;
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchMensagensCliente(widget.clientId);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.fetchMensagensCliente(widget.clientId);
    });
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await widget.repository.sendMensagemCliente(widget.clientId, text);
      _messageCtrl.clear();
      await _reload();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        title: Text(
          widget.clientName,
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<InternalChatMessage>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar conversa',
                      style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
                    ),
                  );
                }

                final messages = snapshot.data ?? const <InternalChatMessage>[];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma mensagem nesta conversa',
                      style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final fromEmployee = msg.from == 'employee';
                    final fromSystem = msg.from == 'system';

                    if (fromSystem) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: dividerColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg.text,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: fromEmployee ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: fromEmployee ? navyDark : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [cardShadow],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              fromEmployee ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: fromEmployee ? Colors.white : textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.time,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: fromEmployee
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    decoration: InputDecoration(
                      hintText: 'Escrever mensagem... ',
                      hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
