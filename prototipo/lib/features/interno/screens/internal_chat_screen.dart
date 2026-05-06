import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../data/internal_chat_repository.dart';
import '../data/models/internal_chat_models.dart';

class InternalChatScreen extends StatefulWidget {
  final InternalChatConversation conversation;
  final InternalChatRepository repository;

  const InternalChatScreen({
    super.key,
    required this.conversation,
    required this.repository,
  });

  @override
  State<InternalChatScreen> createState() => _InternalChatScreenState();
}

class _InternalChatScreenState extends State<InternalChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  late final Stream<List<InternalChatMessage>> _messagesStream;
  List<InternalChatMessage> _latestMessages = [];
  StreamSubscription? _subscription;
  bool _isAssumed = false;

  @override
  void initState() {
    super.initState();
    _isAssumed = widget.conversation.isTakenByEmployee;
    
    // TODO: Refactor to WebSockets when available
    _messagesStream = widget.repository.streamMessages(widget.conversation.id).asBroadcastStream();
    
    _subscription = _messagesStream.listen((messages) {
      if (!mounted) return;
      final bool shouldScroll = _latestMessages.length < messages.length;
      setState(() {
        _latestMessages = messages;
      });
      if (shouldScroll) {
        _scrollToBottom();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _toggleAssume() async {
    final newState = !_isAssumed;
    setState(() {
      _isAssumed = newState;
    });
    
    try {
      await widget.repository.toggleHandoff(widget.conversation.id, newState);
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          _isAssumed = !newState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao alterar status da IA.')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    // Optimistic UI update
    final optimisticMsg = InternalChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      from: 'employee',
      text: text,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      createdAtIso: DateTime.now().toIso8601String(),
    );

    setState(() {
      _latestMessages.add(optimisticMsg);
      _messageCtrl.clear();
    });
    
    _scrollToBottom();

    try {
      await widget.repository.sendMessage(widget.conversation.id, text, 'employee');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar mensagem.')),
        );
        setState(() {
          _latestMessages.removeWhere((m) => m.id == optimisticMsg.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.clientName,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Início: ${widget.conversation.startTime} · ${widget.conversation.status}',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _toggleAssume,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                _isAssumed ? 'Devolver ao TiãoBot' : 'Assumir conversa',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<InternalChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _latestMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: navyDark));
                }

                if (snapshot.hasError && _latestMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'Erro ao carregar histórico.',
                      style: GoogleFonts.dmSans(color: textSecondary),
                    ),
                  );
                }

                if (_latestMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma mensagem.',
                      style: GoogleFonts.dmSans(color: textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _latestMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _latestMessages[index];
                    if (msg.from == 'system') {
                      return _SystemMessage(msg: msg);
                    }
                    return _ChatBubble(msg: msg);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _isAssumed ? bgPage : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _messageCtrl,
                enabled: _isAssumed,
                style: GoogleFonts.dmSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isAssumed ? 'Escreva uma mensagem...' : 'Assuma a conversa para responder',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: textMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isAssumed ? _sendMessage : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isAssumed ? orange : textMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final InternalChatMessage msg;

  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isEmployee = msg.from == 'employee';
    final isBot = msg.from == 'bot';
    final isMe = isEmployee || isBot;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isEmployee 
              ? navyDark 
              : isBot 
                  ? navyMid 
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isBot) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.smart_toy_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TiãoBot',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ] else if (isEmployee) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Manual',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              msg.text,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: isMe ? Colors.white : textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.time,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: isMe ? Colors.white.withValues(alpha: 0.6) : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final InternalChatMessage msg;

  const _SystemMessage({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: dividerColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
      ),
    );
  }
}
