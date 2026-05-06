class InternalChatMessage {
  final String id;
  final String from;
  final String text;
  final String time;
  final String createdAtIso;

  const InternalChatMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.time,
    required this.createdAtIso,
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
    );
  }
}
