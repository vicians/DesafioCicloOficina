import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../data/internal_chat_api_repository.dart';
import '../data/internal_chat_repository.dart';
import '../data/models/internal_chat_models.dart';
import 'internal_chat_screen.dart';

class InternalMessagesScreen extends StatefulWidget {
  final ValueChanged<int>? onUnreadCountChanged;
  final String? initialClientName;
  final String? initialPlate;
  final bool autoOpenMatchingConversation;

  const InternalMessagesScreen({
    super.key,
    this.onUnreadCountChanged,
    this.initialClientName,
    this.initialPlate,
    this.autoOpenMatchingConversation = false,
  });

  @override
  State<InternalMessagesScreen> createState() => _InternalMessagesScreenState();
}

class _InternalMessagesScreenState extends State<InternalMessagesScreen> {
  String _search = '';
  
  // TODO: Move baseUrl configuration to a centralized config or DI
  late final InternalChatRepository _repository;
  late final Stream<List<InternalChatConversation>> _conversationsStream;
  List<InternalChatConversation> _latestConversations = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Defaulting to Android emulator local address. Use localhost for iOS/Web.
    _repository = InternalChatApiRepository(baseUrl: 'http://10.0.2.2:3000');
    
    // TODO: Refactor to WebSockets when available
    _conversationsStream = _repository.streamConversations().asBroadcastStream();
    
    _subscription = _conversationsStream.listen((conversations) {
      if (!mounted) return;
      setState(() {
        _latestConversations = conversations;
      });
      _notifyUnreadCountChanged(conversations);
      _handleAutoOpen(conversations);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _notifyUnreadCountChanged(List<InternalChatConversation> conversations) {
    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + (c.unreadCount > 0 ? 1 : 0));
    widget.onUnreadCountChanged?.call(unreadCount);
  }

  bool _hasAutoOpened = false;
  void _handleAutoOpen(List<InternalChatConversation> conversations) {
    if (!widget.autoOpenMatchingConversation || _hasAutoOpened) return;
    
    final conversation = _findMatchingConversation(conversations);
    if (conversation != null) {
      _hasAutoOpened = true;
      _openChat(
        conversation,
        closeScreenAfterChatClosed: true,
      );
    }
  }

  InternalChatConversation? _findMatchingConversation(List<InternalChatConversation> conversations) {
    final plate = widget.initialPlate?.trim().toLowerCase();
    final clientName = widget.initialClientName?.trim().toLowerCase();

    for (final conversation in conversations) {
      final conversationPlate = conversation.plate.trim().toLowerCase();
      final conversationClient = conversation.clientName.trim().toLowerCase();
      final matchByPlate = plate != null && plate.isNotEmpty && conversationPlate == plate;
      final matchByClient = clientName != null &&
          clientName.isNotEmpty &&
          (conversationClient == clientName ||
              conversationClient.contains(clientName) ||
              clientName.contains(conversationClient));

      if (matchByPlate || matchByClient) {
        return conversation;
      }
    }

    return null;
  }

  List<InternalChatConversation> get _filteredConversations {
    if (_search.length < 3) return _latestConversations;
    final q = _search.toLowerCase();
    return _latestConversations.where((c) {
      return c.clientName.toLowerCase().contains(q) ||
          c.plate.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openChat(
    InternalChatConversation conversation, {
    bool closeScreenAfterChatClosed = false,
  }) async {
    // Optimistically clear unread count
    if (conversation.unreadCount > 0) {
      await _repository.markAsRead(conversation.id);
    }

    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalChatScreen(
          conversation: conversation,
          repository: _repository,
        ),
      ),
    );

    if (!mounted) return;
    if (closeScreenAfterChatClosed) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navyDark, navyMid],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mensagens',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // Search Field
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente ou placa...',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Conversation List
        Expanded(
          child: StreamBuilder<List<InternalChatConversation>>(
            stream: _conversationsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _latestConversations.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: navyDark));
              }

              if (snapshot.hasError && _latestConversations.isEmpty) {
                return Center(
                  child: Text(
                    'Erro ao carregar mensagens.',
                    style: GoogleFonts.dmSans(color: textSecondary),
                  ),
                );
              }

              if (_filteredConversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma conversa encontrada',
                        style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredConversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final conv = _filteredConversations[index];
                  return _ConversationCard(
                    conversation: conv,
                    onTap: () => _openChat(conv),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final InternalChatConversation conversation;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.unreadCount;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [navyDark, navyMid],
              ),
            ),
            child: Center(
              child: Text(
                conversation.clientName.isNotEmpty ? conversation.clientName.substring(0, 1).toUpperCase() : '?',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        conversation.clientName,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${conversation.time} (${conversation.date})',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Veículo: ${conversation.plate}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: unreadCount > 0 ? textPrimary : textSecondary,
                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
