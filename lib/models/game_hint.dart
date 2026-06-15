class GameHint {
  const GameHint({
    required this.id,
    required this.text,
    this.createdAt,
    this.fromBoss = false,
  });

  final String id;
  final String text;
  final DateTime? createdAt;
  /// Подсказка от босса (на переданный вопрос), не от объясняющего.
  final bool fromBoss;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt?.toIso8601String(),
        'fromBoss': fromBoss,
      };

  factory GameHint.fromJson(Map<String, dynamic> json) {
    return GameHint(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      fromBoss: json['fromBoss'] as bool? ?? false,
    );
  }
}
