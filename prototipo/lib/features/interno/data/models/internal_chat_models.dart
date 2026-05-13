class InternalChatMessage {
  final String id;
  final String from; // 'client', 'employee', 'bot', 'system'
  final String text;
  final String time;
  final String createdAtIso;
  bool read;

  InternalChatMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.time,
    required this.createdAtIso,
    this.read = true,
  });

  factory InternalChatMessage.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['criado_em'] as String?) ?? DateTime.now().toIso8601String();
    String hhmm = '--:--';
    if (rawDate.length >= 16) {
      hhmm = rawDate.substring(11, 16);
    }

    return InternalChatMessage(
      id: (json['id'] as String?) ?? '',
      from: (json['tipo_remetente'] as String? ?? 'system').toLowerCase(),
      text: (json['conteudo'] as String?) ?? '',
      time: hhmm,
      createdAtIso: rawDate,
      read: (json['lida'] as bool?) ?? true,
    );
  }
}

class InternalChatConversation {
  final String id;
  final String clientId;
  final String clientName;
  final String plate;
  final String lastMessage;
  final int unreadCount;
  final String time;
  final String date;
  final String status;
  final String startTime;
  bool isTakenByEmployee; // ia_pausada

  InternalChatConversation({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.plate,
    required this.lastMessage,
    required this.unreadCount,
    required this.time,
    required this.date,
    required this.status,
    required this.startTime,
    required this.isTakenByEmployee,
  });

  factory InternalChatConversation.fromJson(Map<String, dynamic> json) {
    // These fields depend on exactly what the backend returns.
    // Based on user feedback: "GET /conversacoes will return the joined data"
    
    // Convert time/date from some timestamp or use provided string
    final rawDate = json['updated_at'] ?? json['criado_em'] ?? '';
    String timeStr = '--:--';
    String dateStr = '--/--';
    if (rawDate is String && rawDate.length >= 16) {
      timeStr = rawDate.substring(11, 16);
      dateStr = '${rawDate.substring(8, 10)}/${rawDate.substring(5, 7)}';
    }

    return InternalChatConversation(
      id: (json['id'] as String?) ?? '',
      clientId: (json['cliente_id'] as String?) ?? '',
      clientName: (json['clientName'] as String?) ?? (json['nome_cliente'] as String?) ?? 'Cliente',
      plate: (json['plate'] as String?) ?? (json['placa'] as String?) ?? '---',
      lastMessage: (json['lastMessage'] as String?) ?? (json['ultima_mensagem'] as String?) ?? '',
      unreadCount: (json['unreadCount'] as int?) ?? (json['mensagens_nao_lidas'] as int?) ?? 0,
      time: timeStr,
      date: dateStr,
      status: (json['status'] as String?) ?? 'Ativo',
      startTime: (json['startTime'] as String?) ?? timeStr,
      isTakenByEmployee: (json['ia_pausada'] as bool?) ?? false,
    );
  }
}
