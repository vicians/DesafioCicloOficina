class WorkshopInfo {
  final String id;
  final String name;
  final int boxes;

  WorkshopInfo({
    required this.id,
    required this.name,
    required this.boxes,
  });

  factory WorkshopInfo.fromJson(Map<String, dynamic> json) {
    return WorkshopInfo(
      id: json['id'] as String,
      name: json['nome'] as String,
      boxes: json['quantidade_boxes'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': name,
      'quantidade_boxes': boxes,
    };
  }
}
