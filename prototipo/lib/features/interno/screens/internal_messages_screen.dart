import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/mock_data.dart';
import 'internal_chat_screen.dart';

class ConversationModel {
  final String id;
  final String clientName;
  final String plate;
  final String lastMessage;
  final String time;
  final String date;
  final String mechanicName;
  final List<ChatMessage> messages;
  final String status;
  final String startTime;
  bool isTakenByEmployee;

  ConversationModel({
    required this.id,
    required this.clientName,
    required this.plate,
    required this.lastMessage,
    required this.time,
    required this.date,
    required this.mechanicName,
    required this.messages,
    required this.status,
    required this.startTime,
    this.isTakenByEmployee = false,
  });
}

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
  static final List<ConversationModel> _sharedConversations = [
    ConversationModel(
      id: '1',
      clientName: 'Carlos Mendes',
      plate: 'ABC-1234',
      lastMessage: 'Ótimo! Começando agora. Previsão até 17h.',
      time: '14:02',
      date: '30/04',
      mechanicName: 'José',
      status: 'Em andamento',
      startTime: '08:05',
      isTakenByEmployee: true,
      messages: [
        ChatMessage(id: 1, from: 'client', text: 'Boa tarde! Meu carro está fazendo um barulho estranho no freio.', time: '08:05', read: true),
        ChatMessage(id: 2, from: 'bot', text: 'Olá Carlos! Sou o TiãoBot. Já estou registrando seu problema.', time: '08:06', read: true),
        ChatMessage(id: 3, from: 'employee', text: 'Boa tarde, Carlos! Pode trazer para avaliarmos. Disponibilidade hoje?', time: '08:08', read: true),
        ChatMessage(id: 4, from: 'client', text: 'Sim, posso levar agora.', time: '08:12', read: true),
        ChatMessage(id: 5, from: 'system', text: 'Veículo recebido — Honda Civic ABC-1234', time: '08:30', read: true),
        ChatMessage(id: 6, from: 'employee', text: 'Carlos, identificamos pastilhas desgastadas e óleo vencido. Orçamento enviado.', time: '09:35', read: true),
        ChatMessage(id: 7, from: 'client', text: 'Pode fazer tudo. Aprovei o orçamento.', time: '10:18', read: true),
        ChatMessage(id: 8, from: 'system', text: 'Orçamento aprovado pelo cliente — R\$ 439,90', time: '10:18', read: true),
        ChatMessage(id: 9, from: 'employee', text: 'Ótimo! Começando agora. Previsão até 17h.', time: '14:02', read: false),
      ],
    ),
    ConversationModel(
      id: '2',
      clientName: 'Ana Paula Lima',
      plate: 'DEF-5678',
      lastMessage: 'Quando o carro vai ficar pronto?',
      time: '10:30',
      date: '30/04',
      mechanicName: 'Ricardo',
      status: 'Aprovar orçamento',
      startTime: '09:00',
      messages: [
        ChatMessage(id: 1, from: 'client', text: 'Bom dia, gostaria de saber se o orçamento já saiu.', time: '09:00', read: true),
        ChatMessage(id: 2, from: 'bot', text: 'Olá Ana! Estou analisando seu veículo. Em breve te envio o orçamento.', time: '09:15', read: true),
        ChatMessage(id: 3, from: 'client', text: 'Quando o carro vai ficar pronto?', time: '10:30', read: false),
        ChatMessage(id: 4, from: 'client', text: 'Preciso dele para o final de semana.', time: '10:35', read: false),
      ],
    ),
    ConversationModel(
      id: '3',
      clientName: 'Rafael Souza',
      plate: 'GHI-9012',
      lastMessage: 'Já terminei o alinhamento.',
      time: '09:15',
      date: '29/04',
      mechanicName: 'José',
      status: 'Concluído',
      startTime: '08:00',
      isTakenByEmployee: true,
      messages: [
        ChatMessage(id: 1, from: 'client', text: 'Olá, vou deixar o carro para alinhamento.', time: '08:00', read: true),
        ChatMessage(id: 2, from: 'employee', text: 'Combinado Rafael. Já estamos com ele aqui.', time: '08:15', read: true),
        ChatMessage(id: 3, from: 'employee', text: 'Já terminei o alinhamento.', time: '09:15', read: true),
      ],
    ),
  ];

  List<ConversationModel> get _allConversations => _sharedConversations;

  List<ConversationModel> get _filteredConversations {
    if (_search.length < 3) return _allConversations;
    final q = _search.toLowerCase();
    return _allConversations.where((c) {
      return c.mechanicName.toLowerCase().contains(q) ||
          c.plate.toLowerCase().contains(q);
    }).toList();
  }

  int get _unreadConversationsCount =>
      _allConversations
          .where(
            (conversation) => conversation.messages.any(
              (message) => message.from == 'client' && !message.read,
            ),
          )
          .length;

  void _notifyUnreadCountChanged() {
    widget.onUnreadCountChanged?.call(_unreadConversationsCount);
  }

  ConversationModel? _findMatchingConversation() {
    final plate = widget.initialPlate?.trim().toLowerCase();
    final clientName = widget.initialClientName?.trim().toLowerCase();

    for (final conversation in _allConversations) {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyUnreadCountChanged();

      if (!widget.autoOpenMatchingConversation) return;
      final conversation = _findMatchingConversation();
      if (conversation != null) {
        _openChat(
          conversation,
          closeScreenAfterChatClosed: true,
        );
      }
    });
  }

  void _markConversationAsRead(ConversationModel conversation) {
    for (final message in conversation.messages) {
      if (message.from == 'client' && !message.read) {
        message.read = true;
      }
    }
  }

  void _openChat(
    ConversationModel conversation, {
    bool closeScreenAfterChatClosed = false,
  }) {
    setState(() => _markConversationAsRead(conversation));
    _notifyUnreadCountChanged();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalChatScreen(conversation: conversation),
      ),
    ).then((_) {
      if (!mounted) return;

      if (closeScreenAfterChatClosed) {
        Navigator.pop(context);
        return;
      }

      setState(() {});
    });
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
                  hintText: 'Buscar por funcionário ou placa...',
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
          child: _filteredConversations.isEmpty
              ? Center(
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
                )
              : ListView.separated(
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
                ),
        ),
      ],
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadMessages = conversation.messages.where((m) => !m.read && m.from == 'client').toList();
    final unreadCount = unreadMessages.length;

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
                conversation.clientName.substring(0, 1).toUpperCase(),
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
                    Text(
                      conversation.clientName,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
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
                  '${conversation.messages.last.from == 'client' ? 'Cliente' : conversation.messages.last.from == 'employee' ? 'Funcionário' : conversation.messages.last.from == 'bot' ? 'TiãoBot' : 'Sistema'}: ${conversation.messages.last.text}',
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
                  unreadCount.toString(),
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
